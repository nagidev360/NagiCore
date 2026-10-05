# NagiCore
All-in-One Windows Utility Suite

## Modules
- Barcode — barcode/QR generation and image scanning, PNG/PDF export and printing.
- Billing — persistent invoices, accurate decimal calculations, tax/discount, history and CSV/PDF export.
- Diamond — persistent inventory records, CRUD, search/filter and CSV import/export. Market valuation is not invented.
- Discord — secure bot credential storage using Windows DPAPI and Discord API verification.
- Windows — compatibility, CPU/RAM/storage/runtime detection and safe startup configuration.

## Technology
C# / WPF / .NET Framework 4.8.

## Compatibility
- Windows 7 SP1: supported baseline when .NET Framework 4.8 is installed.
- Windows 8.0: explicitly unsupported by the selected .NET Framework 4.8 baseline.
- Windows 8.1, Windows 10 and Windows 11: supported baseline.
Actual feature availability is checked at runtime.

## Build
On Windows with Visual Studio/MSBuild:
```powershell
msbuild NagiCore.csproj /restore /p:Configuration=Release /m
```

Build output: `bin\\Release\\NagiCore.exe`

## Installer
Install Inno Setup, build Release, then:
```powershell
iscc installer\\NagiCoreInstaller.iss
```
Installer output: `dist\\NagiCore-Setup.exe`

The installer checks for .NET Framework 4.8 and bundles application DLL dependencies.

## Data
Application data is stored under `%LOCALAPPDATA%\\NagiCore`, with module data under `data`. Writes use temporary files and backups where applicable.

## License
The client verifies licenses through the existing NAGI.KEY service. License secrets are not embedded in the client. Commercial release still requires server-side one-device binding/revocation enforcement in NAGI.KEY.
