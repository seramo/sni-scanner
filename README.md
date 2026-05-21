# SNI Scanner

A lightweight Bash tool to scan common CDN ports on a list of IPs and domains.

## Description

The **SNI Scanner** is a simple Bash-based tool designed to check common HTTPS/CDN ports on multiple IP addresses or domains. It supports mixed input (IPs and domains), automatically resolves domains to IP addresses, and scans a list of ports commonly used by CDN providers like Cloudflare.

The tool provides a clear output indicating which ports are open or closed, supports retries, concurrent scanning, logging, optional IP verification through Cloudflare, and generates a final categorized summary report.

## Features

- IP & Domain Support: Accepts both IP addresses and domain names as input
- Automatic DNS Resolution: Resolves domains to one or more IP addresses
- Custom Port Scanning: Supports custom ports from CLI arguments
- Retry Support: Retries closed ports multiple times
- Concurrent Scanning: Faster scans using background jobs
- Logging System: Saves full activity and summary into a log file
- Detailed Output:
    - Shows open ports (✔)
    - Shows closed ports (✖)
    - Separates successful and failed targets
    - Detects unresolved domains
    - Filters internal/blocked IPs (10.x.x.x)
- Optional IP Verification:
    - Automatically detects your public IP
    - Or allows manual IP input
    - Verifies the IP seen by Cloudflare using `/cdn-cgi/trace`
- Lightweight & Fast: Requires only bash, nc, and dig

## Getting Started

### Prerequisites

- Linux / Unix-based system
- bash
- nc (netcat)
- dig (DNS utilities)
- curl

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
    chmod +x sni-scanner.sh
    ```

## Usage

### Step 1: Prepare Input File

Create a file named `targets.txt`:

```txt
104.19.229.21
example.com
google.com
```

### Step 2: Run the Scanner

Default usage:

```bash
./sni-scanner.sh
```

Custom example:

```bash
./sni-scanner.sh -f my-targets.txt -p 80,443,8443 -t 3 -r 2 -l result.log
```

IP verification (auto detect):

```bash
./sni-scanner.sh -ip
```

IP verification (manual IP):

```bash
./sni-scanner.sh -ip 1.2.3.4
```

## CLI Options

| Option | Default | Description | Example |
|---|---|---|---|
| `-f` | `targets.txt` | Input file containing domains/IPs | `-f my-targets.txt` |
| `-p` | `443,2053,2083,2087,2096,8443` | Comma-separated ports to scan | `-p 80,443,8443` |
| `-t` | `5` | Connection timeout in seconds | `-t 3` |
| `-r` | `3` | Retry count for closed ports | `-r 2` |
| `-l` | `log.txt` | Output log file | `-l result.log` |
| `-ip` | - | Enable IP verification (optional manual IP) | `-ip` or `-ip 1.2.3.4` |
| `-h` | - | Show help menu | `-h` |

## Output Example

```txt
[OK] example.com -> 104.19.229.21 -> 443✔ 2053✔ 2083✖ 2087✖ 2096✖ 8443✔ IP✔

[FAIL] 8.8.8.8 -> 8.8.8.8 -> 443✖ 2053✖ 2083✖ 2087✖ 2096✖ 8443✖

[ERROR] bad-domain.test (Could not resolve)

[FILTERED] internal.test -> 10.0.0.1 (Blocked/Internal IP)
```

## Final Summary

At the end of the scan, the tool generates a categorized summary including:

- OK targets
- IP verified targets
- Failed targets
- Resolve failed targets
- Filtered/internal IPs

## Notes

- This tool performs TCP port checks and optional Cloudflare IP verification
- IP verification uses Cloudflare `/cdn-cgi/trace`
- It does NOT perform real TLS fingerprint spoofing
- Results may vary depending on CDN behavior and network restrictions

## Contribution

Contributions and improvements are welcome. Feel free to submit a Pull Request.