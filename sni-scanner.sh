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
  dig +short "$1" | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}'
}

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

    if $open_found; then
      ok_list+=("$target -> $ip ->$result")
    else
      fail_list+=("$target -> $ip ->$result")
    fi
  done

done < "$file"

echo "=== OK (at least one open port) ==="
for item in "${ok_list[@]}"; do
  echo "$item"
done

echo
echo "=== FAIL (all ports closed) ==="
for item in "${fail_list[@]}"; do
  echo "$item"
done

echo
echo "=== RESOLVE FAILED ==="
for item in "${resolve_fail_list[@]}"; do
  echo "$item"
done