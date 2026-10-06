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

### Professional one-click developer setup

Run **Setup-NagiCore-Dev.bat** from the repository root as Administrator.

The bootstrap:
- detects the Windows build environment
- requires the .NET Framework 4.8 targeting pack
- rejects legacy MSBuild 4.x
- prepares a compatible MSBuild and C# compiler toolchain without Visual Studio Installer
- restores PackageReference dependencies from nuget.org
- builds Release
- runs the real smoke tests
- builds the Inno Setup installer when ISCC is available
- writes detailed logs under `.tools\\logs`

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
