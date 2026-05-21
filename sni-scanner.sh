#!/bin/bash

# Default configurations
INPUT_FILE="targets.txt"
PORTS="443,2053,2083,2087,2096,8443"
TIMEOUT=5
RETRIES=3
LOG_FILE="log.txt"
CONCURRENCY=20

ENABLE_IP_CHECK=false
MANUAL_IP=""
USER_IP_API="http://chabokan.net/ip/"

usage() {
    echo "Usage: $0 [-f file] [-p ports] [-t timeout] [-r retries] [-l log_file] [-ip [IP]]"
    echo "  -f    Input file containing domains/IPs"
    echo "  -p    Comma-separated ports"
    echo "  -t    Timeout in seconds"
    echo "  -r    Number of retries"
    echo "  -l    Output log file"
    echo "  -ip   Enable IP verification (optional manual IP)"
    exit 1
}

# Parse CLI arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -f)
            INPUT_FILE="$2"
            shift 2
            ;;
        -p)
            PORTS="$2"
            shift 2
            ;;
        -t)
            TIMEOUT="$2"
            shift 2
            ;;
        -r)
            RETRIES="$2"
            shift 2
            ;;
        -l)
            LOG_FILE="$2"
            shift 2
            ;;
        -ip)
            ENABLE_IP_CHECK=true

            if [[ -n "$2" && ! "$2" =~ ^- ]]; then
                MANUAL_IP="$2"
                shift 2
            else
                shift
            fi
            ;;
        -h|--help)
            usage
            ;;
        *)
            usage
            ;;
    esac
done

if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: Input file '$INPUT_FILE' not found!"
    exit 1
fi

IFS=',' read -r -a PORT_ARRAY <<< "$PORTS"

# Initialize/Clear log file
> "$LOG_FILE"

get_user_public_ip() {
    local ip=""

    for i in {1..3}; do
        ip=$(curl -s --connect-timeout 10 --max-time 20 "$USER_IP_API" 2>/dev/null \
            | grep -oE '"ip"[[:space:]]*:[[:space:]]*"[^"]+"' \
            | cut -d'"' -f4)

        if [ -n "$ip" ]; then
            echo "$ip"
            return
        fi

        sleep 1
    done
}

USER_PUBLIC_IP=""

if [ "$ENABLE_IP_CHECK" = true ]; then

    if [ -n "$MANUAL_IP" ]; then
        USER_PUBLIC_IP="$MANUAL_IP"
        echo "[INFO] Using Manual IP: $USER_PUBLIC_IP" | tee -a "$LOG_FILE"
    else
        USER_PUBLIC_IP=$(get_user_public_ip)

        if [ -n "$USER_PUBLIC_IP" ]; then
            echo "[INFO] Auto Detected IP: $USER_PUBLIC_IP" | tee -a "$LOG_FILE"
        fi
    fi

    if [ -z "$USER_PUBLIC_IP" ]; then
        echo "[WARNING] Could not detect your public IP" | tee -a "$LOG_FILE"
    fi
fi

check_ip() {
    local domain=$1
    local ip=$2

    local detected_ip

    detected_ip=$(curl -sk \
        --connect-timeout 10 \
        --max-time 20 \
        --resolve "${domain}:443:${ip}" \
        "https://${domain}/cdn-cgi/trace" 2>/dev/null \
        | grep '^ip=' \
        | cut -d'=' -f2)

    if [ -z "$detected_ip" ]; then
        echo " IP✖"
        return
    fi

    if [ "$detected_ip" = "$USER_PUBLIC_IP" ]; then
        echo " IP✔"
    else
        echo " IP✖($detected_ip)"
    fi
}

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

            if [ "$ENABLE_IP_CHECK" = true ] && [ -n "$USER_PUBLIC_IP" ]; then
                ip_result=$(check_ip "$target" "$ip")
                domain_buffer+="[OK] $result_str$ip_result\n"
            else
                domain_buffer+="[OK] $result_str\n"
            fi

        else
            domain_buffer+="[FAIL] $result_str\n"
        fi
    done

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
    echo ""

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