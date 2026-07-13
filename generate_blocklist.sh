#!/usr/bin/env bash
# =============================================================================
# generate_blocklist.sh - Generate iptables blocklist from IP range file
# =============================================================================
# Author: Gris Iscomeback
# Description: Converts IP range lists to iptables rules with flexible options
# Usage: ./generate_blocklist.sh [OPTIONS] <input_file>
# =============================================================================

set -euo pipefail

# Constants
readonly SCRIPT_NAME="$(basename "$0")"
readonly VERSION="1.0.0"
readonly DEFAULT_OUTPUT="block_iptables.sh"
readonly CHAIN_NAME="BLOCK_LIST"
readonly LOG_PREFIX="BLOCKED_IP:"

# Colors for interactive mode (disabled in headless)
if [[ -t 1 ]]; then
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[1;33m'
    readonly BLUE='\033[0;34m'
    readonly NC='\033[0m'
else
    readonly RED='' GREEN='' YELLOW='' BLUE='' NC=''
fi

# Global variables
INPUT_FILE=""
OUTPUT_FILE="$DEFAULT_OUTPUT"
MODE="interactive"
DIRECTION="in"
DRY_RUN=false
VERBOSE=false

# =============================================================================
# Functions
# =============================================================================

usage() {
    cat << EOF
${SCRIPT_NAME} v${VERSION} - Generate iptables blocklist from IP range file

USAGE:
    ${SCRIPT_NAME} [OPTIONS] <input_file>

OPTIONS:
    -h, --help              Show this help message
    -v, --version           Show version
    -o, --output FILE       Output file (default: ${DEFAULT_OUTPUT})
    -m, --mode MODE         Mode: interactive|headless (default: interactive)
    -d, --direction DIR     Direction: in|out|both (default: in)
        --block-in          Block incoming traffic only
        --block-out         Block outgoing traffic only
        --block-all         Block both incoming and outgoing traffic
    -n, --dry-run           Show commands without executing
    -V, --verbose           Enable verbose output
    -f, --force             Overwrite output file if exists

EXAMPLES:
    # Interactive mode (default)
    ${SCRIPT_NAME} blocklist.txt

    # Headless mode - block incoming
    ${SCRIPT_NAME} --mode headless --block-in blocklist.txt

    # Headless mode - block all traffic
    ${SCRIPT_NAME} --mode headless --block-all -o my_rules.sh blocklist.txt

    # Dry run to preview
    ${SCRIPT_NAME} --dry-run --verbose blocklist.txt

INPUT FORMAT:
    Each line should be in format: START_IP - END_IP , CODE , COUNTRY
    Lines starting with # are treated as comments

EOF
    exit 0
}

version() {
    echo "${SCRIPT_NAME} version ${VERSION}"
    exit 0
}

log_info() {
    if [[ "$VERBOSE" == true ]] || [[ "$MODE" == "interactive" ]]; then
        echo -e "${GREEN}[INFO]${NC} $*"
    fi
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

check_root() {
    if [[ "$EUID" -ne 0 ]]; then
        log_error "This script requires root privileges to apply iptables rules"
        log_error "Please run with sudo or as root"
        return 1
    fi
    return 0
}

validate_input_file() {
    local file="$1"
    
    if [[ ! -f "$file" ]]; then
        log_error "Input file not found: $file"
        return 1
    fi
    
    if [[ ! -r "$file" ]]; then
        log_error "Cannot read input file: $file"
        return 1
    fi
    
    # Check if file has valid content
    local line_count
    line_count=$(grep -v '^#' "$file" | grep -v '^[[:space:]]*$' | wc -l)
    
    if [[ "$line_count" -eq 0 ]]; then
        log_error "No valid IP ranges found in: $file"
        return 1
    fi
    
    log_info "Found $line_count IP ranges in input file"
    return 0
}

ip_to_int() {
    local ip="$1"
    local a b c d
    
    IFS='.' read -r a b c d <<< "$ip"
    echo $(( (a << 24) + (b << 16) + (c << 8) + d ))
}

int_to_ip() {
    local int="$1"
    echo "$(( (int >> 24) & 255 )).$(( (int >> 16) & 255 )).$(( (int >> 8) & 255 )).$(( int & 255 ))"
}

range_to_cidr() {
    local start_ip="$1"
    local end_ip="$2"
    
    local start_int end_int
    start_int=$(ip_to_int "$start_ip")
    end_int=$(ip_to_int "$end_ip")
    
    if [[ $start_int -gt $end_int ]]; then
        log_warn "Invalid range: $start_ip > $end_ip"
        return 1
    fi
    
    # Calculate CIDR blocks
    local cidrs=()
    local current=$start_int
    
    while [[ $current -le $end_int ]]; do
        local max_size=32
        
        # Find the largest block that fits
        while [[ $max_size -gt 0 ]]; do
            local mask=$(( 0xFFFFFFFF << (32 - max_size + 1) & 0xFFFFFFFF ))
            local next=$(( current + (1 << (32 - max_size + 1)) - 1 ))
            
            if [[ $next -le $end_int ]] && [[ $(( current & mask )) -eq $current ]]; then
                break
            fi
            max_size=$((max_size - 1))
        done
        
        local cidr_ip
        cidr_ip=$(int_to_ip $current)
        cidrs+=("${cidr_ip}/${max_size}")
        
        current=$(( current + (1 << (32 - max_size)) ))
    done
    
    printf '%s\n' "${cidrs[@]}"
}

generate_iptables_script() {
    local input_file="$1"
    local output_file="$2"
    local direction="$3"
    
    log_info "Generating iptables script: $output_file"
    log_info "Direction: $direction"
    
    # Create temporary file for atomic write
    local tmp_file
    tmp_file=$(mktemp)
    
    cat > "$tmp_file" << 'HEADER'
#!/usr/bin/env bash
# =============================================================================
# Auto-generated iptables blocklist script
# =============================================================================
# Generated by: generate_blocklist.sh
# Date: $(date '+%Y-%m-%d %H:%M:%S')
# WARNING: This will block traffic from specified IP ranges
# =============================================================================

set -euo pipefail

CHAIN_NAME="BLOCK_LIST"
LOG_PREFIX="BLOCKED_IP:"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo "Error: This script must be run as root"
    exit 1
fi

echo "Setting up iptables blocklist..."

# Create custom chain if it doesn't exist
iptables -N $CHAIN_NAME 2>/dev/null || iptables -F $CHAIN_NAME

# Add logging rule
iptables -A $CHAIN_NAME -j LOG --log-prefix "$LOG_PREFIX " --log-level 4

# Default policy: drop
iptables -A $CHAIN_NAME -j DROP

HEADER

    # Replace date placeholder
    sed -i "s/\$(date '+%Y-%m-%d %H:%M:%S')/$(date '+%Y-%m-%d %H:%M:%S')/" "$tmp_file"
    
    # Process IP ranges
    local rule_count=0
    local error_count=0
    
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue
        
        # Parse IP range
        if [[ "$line" =~ ^([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)[[:space:]]*-[[:space:]]*([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+) ]]; then
            local start_ip="${BASH_REMATCH[1]}"
            local end_ip="${BASH_REMATCH[2]}"
            
            # Convert to CIDR and generate rules
            local cidrs
            cidrs=$(range_to_cidr "$start_ip" "$end_ip" 2>/dev/null)
            
            if [[ $? -eq 0 ]] && [[ -n "$cidrs" ]]; then
                while IFS= read -r cidr; do
                    case "$direction" in
                        in)
                            echo "iptables -A INPUT -s $cidr -j $CHAIN_NAME" >> "$tmp_file"
                            ;;
                        out)
                            echo "iptables -A OUTPUT -d $cidr -j $CHAIN_NAME" >> "$tmp_file"
                            ;;
                        both)
                            echo "iptables -A INPUT -s $cidr -j $CHAIN_NAME" >> "$tmp_file"
                            echo "iptables -A OUTPUT -d $cidr -j $CHAIN_NAME" >> "$tmp_file"
                            ;;
                    esac
                    rule_count=$((rule_count + 1))
                done
            else
                log_warn "Failed to convert range: $start_ip - $end_ip"
                error_count=$((error_count + 1))
            fi
        fi
    done < "$input_file"
    
    # Add chain integration
    cat >> "$tmp_file" << FOOTER

# Link chain to main chains
case "$direction" in
    in)
        iptables -I INPUT 1 -j \$CHAIN_NAME
        echo "Blocking incoming traffic from \${rule_count} CIDR blocks"
        ;;
    out)
        iptables -I OUTPUT 1 -j \$CHAIN_NAME
        echo "Blocking outgoing traffic to \${rule_count} CIDR blocks"
        ;;
    both)
        iptables -I INPUT 1 -j \$CHAIN_NAME
        iptables -I OUTPUT 1 -j \$CHAIN_NAME
        echo "Blocking traffic in both directions for \${rule_count} CIDR blocks"
        ;;
esac

echo "Blocklist applied successfully!"
echo ""
echo "To view blocked packets: iptables -L \$CHAIN_NAME -v -n"
echo "To remove rules: iptables -D INPUT -j \$CHAIN_NAME && iptables -D OUTPUT -j \$CHAIN_NAME && iptables -F \$CHAIN_NAME && iptables -X \$CHAIN_NAME"

FOOTER
    
    # Make executable and move to final location
    chmod +x "$tmp_file"
    mv "$tmp_file" "$output_file"
    
    log_info "Generated $rule_count iptables rules"
    if [[ $error_count -gt 0 ]]; then
        log_warn "$error_count ranges could not be converted"
    fi
    
    echo "$output_file"
}

interactive_mode() {
    echo -e "${BLUE}=== IP Blocklist Generator ===${NC}"
    echo ""
    
    # Get input file
    if [[ -z "$INPUT_FILE" ]]; then
        read -rp "Enter path to IP range file: " INPUT_FILE
    fi
    
    validate_input_file "$INPUT_FILE" || exit 1
    
    # Get direction
    if [[ "$DIRECTION" == "in" ]]; then
        echo -e "${YELLOW}Select blocking direction:${NC}"
        echo "1) Block incoming traffic only"
        echo "2) Block outgoing traffic only" 
        echo "3) Block both incoming and outgoing"
        read -rp "Choice [1-3]: " choice
        
        case "$choice" in
            1) DIRECTION="in" ;;
            2) DIRECTION="out" ;;
            3) DIRECTION="both" ;;
            *) log_error "Invalid choice"; exit 1 ;;
        esac
    fi
    
    # Get output file
    if [[ "$OUTPUT_FILE" == "$DEFAULT_OUTPUT" ]]; then
        read -rp "Output file [$DEFAULT_OUTPUT]: " user_output
        if [[ -n "$user_output" ]]; then
            OUTPUT_FILE="$user_output"
        fi
    fi
    
    # Confirm
    echo ""
    echo -e "${YELLOW}Configuration:${NC}"
    echo "  Input:  $INPUT_FILE"
    echo "  Output: $OUTPUT_FILE"
    echo "  Direction: $DIRECTION"
    echo ""
    
    read -rp "Generate blocklist? [y/N]: " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 0
    fi
    
    generate_iptables_script "$INPUT_FILE" "$OUTPUT_FILE" "$DIRECTION"
    
    echo ""
    echo -e "${GREEN}✓ Script generated: $OUTPUT_FILE${NC}"
    echo "To apply: sudo ./$OUTPUT_FILE"
}

headless_mode() {
    if [[ -z "$INPUT_FILE" ]]; then
        log_error "Input file required in headless mode"
        usage
    fi
    
    validate_input_file "$INPUT_FILE" || exit 1
    
    # Check overwrite
    if [[ -f "$OUTPUT_FILE" ]] && [[ "$FORCE" != true ]]; then
        log_error "Output file already exists: $OUTPUT_FILE (use --force to overwrite)"
        exit 1
    fi
    
    local result
    result=$(generate_iptables_script "$INPUT_FILE" "$OUTPUT_FILE" "$DIRECTION")
    
    if [[ "$DRY_RUN" == true ]]; then
        echo "Would generate: $result"
    else
        log_info "Script generated: $OUTPUT_FILE"
        echo "Apply with: sudo ./$OUTPUT_FILE"
    fi
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                usage
                ;;
            -v|--version)
                version
                ;;
            -o|--output)
                OUTPUT_FILE="$2"
                shift 2
                ;;
            -m|--mode)
                MODE="$2"
                shift 2
                ;;
            -d|--direction)
                DIRECTION="$2"
                shift 2
                ;;
            --block-in)
                DIRECTION="in"
                shift
                ;;
            --block-out)
                DIRECTION="out"
                shift
                ;;
            --block-all)
                DIRECTION="both"
                shift
                ;;
            -n|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -V|--verbose)
                VERBOSE=true
                shift
                ;;
            -f|--force)
                FORCE=true
                shift
                ;;
            -*)
                log_error "Unknown option: $1"
                usage
                ;;
            *)
                if [[ -z "$INPUT_FILE" ]]; then
                    INPUT_FILE="$1"
                else
                    log_error "Unexpected argument: $1"
                    usage
                fi
                shift
                ;;
        esac
    done
}

# =============================================================================
# Main
# =============================================================================

main() {
    parse_arguments "$@"
    
    case "$MODE" in
        interactive)
            interactive_mode
            ;;
        headless)
            headless_mode
            ;;
        *)
            log_error "Invalid mode: $MODE (use 'interactive' or 'headless')"
            exit 1
            ;;
    esac
}

main "$@"
