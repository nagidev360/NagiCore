@echo off
setlocal EnableExtensions DisableDelayedExpansion
title NagiCore Developer Setup

rem NagiCore Developer Bootstrap
cd /d "%~dp0"

echo.
echo ============================================================
echo                 NagiCore Developer Setup
echo ============================================================
echo.
echo Project: %CD%
echo.

net session >nul 2>&1
if not "%errorlevel%"=="0" (
    echo Requesting Administrator permission...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b 0
)

set "MSBUILD_EXE="
set "ISCC_EXE="
call :find_msbuild
call :find_iscc

echo [1/4] Checking required build tools...
echo.

call :ensure_supported_msbuild
if errorlevel 1 (
    echo Legacy or unavailable MSBuild detected.
    set "MSBUILD_EXE="
    set "MSBUILD_MAJOR="
)

if not defined MSBUILD_EXE (
    echo MSBuild 15+ was not found.
    echo Bootstrapping portable MSBuild without Visual Studio Installer...
    call :install_vs_buildtools
    if errorlevel 1 goto :failed
    call :find_msbuild
)
if not defined MSBUILD_EXE (
    echo ERROR: Compatible MSBuild is still not available after bootstrap.
    goto :failed
)
call :get_msbuild_major
if errorlevel 1 goto :failed
if %MSBUILD_MAJOR% LSS 15 (
    echo ERROR: Bootstrap produced an unsupported MSBuild version: %MSBUILD_MAJOR%.
    goto :failed
)
echo.
echo [2/4] Configuring machine PATH...
for %%P in ("%MSBUILD_EXE%") do call :add_to_path "%%~dpP"

echo.
echo MSBuild: %MSBUILD_EXE%

echo.
echo [3/4] Restoring and building NagiCore...
if not exist "NagiCore.csproj" (
    echo ERROR: NagiCore.csproj was not found.
    echo Run this script from the NagiCore repository folder.
    goto :failed
)
if exist "bin\Release" rmdir /s /q "bin\Release" >nul 2>&1
if exist "obj\Release" rmdir /s /q "obj\Release" >nul 2>&1

call :get_msbuild_major
if defined MSBUILD_MAJOR if %MSBUILD_MAJOR% GEQ 15 (
    "%MSBUILD_EXE%" "NagiCore.csproj" /restore /p:Configuration=Release /m
) else (
    echo ERROR: The detected MSBuild is too old for this project.
    echo NagiCore requires MSBuild 15 or newer because it uses PackageReference.
    echo MSBuild 4.x cannot process /restore or the current project dependencies.
    goto :failed
)
if errorlevel 1 (
    echo ERROR: NagiCore build failed.
    goto :failed
)

echo.
echo [4/4] Building NagiCore installer...
call :find_iscc
if not defined ISCC_EXE (
    echo Inno Setup compiler was not found. Trying to install it...
    call :install_innosetup
    call :find_iscc
)

if defined ISCC_EXE (
    call :add_to_path "%~dp0"
    for %%P in ("%ISCC_EXE%") do call :add_to_path "%%~dpP"
    if not exist "installer\NagiCoreInstaller.iss" (
        echo WARNING: installer\NagiCoreInstaller.iss was not found.
    ) else (
        if not exist "dist" mkdir "dist"
        "%ISCC_EXE%" "installer\NagiCoreInstaller.iss"
        if errorlevel 1 (
            echo WARNING: Inno Setup compilation failed. The application EXE is still available.
        )
    )
) else (
    echo WARNING: Inno Setup is unavailable on this Windows installation.
    echo The application EXE was built successfully; installer creation was skipped.
)

if not exist "bin\Release\NagiCore.exe" (
    echo ERROR: NagiCore.exe was not produced.
    goto :failed
)

echo.
echo ============================================================
echo                    BUILD SUCCESSFUL
echo ============================================================
echo.
echo Application: %CD%\bin\Release\NagiCore.exe
if exist "dist\NagiCore-Setup.exe" echo Installer:   %CD%\dist\NagiCore-Setup.exe
echo.
echo Double-click NagiCore.exe to run the application.
if exist "dist\NagiCore-Setup.exe" echo Or double-click NagiCore-Setup.exe to install it.
echo.
pause
exit /b 0

:find_msbuild
set "MSBUILD_EXE="
rem Prefer the repo-local portable MSBuild runtime so this script does not require Visual Studio or Visual Studio Installer.
for /f "delims=" %%P in ('dir /b /s ".tools\msbuild-runtime\MSBuild.exe" 2^>nul') do if not defined MSBUILD_EXE set "MSBUILD_EXE=%%P"
if defined MSBUILD_EXE exit /b 0

rem Use an already-installed MSBuild if one exists.
for %%P in (
    "%ProgramFiles%\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe"
    "%ProgramFiles%\Microsoft Visual Studio\2026\BuildTools\MSBuild\Current\Bin\MSBuild.exe"
    "%ProgramFiles(x86)%\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe"
    "%ProgramFiles(x86)%\Microsoft Visual Studio\2019\BuildTools\MSBuild\Current\Bin\MSBuild.exe"
) do if not defined MSBUILD_EXE if exist "%%~P" set "MSBUILD_EXE=%%~P"
exit /b 0
:ensure_supported_msbuild
if not defined MSBUILD_EXE exit /b 1
call :get_msbuild_major
if errorlevel 1 exit /b 1
if %MSBUILD_MAJOR% LSS 15 exit /b 1
exit /b 0


:get_msbuild_major
set "MSBUILD_MAJOR="
for /f "tokens=1 delims=." %%V in ('"%MSBUILD_EXE%" -version 2^>nul ^| findstr /R "^[0-9]"') do if not defined MSBUILD_MAJOR set "MSBUILD_MAJOR=%%V"
if not defined MSBUILD_MAJOR (
    echo ERROR: Unable to determine MSBuild version.
    exit /b 1
)
echo MSBuild major version: %MSBUILD_MAJOR%
exit /b 0


:find_iscc
set "ISCC_EXE="
for %%P in (
    "%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe"
    "%ProgramFiles%\Inno Setup 6\ISCC.exe"
    "%ProgramFiles(x86)%\Inno Setup 7\ISCC.exe"
    "%ProgramFiles%\Inno Setup 7\ISCC.exe"
) do if not defined ISCC_EXE if exist "%%~P" set "ISCC_EXE=%%~P"
if defined ISCC_EXE exit /b 0
for /f "delims=" %%P in ('where iscc.exe 2^>nul') do if not defined ISCC_EXE set "ISCC_EXE=%%P"
exit /b 0

:install_vs_buildtools
rem Portable build-tool bootstrap: no Visual Studio Installer is used.
rem Microsoft.Build.Runtime provides a complete executable copy of MSBuild.
set "TOOLS_ROOT=%CD%\.tools"
set "MSBUILD_ROOT=%TOOLS_ROOT%\msbuild-runtime"
set "NUGET_EXE=%TOOLS_ROOT%\nuget.exe"
set "NUGET_URL=https://dist.nuget.org/win-x86-commandline/v5.11.6/nuget.exe"
set "NUGET_SHA256=63BA74E6B37A6591520E2CC396099D9913AE4C309FF0D8D953611C63377A514"

if not exist "%TOOLS_ROOT%" mkdir "%TOOLS_ROOT%"
if not exist "%MSBUILD_ROOT%" mkdir "%MSBUILD_ROOT%"

call :find_net48_refs
if not defined NET48_REFS (
    echo .NET Framework 4.8 Developer Pack / targeting pack was not found.
    echo Installing it directly from Microsoft - Visual Studio Installer is not used.
    call :install_net48_devpack
    if errorlevel 1 exit /b 1
    call :find_net48_refs
)
if not defined NET48_REFS (
    echo ERROR: .NET Framework 4.8 targeting pack is still unavailable.
    echo NagiCore targets .NET Framework 4.8 and cannot be built without its reference assemblies.
    exit /b 1
)

if not exist "%NUGET_EXE%" (
    echo Downloading NuGet CLI 5.11.6...
    call :download_file "%NUGET_URL%" "%NUGET_EXE%"
    if errorlevel 1 exit /b 1
)
call :verify_sha256 "%NUGET_EXE%" "%NUGET_SHA256%"
if errorlevel 1 (
    echo ERROR: NuGet CLI SHA-256 verification failed.
    del /q "%NUGET_EXE%" >nul 2>&1
    exit /b 1
)

echo Downloading portable MSBuild Runtime 16.11.6...
"%NUGET_EXE%" install Microsoft.Build.Runtime -Version 16.11.6 -OutputDirectory "%MSBUILD_ROOT%" -Source "https://api.nuget.org/v3/index.json" -NonInteractive -DirectDownload -NoHttpCache -ForceEnglishOutput
if errorlevel 1 (
    echo ERROR: Portable MSBuild Runtime download failed.
    exit /b 1
)

call :find_msbuild
if not defined MSBUILD_EXE (
    echo ERROR: Portable MSBuild.exe was not found after NuGet installation.
    exit /b 1
)
echo Portable MSBuild: %MSBUILD_EXE%
exit /b 0

:find_net48_refs
set "NET48_REFS="
for %%P in (
    "%ProgramFiles(x86)%\Reference Assemblies\Microsoft\Framework\.NETFramework\v4.8\RedistList\FrameworkList.xml"
    "%ProgramFiles%\Reference Assemblies\Microsoft\Framework\.NETFramework\v4.8\RedistList\FrameworkList.xml"
) do if not defined NET48_REFS if exist "%%~P" set "NET48_REFS=%%~dpP"
exit /b 0

:install_net48_devpack
set "DEVPACK=%TEMP%\NDP48-DevPack-ENU.exe"
set "DEVPACK_URL=https://download.microsoft.com/download/6/4/2/642ec242-448b-49a1-8371-5d9c202eaa46/NDP48-DevPack-ENU.exe"

call :download_file "%DEVPACK_URL%" "%DEVPACK%"
if errorlevel 1 (
    echo ERROR: Could not download the official .NET Framework 4.8 Developer Pack.
    echo You can download it manually from:
    echo https://dotnet.microsoft.com/download/dotnet-framework/net48
    exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$s=Get-AuthenticodeSignature -LiteralPath '%DEVPACK%'; if($s.Status -ne 'Valid' -or $s.SignerCertificate.Subject -notmatch 'Microsoft') { exit 1 }"
if errorlevel 1 (
    echo ERROR: .NET Framework Developer Pack signature verification failed.
    del /q "%DEVPACK%" >nul 2>&1
    exit /b 1
)

echo Installing .NET Framework 4.8 Developer Pack...
"%DEVPACK%" /quiet /norestart
set "RC=%errorlevel%"
del /q "%DEVPACK%" >nul 2>&1
if not "%RC%"=="0" if not "%RC%"=="3010" (
    echo ERROR: .NET Framework 4.8 Developer Pack installation failed with code %RC%.
    exit /b 1
)
exit /b 0

:verify_sha256
set "HASH_FILE=%~1"
set "EXPECTED_HASH=%~2"
set "ACTUAL_HASH="
for /f "tokens=1" %%H in ('certutil -hashfile "%HASH_FILE%" SHA256 2^>nul ^| findstr /R /I "^[0-9A-F][0-9A-F]"') do if not defined ACTUAL_HASH set "ACTUAL_HASH=%%H"
if /I "%ACTUAL_HASH%"=="%EXPECTED_HASH%" exit /b 0
exit /b 1


:install_innosetup
set "WINGET="
for /f "delims=" %%P in ('where winget.exe 2^>nul') do if not defined WINGET set "WINGET=%%P"
if defined WINGET (
    echo Installing Inno Setup through winget...
    "%WINGET%" install --id JRSoftware.InnoSetup -e --accept-source-agreements --accept-package-agreements
    if not errorlevel 1 exit /b 0
    echo winget installation failed. Trying download fallback...
)

set "INNO_INSTALLER=%TEMP%\innosetup.exe"
call :download_file "https://jrsoftware.org/download.php/is.exe" "%INNO_INSTALLER%"
if errorlevel 1 (
    echo ERROR: Could not download Inno Setup.
    echo Install Inno Setup manually, then run this script again.
    exit /b 1
)
"%INNO_INSTALLER%" /VERYSILENT /SUPPRESSMSGBOXES /NORESTART
set "RC=%errorlevel%"
del /q "%INNO_INSTALLER%" >nul 2>&1
if not "%RC%"=="0" (
    echo ERROR: Inno Setup installation failed with code %RC%.
    exit /b 1
)
exit /b 0

:download_file
set "DOWNLOAD_URL=%~1"
set "DOWNLOAD_FILE=%~2"
set "CURL_EXE="
if exist "%DOWNLOAD_FILE%" del /q "%DOWNLOAD_FILE%" >nul 2>&1

rem 1) Prefer native curl. No PowerShell TLS enum is used.
for /f "delims=" %%P in ('where curl.exe 2^>nul') do if not defined CURL_EXE set "CURL_EXE=%%P"
if defined CURL_EXE (
    echo Downloading with curl...
    "%CURL_EXE%" -L --fail --retry 3 --connect-timeout 20 --output "%DOWNLOAD_FILE%" "%DOWNLOAD_URL%"
    if not errorlevel 1 call :validate_download && exit /b 0
    if exist "%DOWNLOAD_FILE%" del /q "%DOWNLOAD_FILE%" >nul 2>&1
)

rem 2) Windows certutil uses the OS networking stack and works on older PowerShell.
echo Downloading with Windows certutil...
certutil -urlcache -split -f "%DOWNLOAD_URL%" "%DOWNLOAD_FILE%" >nul 2>&1
if not errorlevel 1 call :validate_download && exit /b 0
if exist "%DOWNLOAD_FILE%" del /q "%DOWNLOAD_FILE%" >nul 2>&1

rem 3) BITS fallback for older Windows installations.
where bitsadmin.exe >nul 2>&1
if not errorlevel 1 (
    echo Downloading with BITS...
    bitsadmin /transfer NagiCoreSetupDownload /priority normal "%DOWNLOAD_URL%" "%DOWNLOAD_FILE%" >nul 2>&1
    if not errorlevel 1 call :validate_download && exit /b 0
    if exist "%DOWNLOAD_FILE%" del /q "%DOWNLOAD_FILE%" >nul 2>&1
)

rem 4) Last resort: open the official URL in the browser for manual download.
echo.
echo Automatic HTTPS download failed on this Windows installation.
echo Opening the official Microsoft download page in your browser...
start "" "%DOWNLOAD_URL%"
echo.
echo IMPORTANT:
echo 1. Download the installer from the official page.
echo 2. Save it EXACTLY as:
echo    %DOWNLOAD_FILE%
echo 3. If the Save dialog does not show that folder, open:
echo    %TEMP%
echo.
echo Waiting for the downloaded file...
:wait_for_download
if exist "%DOWNLOAD_FILE%" (
    call :validate_download
    if not errorlevel 1 exit /b 0
)
choice /C YN /N /M "Is the file saved at the path above? [Y/N]: "
if errorlevel 2 goto :wait_for_download
if exist "%DOWNLOAD_FILE%" call :validate_download && exit /b 0

echo ERROR: Downloaded installer was not found or is incomplete.
exit /b 1

:validate_download
if not exist "%DOWNLOAD_FILE%" exit /b 1
for %%F in ("%DOWNLOAD_FILE%") do if %%~zF GTR 100000 exit /b 0
exit /b 1

:add_to_path
set "ADD_PATH=%~1"
if not exist "%ADD_PATH%" exit /b 0
for /f "tokens=2,*" %%A in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v Path 2^>nul') do if /i "%%A"=="Path" set "MACHINE_PATH=%%B"
echo %MACHINE_PATH% | findstr /I /C:"%ADD_PATH%" >nul
if errorlevel 1 (
    echo Adding to machine PATH: %ADD_PATH%
    set "MACHINE_PATH=%MACHINE_PATH%;%ADD_PATH%"
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v Path /t REG_EXPAND_SZ /d "%MACHINE_PATH%" /f >nul
)
exit /b 0

:failed
echo.
echo ============================================================
echo                       SETUP FAILED
echo ============================================================
echo.
echo No source files were changed by this script.
echo Review the error above, then run this file again.
echo.
pause
exit /b 1
