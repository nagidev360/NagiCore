#define AppName "NagiCore"
#define AppVersion "1.0.0"
#define AppPublisher "NagiDev"
#define AppExeName "NagiCore.exe"

[Setup]
AppId={{B8A0E0D2-7B7D-4A7E-9C4A-7D2E1B9A1C10}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={localappdata}\Programs\NagiCore
DefaultGroupName={#AppName}
OutputDir=..\dist
OutputBaseFilename=NagiCore-Setup
Compression=lzma
SolidCompression=yes
PrivilegesRequired=lowest
WizardStyle=modern
Uninstallable=yes
ArchitecturesAllowed=x86 x64compatible
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
  Result := False;
  if IsWin64 then
    Result := RegQueryDWordValue(HKLM64, 'SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full', 'Release', Release) and (Release >= 528040);
  if not Result then
    Result := RegQueryDWordValue(HKLM32, 'SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full', 'Release', Release) and (Release >= 528040);
  if not Result then
    Result := RegQueryDWordValue(HKLM, 'SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full', 'Release', Release) and (Release >= 528040);
end;

function InitializeSetup(): Boolean;
begin
  Result := True;
  if not IsDotNet48Installed then
  begin
    Log('.NET Framework 4.8 was not detected by installer preflight.');
    if not WizardSilent then
      MsgBox('NagiCore requires Microsoft .NET Framework 4.8 or later. The installer will continue, but NagiCore will report the runtime requirement at startup.', mbInformation, MB_OK);
  end;
end;

[Run]
Filename: "{app}\NagiCore.exe"; Description: "Launch NagiCore"; Flags: nowait postinstall skipifsilent