# NagiCore
All-in-One Windows Utility Suite

## Build
Install .NET 8 SDK on Windows, then run:
dotnet restore
dotnet build -c Release

Publish:
dotnet publish -c Release -r win-x64 --self-contained true /p:PublishSingleFile=true /p:IncludeNativeLibrariesForSelfExtract=true

The executable will be under bin/Release/net8.0-windows/win-x64/publish/NagiCore.exe.

## License
The client verifies licenses through the existing NAGI.KEY service. License secrets are not embedded in the client.
Strong server-side one-device binding should be added to NAGI.KEY before commercial release.