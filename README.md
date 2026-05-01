# Koha SIP2 Raw Socket Tester

A menu-driven SIP2 raw socket tester for Koha.

## Why this exists
This establishes a stateful `/dev/tcp` connection, managing the login sequence automatically, and calculating valid SIP2 checksums on the fly.

## Usage
Run the script with elevated privileges (required to parse the Koha `SIPconfig.xml`):
```bash
chmod +x sip_tester.sh
sudo ./sip_tester.sh
