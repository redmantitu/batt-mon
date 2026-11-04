# Security Policy

## Supported versions

Only the latest release receives security fixes.

## What this app does (and doesn't)

Screen On Time reads the Mac's power source state and screen sleep/wake events through public macOS APIs. It:

- makes **no network connections**
- writes **no files** and collects **no data**
- needs **no special permissions** (no Accessibility, Screen Recording, or Full Disk Access)
- is ad-hoc signed, not notarized; release zips are built by `scripts/release.sh` from this repository

You can verify this yourself: the whole app is a single file, `ScreenOnTime.swift`.

## Reporting a vulnerability

Please **do not open a public issue** for security problems.

Report privately via GitHub: [Report a vulnerability](https://github.com/redmantitu/batt-mon/security/advisories/new).

I aim to acknowledge reports within 7 days and to ship a fix or mitigation for confirmed issues as soon as reasonably possible. Reporters will be credited unless they prefer otherwise.
