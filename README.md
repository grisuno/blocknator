# blocknator

## generate_blocklist.sh

## Usage Examples:

### Interactive Mode (default):
```bash
./generate_blocklist.sh blocklist.txt
```

### Headless Mode - Block Incoming:
```bash
./generate_blocklist.sh --mode headless --block-in blocklist.txt
```

### Headless Mode - Block All Traffic:
```bash
./generate_blocklist.sh --mode headless --block-all -o my_rules.sh blocklist.txt
```

### Dry Run Preview:
```bash
./generate_blocklist.sh --dry-run --verbose --block-out blocklist.txt
```

### Force Overwrite:
```bash
./generate_blocklist.sh --mode headless --block-all --force blocklist.txt
```

## Features:

- **Two modes**: Interactive and headless  
- **Flexible direction**: `--block-in`, `--block-out`, `--block-all`  
- **IP range to CIDR conversion**: Optimized rules  
- **Custom chain**: Better organization and management  
- **Logging**: Track blocked packets  
- **Dry run**: Preview before generating  
- **Verbose output**: Detailed information  
- **Force overwrite**: Handle existing files  
- **Validation**: Check input file format  
- **Root check**: Verify permissions  
- **Atomic writes**: Safe file generation  

![Python](https://img.shields.io/badge/python-3670A0?style=for-the-badge&logo=python&logoColor=ffdd54) ![Shell Script](https://img.shields.io/badge/shell_script-%23121011.svg?style=for-the-badge&logo=gnu-bash&logoColor=white) ![Flask](https://img.shields.io/badge/flask-%23000.svg?style=for-the-badge&logo=flask&logoColor=white) [![License: AGPL v3](https://img.shields.io/badge/License-AGPLv3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/Y8Y2Z73AV)
