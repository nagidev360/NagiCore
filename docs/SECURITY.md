# Security

- No licensing/admin secret is embedded in the desktop client.
- Local license state is protected with Windows DPAPI.
- License verification is server-side.
- Logs avoid storing license keys and credentials.
- Settings writes use temporary files and replacement.
- Update packages must be verified before installation.
- NagiCore does not execute arbitrary user-provided commands.