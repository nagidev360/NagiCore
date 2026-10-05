#define AppName "NagiCore"
#define AppVersion "1.0.0"
#define AppPublisher "NagiDev"
#define AppExeName "NagiCore.exe"

[Setup]
AppId={{B8A0E0D2-7B7D-4A7E-9C4A-7D2E1B9A1C10}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={autopf}\NagiCore
DefaultGroupName={#AppName}
OutputDir=..\dist
OutputBaseFilename=NagiCore-Setup
Compression=lzma
SolidCompression=yes
PrivilegesRequired=lowest
WizardStyle=modern
Uninstallable=yes
ArchitecturesAllowed=x86 x64
[Files]
Source: "..\bin\Release\NagiCore.exe"; DestDir: "{app}"; Flags: ignoreversion
[Icons]
Name: "{group}\NagiCore"; Filename: "{app}\NagiCore.exe"
Name: "{autodesktop}\NagiCore"; Filename: "{app}\NagiCore.exe"; Tasks: desktopicon
[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"
[Run]
Filename: "{app}\NagiCore.exe"; Description: "Launch NagiCore"; Flags: nowait postinstall skipifsilent