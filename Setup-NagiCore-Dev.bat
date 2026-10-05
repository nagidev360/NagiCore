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

if defined MSBUILD_EXE if defined ISCC_EXE goto :tools_ready

echo [1/4] Checking required build tools...
echo.

if not defined MSBUILD_EXE (
    echo MSBuild was not found. Installing Visual Studio Build Tools...
    call :install_vs_buildtools
    if errorlevel 1 goto :failed
    call :find_msbuild
)
if not defined MSBUILD_EXE (
    echo ERROR: MSBuild is still not available after installation.
    goto :failed
)

if not defined ISCC_EXE (
    echo Inno Setup compiler was not found. Installing Inno Setup...
    call :install_innosetup
    if errorlevel 1 goto :failed
    call :find_iscc
)
if not defined ISCC_EXE (
    echo ERROR: ISCC.exe is still not available after installation.
    goto :failed
)

:tools_ready
echo.
echo [2/4] Configuring machine PATH...
for %%P in ("%MSBUILD_EXE%") do call :add_to_path "%%~dpP"
for %%P in ("%ISCC_EXE%") do call :add_to_path "%%~dpP"

echo.
echo MSBuild: %MSBUILD_EXE%
echo ISCC:    %ISCC_EXE%

echo.
echo [3/4] Restoring and building NagiCore...
if not exist "NagiCore.csproj" (
    echo ERROR: NagiCore.csproj was not found.
    echo Run this script from the NagiCore repository folder.
    goto :failed
)
if exist "bin\Release" rmdir /s /q "bin\Release" >nul 2>&1
if exist "obj\Release" rmdir /s /q "obj\Release" >nul 2>&1

"%MSBUILD_EXE%" "NagiCore.csproj" /restore /p:Configuration=Release /m
if errorlevel 1 (
    echo ERROR: NagiCore build failed.
    goto :failed
)

echo.
echo [4/4] Building NagiCore installer...
if not exist "installer\NagiCoreInstaller.iss" (
    echo ERROR: installer\NagiCoreInstaller.iss was not found.
    goto :failed
)
if not exist "dist" mkdir "dist"

"%ISCC_EXE%" "installer\NagiCoreInstaller.iss"
if errorlevel 1 (
    echo ERROR: Inno Setup compilation failed.
    goto :failed
)
if not exist "dist\NagiCore-Setup.exe" (
    echo ERROR: Installer output was not found.
    goto :failed
)

echo.
echo ============================================================
echo                    BUILD SUCCESSFUL
echo ============================================================
echo.
echo Application: %CD%\bin\Release\NagiCore.exe
echo Installer:   %CD%\dist\NagiCore-Setup.exe
echo.
echo You can now double-click NagiCore-Setup.exe to install.
echo.
pause
exit /b 0

:find_msbuild
set "MSBUILD_EXE="
for %%P in (
    "%ProgramFiles%\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe"
    "%ProgramFiles%\Microsoft Visual Studio\2026\BuildTools\MSBuild\Current\Bin\MSBuild.exe"
    "%ProgramFiles(x86)%\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe"
    "%ProgramFiles(x86)%\Microsoft Visual Studio\2019\BuildTools\MSBuild\Current\Bin\MSBuild.exe"
) do if not defined MSBUILD_EXE if exist "%%~P" set "MSBUILD_EXE=%%~P"
if defined MSBUILD_EXE exit /b 0
set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
if exist "%VSWHERE%" (
    for /f "usebackq delims=" %%P in (`"%VSWHERE%" -latest -products * -requires Microsoft.Component.MSBuild -find MSBuild\**\Bin\MSBuild.exe 2^>nul`) do if not defined MSBUILD_EXE set "MSBUILD_EXE=%%P"
)
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
set "WINGET="
for /f "delims=" %%P in ('where winget.exe 2^>nul') do if not defined WINGET set "WINGET=%%P"
if defined WINGET (
    echo Installing Microsoft Visual Studio Build Tools through winget...
    "%WINGET%" install --id Microsoft.VisualStudio.2022.BuildTools -e --accept-source-agreements --accept-package-agreements --override "--quiet --wait --norestart --add Microsoft.VisualStudio.Workload.ManagedDesktopBuildTools --add Microsoft.Net.Component.4.8.TargetingPack --includeRecommended"
    if not errorlevel 1 exit /b 0
    echo winget installation failed. Trying download fallback...
)

set "VS_BOOTSTRAPPER=%TEMP%\vs_buildtools.exe"
call :download_file "https://aka.ms/vs/17/release/vs_buildtools.exe" "%VS_BOOTSTRAPPER%"
if errorlevel 1 (
    echo ERROR: Could not download Visual Studio Build Tools.
    echo Install Microsoft Visual Studio Build Tools manually, then run this script again.
    exit /b 1
)
"%VS_BOOTSTRAPPER%" --quiet --wait --norestart --add Microsoft.VisualStudio.Workload.ManagedDesktopBuildTools --add Microsoft.Net.Component.4.8.TargetingPack --includeRecommended
set "RC=%errorlevel%"
del /q "%VS_BOOTSTRAPPER%" >nul 2>&1
if not "%RC%"=="0" if not "%RC%"=="3010" (
    echo ERROR: Visual Studio Build Tools installation failed with code %RC%.
    exit /b 1
)
exit /b 0

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
echo Opening the official download URL in your browser...
start "" "%DOWNLOAD_URL%"
echo.
echo Save the downloaded file as:
echo   %DOWNLOAD_FILE%
echo Then press any key to continue.
pause >nul
if exist "%DOWNLOAD_FILE%" call :validate_download && exit /b 0

echo ERROR: Download could not be completed automatically.
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
