#!/bin/bash

# SNI Scanner
# Input: targets.txt (IPs + domains)
# Author: SeRaMo ( https://github.com/seramo/ )

file="${1:-targets.txt}"

ports=(443 2053 2083 2087 2096 8443)

if [ ! -f "$file" ]; then
  echo "Error: File '$file' not found"
  exit 1
fi

ok_list=()
fail_list=()
resolve_fail_list=()

# Resolve domain → IP
resolve_domain() {
  dig +short "$1" \
  | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' \
  | grep -vE '^(127\.|10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[0-1])\.|0\.|255\.)' \
  | sort -u
}

echo
echo "=== Checking targets and ports ==="
echo

while IFS= read -r target || [ -n "$target" ]; do
  [[ -z "$target" ]] && continue

  # Detect IP or domain
  if [[ "$target" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    ips=("$target")
  else
    ips=($(resolve_domain "$target"))
  fi

  # Resolve failed
  if [ ${#ips[@]} -eq 0 ]; then
    echo "[RESOLVE FAIL] $target"
    resolve_fail_list+=("$target")
    continue
  fi

  for ip in "${ips[@]}"; do
    result=""
    open_found=false

    for port in "${ports[@]}"; do
      if nc -z -w1 "$ip" "$port" 2>/dev/null; then
        result+=" $port✔"
        open_found=true
      else
        result+=" $port✖"
      fi
    done

    line="$target -> $ip ->$result"

    if $open_found; then
      echo "[OK]   $line"
      ok_list+=("$line")
    else
      echo "[FAIL] $line"
      fail_list+=("$line")
    fi
  done

done < "$file"

if [ ${#ok_list[@]} -eq 0 ] && [ ${#fail_list[@]} -eq 0 ] && [ ${#resolve_fail_list[@]} -eq 0 ]; then
  echo "No results found."
  echo
  exit 0
fi

if [ ${#ok_list[@]} -gt 0 ]; then
  echo
  echo "=== OK (at least one open port) ==="
  echo
  for item in "${ok_list[@]}"; do
    echo "$item"
  done
fi

if [ ${#fail_list[@]} -gt 0 ]; then
  echo
  echo "=== FAIL (all ports closed) ==="
  echo
  for item in "${fail_list[@]}"; do
    echo "$item"
  done
fi

if [ ${#resolve_fail_list[@]} -gt 0 ]; then
  echo
  echo "=== RESOLVE FAILED ==="
  echo
  for item in "${resolve_fail_list[@]}"; do
    echo "$item"
  done
fi

echo