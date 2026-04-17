# SNI Scanner

A lightweight Bash tool to scan common CDN ports on a list of IPs and domains.

## Description

The **SNI Scanner** is a simple Bash-based tool designed to check common HTTPS/CDN ports on multiple IP addresses or domains. It supports mixed input (IPs and domains), automatically resolves domains to IP addresses, and scans a predefined list of ports commonly used by CDN providers like Cloudflare.

The tool provides a clear output indicating which ports are open or closed, helping users quickly identify reachable endpoints.

## Features

- IP & Domain Support: Accepts both IP addresses and domain names as input
- Automatic DNS Resolution: Resolves domains to one or more IP addresses
- CDN Port Scanning: Scans common HTTPS/CDN ports
- Detailed Output:
    - Shows open ports (✔)
    - Shows closed ports (✖)
    - Separates successful and failed targets
- Lightweight & Fast: Requires only bash, nc, and dig

## Getting Started

### Prerequisites

- Linux / Unix-based system
- bash
- nc (netcat)
- dig (DNS utilities)

### Installation

1. Clone the repository:

    ```bash
    git clone https://github.com/seramo/sni-scanner.git
   ```

2. Navigate to the project directory:

    ```bash
    cd sni-scanner
    ```
   
3. Make the script executable:

    ```bash
    chmod +x scanner.sh
    ```
   
## Usage

### Step 1: Prepare Input File

Create a file named targets.txt:

```txt
104.19.229.21
example.com
google.com
```

### Step 2: Run the Scanner

```bash
./scanner.sh
```

Or specify a custom file:

```bash
./scanner.sh my-targets.txt
```

## Scanned Ports

443, 2053, 2083, 2087, 2096, 8443

## Output Example

```txt
=== OK (at least one open port) ===
example.com -> 104.19.229.21 -> 443✔ 2053✔ 2083✖ 2087✖ 2096✖ 8443✔

=== FAIL (all ports closed) ===
8.8.8.8 -> 8.8.8.8 -> 443✖ 2053✖ 2083✖ 2087✖ 2096✖ 8443✖

=== RESOLVE FAILED ===
bad-domain.test
```

## Notes

- This tool performs basic TCP port checks only
- It does NOT perform real SNI spoofing or TLS validation
- Results may vary depending on CDN behavior and network restrictions

## Contribution

Contributions and improvements are welcome. Feel free to submit a Pull Request.