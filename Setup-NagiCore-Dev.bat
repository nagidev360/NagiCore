@echo off
setlocal EnableExtensions DisableDelayedExpansion
title NagiCore Developer Setup

rem ============================================================
rem NagiCore Developer Bootstrap
rem Double-click this file to install/configure build tools and
rem build NagiCore + NagiCore-Setup.exe.
rem ============================================================

cd /d "%~dp0"

echo.
echo ============================================================
echo                 NagiCore Developer Setup
echo ============================================================
echo.
echo Project: %CD%
echo.

rem ---- Self-elevate because Visual Studio Build Tools installation
rem      and machine PATH changes require administrator rights.
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

rem ---- Install Visual Studio Build Tools when MSBuild is missing.
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

rem ---- Install Inno Setup when ISCC is missing.
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
echo [2/4] Configuring current machine PATH...

for %%P in ("%MSBUILD_EXE%") do call :add_to_path "%%~dpP"
for %%P in ("%ISCC_EXE%") do call :add_to_path "%%~dpP"

rem Refresh this process PATH from the machine PATH.
for /f "tokens=2,*" %%A in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v Path 2^>nul') do if /i "%%A"=="Path" set "PATH=%%B;%PATH%"

echo.
echo MSBuild:
echo   %MSBUILD_EXE%
echo ISCC:
echo   %ISCC_EXE%

echo.
echo Verifying command-line availability...
where msbuild.exe >nul 2>&1
if errorlevel 1 echo WARNING: msbuild is not yet visible to this process. The installed path will be available in a new terminal.
where iscc.exe >nul 2>&1
if errorlevel 1 echo WARNING: iscc is not yet visible to this process. The installed path will be available in a new terminal.

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
    echo ERROR: Installer compilation reported success, but the output was not found:
    echo   %CD%\dist\NagiCore-Setup.exe
    goto :failed
)

echo.
echo ============================================================
echo                    BUILD SUCCESSFUL
echo ============================================================
echo.
echo Application:
echo   %CD%\bin\Release\NagiCore.exe
echo.
echo Installer:
echo   %CD%\dist\NagiCore-Setup.exe
echo.
echo You can now double-click NagiCore-Setup.exe to install.
echo.
pause
exit /b 0

:find_msbuild
set "MSBUILD_EXE="

rem Visual Studio 2022/2026 common locations.
for %%P in (
    "%ProgramFiles%\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe"
    "%ProgramFiles%\Microsoft Visual Studio\2026\BuildTools\MSBuild\Current\Bin\MSBuild.exe"
    "%ProgramFiles(x86)%\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe"
    "%ProgramFiles(x86)%\Microsoft Visual Studio\2019\BuildTools\MSBuild\Current\Bin\MSBuild.exe"
) do if not defined MSBUILD_EXE if exist "%%~P" set "MSBUILD_EXE=%%~P"

if defined MSBUILD_EXE exit /b 0

rem Use vswhere when available.
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
    echo winget installation failed. Trying Microsoft's official bootstrapper...
)

set "VS_BOOTSTRAPPER=%TEMP%\vs_buildtools.exe"
echo Downloading Microsoft Visual Studio Build Tools from Microsoft...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ProgressPreference='SilentlyContinue'; Invoke-WebRequest -UseBasicParsing -Uri 'https://aka.ms/vs/17/release/vs_buildtools.exe' -OutFile '%VS_BOOTSTRAPPER%'"
if errorlevel 1 (
    echo ERROR: Could not download Visual Studio Build Tools.
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
    echo winget installation failed. Trying the official Inno Setup installer...
)

set "INNO_INSTALLER=%TEMP%\innosetup.exe"
echo Downloading Inno Setup from the official publisher...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ProgressPreference='SilentlyContinue'; Invoke-WebRequest -UseBasicParsing -Uri 'https://jrsoftware.org/download.php/is.exe' -OutFile '%INNO_INSTALLER%'"
if errorlevel 1 (
    echo ERROR: Could not download Inno Setup.
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
