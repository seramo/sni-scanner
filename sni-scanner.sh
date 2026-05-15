#!/bin/bash

# Default configurations
INPUT_FILE="targets.txt"
PORTS="443,2053,2083,2087,2096,8443"
TIMEOUT=5
RETRIES=3
LOG_FILE="log.txt"
CONCURRENCY=20

usage() {
    echo "Usage: $0 [-f file] [-p ports] [-t timeout] [-r retries] [-l log_file]"
    echo "  -f  Input file containing domains/IPs (default: targets.txt)"
    echo "  -p  Comma-separated ports to scan (default: 443,2053,2083,2087,2096,8443)"
    echo "  -t  Timeout in seconds for each connection (default: 5)"
    echo "  -r  Number of retries for closed ports (default: 3)"
    echo "  -l  Output log file (default: log.txt)"
    exit 1
}

# Parse CLI arguments
while getopts "f:p:t:r:l:h" opt; do
    case $opt in
        f) INPUT_FILE="$OPTARG" ;;
        p) PORTS="$OPTARG" ;;
        t) TIMEOUT="$OPTARG" ;;
        r) RETRIES="$OPTARG" ;;
        l) LOG_FILE="$OPTARG" ;;
        h|*) usage ;;
    esac
done

if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: Input file '$INPUT_FILE' not found!"
    exit 1
fi

IFS=',' read -r -a PORT_ARRAY <<< "$PORTS"

# Initialize/Clear log file
> "$LOG_FILE"

process_target() {
    local target=$1
    local ips=()
    local domain_buffer=""

    # DNS Resolution
    if [[ $target =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        ips=($target)
    else
        mapfile -t ips < <(dig +short A "$target" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$')
    fi

    if [ ${#ips[@]} -eq 0 ]; then
        local msg="[ERROR] $target (Could not resolve)"
        echo "$msg" | tee -a "$LOG_FILE"
        return
    fi

    for ip in "${ips[@]}"; do
        # Filtering check for IPs starting with 10.
        if [[ $ip =~ ^10\. ]]; then
            domain_buffer+="[FILTERED] $target -> $ip (Blocked/Internal IP)\n"
            continue
        fi

        local result_str="$target -> $ip ->"
        local open_count=0

        for port in "${PORT_ARRAY[@]}"; do
            local port_status="closed"
            for ((i=1; i<=RETRIES; i++)); do
                if nc -z -w "$TIMEOUT" "$ip" "$port" 2>/dev/null; then
                    port_status="open"
                    break
                fi
            done

            if [ "$port_status" = "open" ]; then
                result_str="$result_str ${port}✔"
                ((open_count++))
            else
                result_str="$result_str ${port}✖"
            fi
        done

        if [ $open_count -gt 0 ]; then
            domain_buffer+="[OK] $result_str\n"
        else
            domain_buffer+="[FAIL] $result_str\n"
        fi
    done

    # Print the entire domain block to keep Multi-IPs together
    printf "$domain_buffer" | tee -a "$LOG_FILE"
}

# START LOGGING
{
    echo "Starting SNI Scanner..."
    echo "Scan started at $(date)"
    echo "Targets: $INPUT_FILE | Ports: $PORTS | Timeout: ${TIMEOUT}s | Retries: $RETRIES"
    echo "---------------------------------------------------"
} | tee -a "$LOG_FILE"

# Process loop
while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" =~ ^# ]] && continue
    target=$(echo "$line" | tr -d '\r' | xargs)
    [ -z "$target" ] && continue

    process_target "$target" &

    while [ $(jobs -r | wc -l) -ge $CONCURRENCY ]; do
        sleep 0.1
    done
done < "$INPUT_FILE"

wait

# FINAL SUMMARY REPORT
{
    echo "---------------------------------------------------"
    echo "==================================================="
    echo "                   FINAL SUMMARY                   "
    echo "==================================================="
    echo "" # Space after title

    OK_COUNT=$(grep -c "^\[OK\]" "$LOG_FILE" || true)
    FAIL_COUNT=$(grep -c "^\[FAIL\]" "$LOG_FILE" || true)
    FILTERED_COUNT=$(grep -c "^\[FILTERED\]" "$LOG_FILE" || true)
    ERROR_COUNT=$(grep -c "^\[ERROR\]" "$LOG_FILE" || true)

    if [ "$OK_COUNT" -gt 0 ]; then
        echo "=== OK (at least one open port) [$OK_COUNT] ==="
        echo ""
        grep "^\[OK\]" "$LOG_FILE"
        echo ""
    fi

    if [ "$FAIL_COUNT" -gt 0 ]; then
        echo "=== FAIL (all ports closed) [$FAIL_COUNT] ==="
        echo ""
        grep "^\[FAIL\]" "$LOG_FILE"
        echo ""
    fi

    if [ "$ERROR_COUNT" -gt 0 ]; then
        echo "=== RESOLVE FAILED [$ERROR_COUNT] ==="
        echo ""
        grep "^\[ERROR\]" "$LOG_FILE"
        echo ""
    fi

    if [ "$FILTERED_COUNT" -gt 0 ]; then
        echo "=== FILTERED (Blocked/IP 10.x) [$FILTERED_COUNT] ==="
        echo ""
        grep "^\[FILTERED\]" "$LOG_FILE"
        echo ""
    fi

    echo "---------------------------------------------------"
    echo "Scan fully completed at $(date)"
} | tee -a "$LOG_FILE"

echo ""
echo "Full scan activity and summary saved to: $LOG_FILE"