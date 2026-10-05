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
Source: "..\bin\Release\*.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\bin\Release\NagiCore.exe.config"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist
[Icons]
Name: "{group}\NagiCore"; Filename: "{app}\NagiCore.exe"
Name: "{autodesktop}\NagiCore"; Filename: "{app}\NagiCore.exe"; Tasks: desktopicon
[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"
[Code]
function IsDotNet48Installed(): Boolean;
var Release: Cardinal;
begin
  Result := RegQueryDWordValue(HKLM64, 'SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full', 'Release', Release) and (Release >= 528040);
  if not Result then
    Result := RegQueryDWordValue(HKLM, 'SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full', 'Release', Release) and (Release >= 528040);
end;

function InitializeSetup(): Boolean;
begin
  Result := IsDotNet48Installed();
  if not Result then
    MsgBox('NagiCore requires Microsoft .NET Framework 4.8. Install it first, then run this installer again.', mbCriticalError, MB_OK);
end;

[Run]
Filename: "{app}\NagiCore.exe"; Description: "Launch NagiCore"; Flags: nowait postinstall skipifsilent