# root

*Community 0 | 2 files | cohesion 1.00*

## Definition

This community groups 2 file(s) rooted at `root` with dominant language sh (cohesion 1.00). Central symbols: `check_root`, `generate_iptables_script`, `headless_mode`, `int_to_ip`, `interactive_mode`, `ip_to_int`, `log_error`, `log_info`. Core file: `generate_blocklist.sh` (15 symbols).

## Files

| File | Language | Layer | Symbols | Doc |
|------|----------|-------|---------|-----|
| `generate_blocklist.sh` | sh | utility | 15 | yes |
| `install.sh` | sh | utility | 0 | no |

## Key Symbols

- `usage` (function, `generate_blocklist.sh:42`)
- `version` (function, `generate_blocklist.sh:83`)
- `log_info` (function, `generate_blocklist.sh:88`)
- `log_warn` (function, `generate_blocklist.sh:94`)
- `log_error` (function, `generate_blocklist.sh:98`)
- `check_root` (function, `generate_blocklist.sh:102`)
- `validate_input_file` (function, `generate_blocklist.sh:111`)
- `ip_to_int` (function, `generate_blocklist.sh:137`)
- `int_to_ip` (function, `generate_blocklist.sh:145`)
- `range_to_cidr` (function, `generate_blocklist.sh:150`)
- `generate_iptables_script` (function, `generate_blocklist.sh:191`)
- `interactive_mode` (function, `generate_blocklist.sh:320`)
- `headless_mode` (function, `generate_blocklist.sh:376`)
- `parse_arguments` (function, `generate_blocklist.sh:401`)
- `main` (function, `generate_blocklist.sh:467`)

## Internal vs External Edges

- Internal resolved imports (EXTRACTED): 0
- Cross-boundary resolved imports (EXTRACTED): 0

## Connections

- No cross-community bridges recorded. This community is self-contained.

## Risks

- No scoped security, taint, cycle, or layer risks.

## Open Questions

- Why do 1 file(s) lack file-level docs (e.g. `install.sh`)? What purpose do they serve?
- What would break if the most connected file in root changed?
- Should root be split, given cohesion 1.00?

## Sources

- `generate_blocklist.sh`
- `install.sh`
