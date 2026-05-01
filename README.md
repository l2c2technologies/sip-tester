# Koha SIP2 Raw Socket Tester

A menu-driven SIP2 raw socket tester for Koha with automatic checksum generation.

## Why this exists
Testing Koha SIP2 over a `RAW` transport socket (e.g., port 6001) using standard tools like `netcat` or `telnet` often fails due to strict `\r` line terminator requirements and Koha's tendency to drop unauthenticated connections. This script bypasses those traps by establishing a stateful `/dev/tcp` connection, managing the login sequence automatically, and calculating valid SIP2 checksums on the fly.

## Usage
Run the script with elevated privileges (required to parse the Koha `SIPconfig.xml`):
```bash
chmod +x sip_tester.sh
sudo ./sip_tester.sh
