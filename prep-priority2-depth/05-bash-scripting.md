# Bash Cheatsheet — Memorize This

## Script Header
```bash
#!/bin/bash
set -euo pipefail
# -e: exit on error
# -u: error on undefined variables
# -o pipefail: catch errors in piped commands
```

## Variables
```bash
NAME="carlos"
echo "Hello $NAME"
echo "Hello ${NAME}"

# Default value
echo "${NAME:-default_value}"      # use default if NAME unset
echo "${NAME:=default_value}"      # set AND use default if NAME unset

# String operations
echo "${#NAME}"                    # length: 6
echo "${NAME^^}"                   # uppercase: CARLOS
echo "${NAME,,}"                   # lowercase: carlos
echo "${NAME:0:3}"                 # substring: car

# Path operations
FILE="/path/to/file.tar.gz"
echo "${FILE##*/}"                 # basename: file.tar.gz
echo "${FILE%.*}"                  # remove extension: /path/to/file.tar
echo "${FILE%%.*}"                 # remove all extensions: /path/to/file
echo "${FILE%/*}"                  # dirname: /path/to
```

## Conditionals
```bash
# String comparison
if [[ "$VAR" == "value" ]]; then
    echo "match"
elif [[ "$VAR" != "other" ]]; then
    echo "not other"
else
    echo "something else"
fi

# Numeric comparison
if [[ "$NUM" -eq 0 ]]; then echo "zero"; fi
if [[ "$NUM" -gt 5 ]]; then echo "greater than 5"; fi
if [[ "$NUM" -lt 10 ]]; then echo "less than 10"; fi
if [[ "$NUM" -ge 5 ]]; then echo "5 or more"; fi
if [[ "$NUM" -le 10 ]]; then echo "10 or less"; fi

# File tests
if [[ -f "$FILE" ]]; then echo "file exists"; fi
if [[ -d "$DIR" ]]; then echo "directory exists"; fi
if [[ -e "$PATH" ]]; then echo "exists (file or dir)"; fi
if [[ -r "$FILE" ]]; then echo "readable"; fi
if [[ -w "$FILE" ]]; then echo "writable"; fi
if [[ -x "$FILE" ]]; then echo "executable"; fi
if [[ -s "$FILE" ]]; then echo "not empty"; fi

# String tests
if [[ -z "$VAR" ]]; then echo "empty/unset"; fi
if [[ -n "$VAR" ]]; then echo "not empty"; fi

# Logical operators
if [[ "$A" == "1" && "$B" == "2" ]]; then echo "both"; fi
if [[ "$A" == "1" || "$B" == "2" ]]; then echo "either"; fi
if [[ ! -f "$FILE" ]]; then echo "file missing"; fi
```

## Loops
```bash
# For loop — list
for item in alice bob charlie; do
    echo "User: $item"
done

# For loop — range
for i in {1..10}; do
    echo "Number: $i"
done

# For loop — C-style
for ((i=0; i<10; i++)); do
    echo "Index: $i"
done

# For loop — files
for file in /var/log/*.log; do
    echo "Log: $file"
done

# While loop
count=0
while [[ $count -lt 5 ]]; do
    echo "Count: $count"
    ((count++))
done

# While read (process file line by line)
while IFS= read -r line; do
    echo "Line: $line"
done < input.txt

# While read from command
kubectl get pods -o name | while read -r pod; do
    echo "Pod: $pod"
done
```

## Functions
```bash
my_function() {
    local name="$1"        # local variable
    local count="${2:-0}"   # with default

    echo "Name: $name, Count: $count"

    if [[ -z "$name" ]]; then
        return 1           # return error code
    fi
    return 0               # return success
}

# Call it
my_function "carlos" 5
result=$?                  # capture return code
```

## Error Handling
```bash
# Trap for cleanup
cleanup() {
    echo "Cleaning up..."
    rm -f "$TEMP_FILE"
}
trap cleanup EXIT          # runs on exit (success or failure)
trap cleanup ERR           # runs on error only

# Check command success
if ! command -v rke2 &>/dev/null; then
    echo "ERROR: rke2 not found" >&2
    exit 1
fi

# Or inline
command -v rke2 &>/dev/null || { echo "rke2 not found" >&2; exit 1; }
```

## Redirects
```bash
echo "stdout"              # prints to stdout (fd 1)
echo "error" >&2           # prints to stderr (fd 2)

command > output.txt       # redirect stdout to file (overwrite)
command >> output.txt      # redirect stdout to file (append)
command 2> errors.txt      # redirect stderr to file
command > all.txt 2>&1     # redirect both stdout and stderr to file
command &> all.txt         # shorthand for both (bash only)
command > /dev/null 2>&1   # discard all output
```

## Common Patterns

### Log function
```bash
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}
log "Starting backup..."
```

### Argument parsing
```bash
while [[ $# -gt 0 ]]; do
    case "$1" in
        -f|--file)
            FILE="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [-f file] [-v]"
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done
```

### Check if running as root
```bash
if [[ $EUID -ne 0 ]]; then
    echo "Must run as root" >&2
    exit 1
fi
```

### Checksum validation
```bash
# Generate checksums
sha256sum /path/to/files/* > manifest.sha256

# Verify checksums
sha256sum -c manifest.sha256
```

### Process substitution
```bash
diff <(sort file1.txt) <(sort file2.txt)
```

## Useful One-Liners
```bash
# Find files modified in last 24h
find /var/log -name "*.log" -mtime -1

# Find and delete
find /tmp -name "*.tmp" -mtime +7 -exec rm {} \;

# Count lines matching pattern
grep -c "ERROR" /var/log/app.log

# Extract column
awk '{print $3}' /var/log/access.log

# Unique sorted count
sort file.txt | uniq -c | sort -rn

# Watch command output
watch -n 5 'kubectl get pods'

# Parallel execution
xargs -P 4 -I {} sh -c 'echo processing {}' < filelist.txt
```

## Exit Codes
```
0   — success
1   — general error
2   — misuse of shell command
126 — command not executable
127 — command not found
128+N — killed by signal N (e.g., 130 = Ctrl+C)
```

## Special Variables
```bash
$0    # script name
$1    # first argument
$#    # number of arguments
$@    # all arguments (as separate words)
$*    # all arguments (as single string)
$?    # exit code of last command
$$    # current process PID
$!    # PID of last background process
```
