@echo off
setlocal EnableExtensions EnableDelayedExpansion
title NagiCore Professional Developer Setup

rem ============================================================================
rem NagiCore Professional Developer Bootstrap
rem Repository: https://github.com/nagidev360/NagiCore
rem
rem Goals:
rem   - No Visual Studio Installer dependency
rem   - Never select legacy MSBuild 4.x
rem   - Bootstrap a local MSBuild + compiler toolchain when required
rem   - Require .NET Framework 4.8 targeting/reference assemblies
rem   - Restore PackageReference dependencies from nuget.org only
rem   - Build Release
rem   - Run real smoke tests
rem   - Build Inno Setup installer when ISCC is available
rem   - Never modify the repository source files
rem   - Do not permanently modify the machine PATH
rem ============================================================================

cd /d "%~dp0"

set "APP_NAME=NagiCore"
set "PROJECT_FILE=NagiCore.csproj"
set "CONFIGURATION=Release"
set "TOOLS_ROOT=%CD%\.tools"
set "LOG_ROOT=%TOOLS_ROOT%\logs"
set "LOG_FILE=%LOG_ROOT%\setup.log"
set "MSBUILD_ROOT=%TOOLS_ROOT%\msbuild"
set "COMPILER_ROOT=%TOOLS_ROOT%\compiler"
set "NUGET_EXE=%TOOLS_ROOT%\nuget.exe"
set "MSBUILD_EXE="
set "MSBUILD_MAJOR="
set "CSC_EXE="
set "ISCC_EXE="
set "OS_VERSION="
set "OS_MAJOR="
set "OS_MINOR="
set "OS_SP="
set "OS_ARCH="
set "NET48_REFS="
set "EXIT_CODE=1"

if not exist "%TOOLS_ROOT%" mkdir "%TOOLS_ROOT%" >nul 2>&1
if not exist "%LOG_ROOT%" mkdir "%LOG_ROOT%" >nul 2>&1

call :log "============================================================"
call :log "NagiCore Professional Developer Setup"
call :log "Project: %CD%"
call :log "============================================================"

echo.
echo ============================================================
echo             NagiCore Professional Developer Setup
echo ============================================================
echo.
echo Project : %CD%
echo Log     : %LOG_FILE%
echo.

call :require_admin
if errorlevel 1 goto :failed

call :step "1/7" "Detecting operating system and environment"
call :detect_environment
if errorlevel 1 goto :failed

call :step "2/7" "Checking .NET Framework 4.8 targeting pack"
call :ensure_net48
if errorlevel 1 goto :failed

call :step "3/7" "Selecting compatible MSBuild toolchain"
call :ensure_msbuild
if errorlevel 1 goto :failed

call :step "4/7" "Restoring NuGet dependencies"
call :restore_dependencies
if errorlevel 1 goto :failed

call :step "5/7" "Building NagiCore Release"
call :build_application
if errorlevel 1 goto :failed

call :step "6/7" "Running NagiCore smoke tests"
call :run_smoke_tests
if errorlevel 1 goto :failed

call :step "7/7" "Building installer and final verification"
call :build_installer

if not exist "bin\Release\NagiCore.exe" (
    call :error "NagiCore.exe was not produced."
    goto :failed
)

call :sha256 "bin\Release\NagiCore.exe" APP_SHA256

echo.
echo ============================================================
echo                    BUILD SUCCESSFUL
echo ============================================================
echo.
echo Application
echo   %CD%\bin\Release\NagiCore.exe
echo.
echo SHA-256
echo   !APP_SHA256!
echo.
if exist "dist\NagiCore-Setup.exe" (
    call :sha256 "dist\NagiCore-Setup.exe" INSTALLER_SHA256
    echo Installer
    echo   %CD%\dist\NagiCore-Setup.exe
    echo.
    echo Installer SHA-256
    echo   !INSTALLER_SHA256!
    echo.
) else (
    echo Installer
echo   Not built - Inno Setup compiler was unavailable.
echo.
)
echo Toolchain
echo   MSBuild: %MSBUILD_EXE%
echo   C# compiler: %CSC_EXE%
echo.
echo Log
echo   %LOG_FILE%
echo.
echo NagiCore is ready to run.
echo.
call :log "BUILD SUCCESSFUL"
call :log "Application SHA-256: !APP_SHA256!"
if defined INSTALLER_SHA256 call :log "Installer SHA-256: !INSTALLER_SHA256!"
set "EXIT_CODE=0"
pause
exit /b 0

:step
echo.
echo ============================================================
echo [%~1] %~2
echo ============================================================
call :log "[%~1] %~2"
exit /b 0

:info
echo [INFO] %~1
call :log "[INFO] %~1"
exit /b 0

:warn
echo [WARN] %~1
call :log "[WARN] %~1"
exit /b 0

:error
echo [ERROR] %~1
call :log "[ERROR] %~1"
exit /b 0

:log
>>"%LOG_FILE%" echo [%date% %time%] %~1
exit /b 0

:require_admin
net session >nul 2>&1
if not errorlevel 1 (
    call :info "Administrator privileges confirmed."
    exit /b 0
)

call :info "Administrator privileges are required for dependency installation."
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
if errorlevel 1 (
    call :error "Could not request Administrator privileges."
    exit /b 1
)
exit /b 1

:detect_environment
if not exist "%PROJECT_FILE%" (
    call :error "%PROJECT_FILE% was not found. Run this script from the NagiCore repository root."
    exit /b 1
)

for /f "tokens=2 delims==" %%A in ('wmic os get Version /value 2^>nul ^| find "="') do if not defined OS_VERSION set "OS_VERSION=%%A"
if not defined OS_VERSION (
    for /f "delims=" %%A in ('powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "(Get-WmiObject Win32_OperatingSystem).Version" 2^>nul') do if not defined OS_VERSION set "OS_VERSION=%%A"
)

if not defined OS_VERSION (
    call :error "Unable to determine Windows version."
    exit /b 1
)

for /f "tokens=1,2 delims=." %%A in ("!OS_VERSION!") do (
    set "OS_MAJOR=%%A"
    set "OS_MINOR=%%B"
)

for /f "tokens=2 delims==" %%A in ('wmic os get ServicePackMajorVersion /value 2^>nul ^| find "="') do if not defined OS_SP set "OS_SP=%%A"
if not defined OS_SP set "OS_SP=0"

if defined PROCESSOR_ARCHITEW6432 (
    set "OS_ARCH=%PROCESSOR_ARCHITEW6432%"
) else (
    set "OS_ARCH=%PROCESSOR_ARCHITECTURE%"
)

call :info "Windows version: !OS_VERSION!"
call :info "Architecture: !OS_ARCH!"
call :info "Service Pack: !OS_SP!"

if "!OS_MAJOR!"=="6" if "!OS_MINOR!"=="0" (
    call :error "Windows Vista / Server 2008 is not a supported NagiCore build environment."
    exit /b 1
)

if "!OS_MAJOR!"=="6" if "!OS_MINOR!"=="2" (
    call :error "Windows 8.0 is not supported by the NagiCore .NET Framework 4.8 build target."
    call :error "Use Windows 8.1, Windows 10, Windows 11, or Windows 7 SP1."
    exit /b 1
)

if "!OS_MAJOR!"=="6" if "!OS_MINOR!"=="1" if "!OS_SP!"=="0" (
    call :error "Windows 7 SP1 is required for the .NET Framework 4.8 build environment."
    exit /b 1
)

for /f "tokens=2 delims==" %%A in ('wmic computersystem get TotalPhysicalMemory /value 2^>nul ^| find "="') do if not defined TOTAL_RAM set "TOTAL_RAM=%%A"
if defined TOTAL_RAM call :info "RAM detected: !TOTAL_RAM! bytes"

for /f "tokens=2 delims==" %%A in ('wmic logicaldisk where "DeviceID='%SystemDrive%'" get FreeSpace /value 2^>nul ^| find "="') do if not defined FREE_DISK set "FREE_DISK=%%A"
if defined FREE_DISK call :info "Free system-drive space: !FREE_DISK! bytes"

exit /b 0

:ensure_net48
call :find_net48_refs
if defined NET48_REFS (
    call :info ".NET Framework 4.8 reference assemblies found: !NET48_REFS!"
    exit /b 0
)

call :warn ".NET Framework 4.8 Developer Pack / targeting pack is missing."
call :info "The official Microsoft Developer Pack will be downloaded and installed."

set "DEVPACK=%TEMP%\NDP48-DevPack-ENU.exe"
set "DEVPACK_URL=https://download.microsoft.com/download/6/4/2/642ec242-448b-49a1-8371-5d9c202eaa46/NDP48-DevPack-ENU.exe"

call :download "%DEVPACK_URL%" "%DEVPACK%"
if errorlevel 1 (
    call :error "Could not obtain the official .NET Framework 4.8 Developer Pack."
    call :error "Manual source: https://dotnet.microsoft.com/download/dotnet-framework/net48"
    exit /b 1
)

call :verify_microsoft_signature "%DEVPACK%"
if errorlevel 1 (
    call :error "Microsoft Authenticode verification failed for the .NET Developer Pack."
    del /q "%DEVPACK%" >nul 2>&1
    exit /b 1
)

"%DEVPACK%" /quiet /norestart
set "RC=!errorlevel!"
del /q "%DEVPACK%" >nul 2>&1

if not "!RC!"=="0" if not "!RC!"=="3010" (
    call :error ".NET Framework 4.8 Developer Pack installation failed with code !RC!."
    exit /b 1
)

call :find_net48_refs
if not defined NET48_REFS (
    call :error ".NET Framework 4.8 reference assemblies are still missing after installation."
    exit /b 1
)

call :info ".NET Framework 4.8 targeting pack is ready."
exit /b 0

:find_net48_refs
set "NET48_REFS="
for %%P in (
    "%ProgramFiles(x86)%\Reference Assemblies\Microsoft\Framework\.NETFramework\v4.8\RedistList\FrameworkList.xml"
    "%ProgramFiles%\Reference Assemblies\Microsoft\Framework\.NETFramework\v4.8\RedistList\FrameworkList.xml"
) do if not defined NET48_REFS if exist "%%~P" set "NET48_REFS=%%~dpP"
exit /b 0

:ensure_msbuild
set "MSBUILD_EXE="
set "CSC_EXE="

call :find_msbuild
if defined MSBUILD_EXE (
    call :get_msbuild_major
    if not errorlevel 1 if !MSBUILD_MAJOR! GEQ 15 (
        call :info "Using installed MSBuild !MSBUILD_MAJOR!: !MSBUILD_EXE!"
        call :find_csc_near_msbuild
        if defined CSC_EXE (
            call :info "Using installed C# compiler: !CSC_EXE!"
            exit /b 0
        )
        call :warn "Installed MSBuild has no usable C# compiler path. A local compiler toolset will be prepared."
    )
)

call :bootstrap_toolchain
if errorlevel 1 exit /b 1

call :find_msbuild
if not defined MSBUILD_EXE (
    call :error "Portable MSBuild was not found after bootstrap."
    exit /b 1
)

call :get_msbuild_major
if errorlevel 1 exit /b 1
if !MSBUILD_MAJOR! LSS 15 (
    call :error "Portable MSBuild version !MSBUILD_MAJOR! is too old."
    exit /b 1
)

call :find_csc
if not defined CSC_EXE (
    call :error "C# compiler csc.exe was not found in the prepared compiler toolset."
    exit /b 1
)

call :info "Portable MSBuild: !MSBUILD_EXE!"
call :info "Portable C# compiler: !CSC_EXE!"
exit /b 0

:find_msbuild
set "MSBUILD_EXE="

for /f "delims=" %%P in ('dir /b /s "%MSBUILD_ROOT%\MSBuild.exe" 2^>nul') do if not defined MSBUILD_EXE set "MSBUILD_EXE=%%P"
if defined MSBUILD_EXE exit /b 0

for %%P in (
    "%ProgramFiles%\Microsoft Visual Studio\2026\BuildTools\MSBuild\Current\Bin\MSBuild.exe"
    "%ProgramFiles%\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe"
    "%ProgramFiles(x86)%\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe"
    "%ProgramFiles(x86)%\Microsoft Visual Studio\2019\BuildTools\MSBuild\Current\Bin\MSBuild.exe"
) do if not defined MSBUILD_EXE if exist "%%~P" set "MSBUILD_EXE=%%~P"

if defined MSBUILD_EXE exit /b 0

for /f "delims=" %%P in ('where msbuild.exe 2^>nul') do if not defined MSBUILD_EXE set "MSBUILD_EXE=%%P"
exit /b 0

:get_msbuild_major
set "MSBUILD_MAJOR="
for /f "tokens=1 delims=." %%V in ('"!MSBUILD_EXE!" -version 2^>nul ^| findstr /R "^[0-9]"') do if not defined MSBUILD_MAJOR set "MSBUILD_MAJOR=%%V"
if not defined MSBUILD_MAJOR (
    call :error "Unable to determine MSBuild version from !MSBUILD_EXE!."
    exit /b 1
)
exit /b 0

:find_csc_near_msbuild
set "CSC_EXE="
for %%P in ("%MSBUILD_EXE%") do set "MSBUILD_DIR=%%~dpP"
for /f "delims=" %%P in ('dir /b /s "!MSBUILD_DIR!csc.exe" 2^>nul') do if not defined CSC_EXE set "CSC_EXE=%%P"
exit /b 0

:find_csc
set "CSC_EXE="
for /f "delims=" %%P in ('dir /b /s "%COMPILER_ROOT%\csc.exe" 2^>nul') do if not defined CSC_EXE set "CSC_EXE=%%P"
exit /b 0

:bootstrap_toolchain
set "NUGET_URL=https://dist.nuget.org/win-x86-commandline/v5.11.6/nuget.exe"
set "NUGET_SHA256=63BA74E6B37A6591520E2CC396099D9913AE4C309FF0D8D953611C63377A514"
set "MSBUILD_PACKAGE=Microsoft.Build.Runtime"
set "MSBUILD_VERSION=16.11.6"
set "COMPILER_PACKAGE=Microsoft.Net.Compilers.Toolset"
set "COMPILER_VERSION=4.8.0"
set "NUGET_SOURCE=https://api.nuget.org/v3/index.json"

if not exist "%MSBUILD_ROOT%" mkdir "%MSBUILD_ROOT%" >nul 2>&1
if not exist "%COMPILER_ROOT%" mkdir "%COMPILER_ROOT%" >nul 2>&1

call :write_nuget_config
if errorlevel 1 exit /b 1

if not exist "%NUGET_EXE%" (
    call :info "Downloading NuGet CLI 5.11.6..."
    call :download "%NUGET_URL%" "%NUGET_EXE%"
    if errorlevel 1 exit /b 1
)

call :verify_sha256 "%NUGET_EXE%" "%NUGET_SHA256%"
if errorlevel 1 (
    call :error "NuGet CLI SHA-256 verification failed."
    del /q "%NUGET_EXE%" >nul 2>&1
    exit /b 1
)

call :info "NuGet CLI integrity verified."

if not exist "%MSBUILD_ROOT%\Microsoft.Build.Runtime.%MSBUILD_VERSION%\MSBuild.exe" (
    call :info "Installing Microsoft.Build.Runtime %MSBUILD_VERSION%..."
    "%NUGET_EXE%" install "%MSBUILD_PACKAGE%" -Version "%MSBUILD_VERSION%" -OutputDirectory "%MSBUILD_ROOT%" -Source "%NUGET_SOURCE%" -ConfigFile "%NUGET_CONFIG%" -NonInteractive -DirectDownload -NoHttpCache -ForceEnglishOutput
    if errorlevel 1 (
        call :error "Microsoft.Build.Runtime installation failed."
        exit /b 1
    )
)

if not exist "%COMPILER_ROOT%\Microsoft.Net.Compilers.Toolset.%COMPILER_VERSION%" (
    call :info "Installing Microsoft.Net.Compilers.Toolset %COMPILER_VERSION%..."
    "%NUGET_EXE%" install "%COMPILER_PACKAGE%" -Version "%COMPILER_VERSION%" -OutputDirectory "%COMPILER_ROOT%" -Source "%NUGET_SOURCE%" -ConfigFile "%NUGET_CONFIG%" -NonInteractive -DirectDownload -NoHttpCache -ForceEnglishOutput
    if errorlevel 1 (
        call :error "Microsoft.Net.Compilers.Toolset installation failed."
        exit /b 1
    )
)

call :verify_nuget_package "%MSBUILD_ROOT%" "Microsoft.Build.Runtime.%MSBUILD_VERSION%.nupkg"
if errorlevel 1 exit /b 1

call :verify_nuget_package "%COMPILER_ROOT%" "Microsoft.Net.Compilers.Toolset.%COMPILER_VERSION%.nupkg"
if errorlevel 1 exit /b 1

call :find_msbuild
call :find_csc

if not defined MSBUILD_EXE (
    call :error "MSBuild.exe was not found in the bootstrapped runtime."
    exit /b 1
)

if not defined CSC_EXE (
    call :error "csc.exe was not found in the bootstrapped compiler toolset."
    exit /b 1
)

exit /b 0

:write_nuget_config
> "%NUGET_CONFIG%" echo ^<?xml version="1.0" encoding="utf-8"?^>
>>"%NUGET_CONFIG%" echo ^<configuration^>
>>"%NUGET_CONFIG%" echo   ^<config^>
>>"%NUGET_CONFIG%" echo     ^<add key="signatureValidationMode" value="require" /^>
>>"%NUGET_CONFIG%" echo   ^</config^>
>>"%NUGET_CONFIG%" echo   ^<packageSources^>
>>"%NUGET_CONFIG%" echo     ^<clear /^>
>>"%NUGET_CONFIG%" echo     ^<add key="nuget.org" value="https://api.nuget.org/v3/index.json" protocolVersion="3" /^>
>>"%NUGET_CONFIG%" echo   ^</packageSources^>
>>"%NUGET_CONFIG%" echo   ^<trustedSigners^>
>>"%NUGET_CONFIG%" echo     ^<repository name="nuget.org" serviceIndex="https://api.nuget.org/v3/index.json"^>
>>"%NUGET_CONFIG%" echo       ^<certificate fingerprint="0E5F38F57DC1BCC806D8494F4F90FBCEDD988B46760709CBEEC6F4219AA6157D" hashAlgorithm="SHA256" allowUntrustedRoot="false" /^>
>>"%NUGET_CONFIG%" echo       ^<certificate fingerprint="5A2901D6ADA3D18260B9C6DFE2133C95D74B9EEF6AE0E5DC334C8454D1477DF4" hashAlgorithm="SHA256" allowUntrustedRoot="false" /^>
>>"%NUGET_CONFIG%" echo       ^<certificate fingerprint="1F4B311D9ACC115C8DC8018B5A49E00FCE6DA8E2855F9F014CA6F34570BC482D" hashAlgorithm="SHA256" allowUntrustedRoot="false" /^>
>>"%NUGET_CONFIG%" echo     ^</repository^>
>>"%NUGET_CONFIG%" echo   ^</trustedSigners^>
>>"%NUGET_CONFIG%" echo ^</configuration^>
if not exist "%NUGET_CONFIG%" (
    call :error "Failed to create the private NuGet trust configuration."
    exit /b 1
)
exit /b 0

:verify_nuget_package
set "PKG_ROOT=%~1"
set "PKG_NAME=%~2"
set "PKG_FILE="
for /f "delims=" %%P in ('dir /b /s "%PKG_ROOT%\%PKG_NAME%" 2^>nul') do if not defined PKG_FILE set "PKG_FILE=%%P"

if not defined PKG_FILE (
    set "GLOBAL_NUGET=%USERPROFILE%\\.nuget\\packages"
    for /f "delims=" %%P in ('dir /b /s "!GLOBAL_NUGET!\\%PKG_NAME%" 2^>nul') do if not defined PKG_FILE set "PKG_FILE=%%P"
)
if not defined PKG_FILE (
    call :error "NuGet package archive for signature verification was not found: %PKG_NAME%"
    exit /b 1
)

"%NUGET_EXE%" verify -All "!PKG_FILE!" -NonInteractive -ForceEnglishOutput
if errorlevel 1 (
    call :error "NuGet package signature verification failed: !PKG_FILE!"
    exit /b 1
)

call :info "NuGet package signature verified: %PKG_NAME%"
exit /b 0

:restore_dependencies
set "RESTORE_LOG=%LOG_ROOT%\restore.log"
del /q "%RESTORE_LOG%" >nul 2>&1

call :info "Restoring PackageReference dependencies from nuget.org."
call :info "No arbitrary package source is used."

"!MSBUILD_EXE!" "%PROJECT_FILE%" -t:Restore -p:Configuration=%CONFIGURATION% -p:RestoreSources=%NUGET_SOURCE% -p:RestoreConfigFile="%NUGET_CONFIG%" -p:RestoreIgnoreFailedSources=false -p:RestoreNoHttpCache=true -v:minimal >"%RESTORE_LOG%" 2>&1
set "RC=!errorlevel!"

type "%RESTORE_LOG%"
if not "!RC!"=="0" (
    call :error "NuGet/MSBuild restore failed. Full restore log: !RESTORE_LOG!"
    exit /b 1
)

call :info "Dependency restore completed successfully."
exit /b 0

:build_application
if exist "bin\Release" rmdir /s /q "bin\Release" >nul 2>&1
if exist "obj\Release" rmdir /s /q "obj\Release" >nul 2>&1

set "BUILD_LOG=%LOG_ROOT%\build.log"
del /q "%BUILD_LOG%" >nul 2>&1

call :info "Building Release configuration."

"!MSBUILD_EXE!" "%PROJECT_FILE%" -p:Configuration=%CONFIGURATION% -p:RestorePackagesPath="%USERPROFILE%\.nuget\packages" -p:CscToolPath="!CSC_EXE:~0,-7!" -p:CscToolExe=csc.exe -m -v:minimal >"%BUILD_LOG%" 2>&1
set "RC=!errorlevel!"

type "%BUILD_LOG%"
if not "!RC!"=="0" (
    call :error "Release build failed. Full build log: !BUILD_LOG!"
    exit /b 1
)

if not exist "bin\Release\NagiCore.exe" (
    call :error "MSBuild returned success but NagiCore.exe is missing."
    exit /b 1
)

call :info "Release build completed."
exit /b 0

:run_smoke_tests
if not exist "tests\SmokeTests.ps1" (
    call :error "tests\SmokeTests.ps1 was not found."
    exit /b 1
)

where powershell.exe >nul 2>&1
if errorlevel 1 (
    call :error "Windows PowerShell is required to run the NagiCore smoke tests."
    exit /b 1
)

set "TEST_LOG=%LOG_ROOT%\smoke-tests.log"
del /q "%TEST_LOG%" >nul 2>&1

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "tests\SmokeTests.ps1" >"%TEST_LOG%" 2>&1
set "RC=!errorlevel!"

type "%TEST_LOG%"
if not "!RC!"=="0" (
    call :error "Smoke tests failed. Full test log: !TEST_LOG!"
    exit /b 1
)

call :info "Smoke tests passed."
exit /b 0

:build_installer
set "ISCC_EXE="
call :find_iscc

if not defined ISCC_EXE (
    call :warn "Inno Setup compiler (ISCC.exe) was not found."
    call :try_install_inno
    call :find_iscc
)

if not defined ISCC_EXE (
    call :warn "Installer build skipped. NagiCore.exe is still available."
    exit /b 0
)

if not exist "installer\NagiCoreInstaller.iss" (
    call :warn "installer\NagiCoreInstaller.iss was not found. Installer build skipped."
    exit /b 0
)

if not exist "dist" mkdir "dist" >nul 2>&1
if exist "dist\NagiCore-Setup.exe" del /q "dist\NagiCore-Setup.exe" >nul 2>&1

call :info "Building NagiCore installer with: !ISCC_EXE!"
"!ISCC_EXE!" "installer\NagiCoreInstaller.iss"
if errorlevel 1 (
    call :warn "Inno Setup compilation failed. Application build remains valid."
    exit /b 0
)

if not exist "dist\NagiCore-Setup.exe" (
    call :warn "Inno Setup reported success but the installer was not found."
    exit /b 0
)

call :info "Installer created successfully."
exit /b 0

:find_iscc
set "ISCC_EXE="
for %%P in (
    "%ProgramFiles(x86)%\Inno Setup 7\ISCC.exe"
    "%ProgramFiles%\Inno Setup 7\ISCC.exe"
    "%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe"
    "%ProgramFiles%\Inno Setup 6\ISCC.exe"
) do if not defined ISCC_EXE if exist "%%~P" set "ISCC_EXE=%%~P"

if defined ISCC_EXE exit /b 0

for /f "delims=" %%P in ('where iscc.exe 2^>nul') do if not defined ISCC_EXE set "ISCC_EXE=%%P"
exit /b 0

:try_install_inno
set "WINGET_EXE="
for /f "delims=" %%P in ('where winget.exe 2^>nul') do if not defined WINGET_EXE set "WINGET_EXE=%%P"

if not defined WINGET_EXE (
    call :warn "winget is unavailable; Inno Setup will not be installed automatically."
    exit /b 0
)

echo.
choice /C YN /N /M "Inno Setup is missing. Install it with winget now? [Y/N]: "
if errorlevel 2 (
    call :info "User chose not to install Inno Setup."
    exit /b 0
)

"!WINGET_EXE!" install --id JRSoftware.InnoSetup -e --accept-source-agreements --accept-package-agreements
if errorlevel 1 (
    call :warn "winget could not install Inno Setup."
    exit /b 0
)

call :info "Inno Setup installation completed."
exit /b 0

:verify_microsoft_signature
set "SIGN_FILE=%~1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$s=Get-AuthenticodeSignature -LiteralPath '%SIGN_FILE%'; if($s.Status -ne 'Valid'){exit 1}; if($s.SignerCertificate.Subject -notmatch 'Microsoft'){exit 1}"
exit /b %errorlevel%

:verify_sha256
set "HASH_FILE=%~1"
set "EXPECTED_HASH=%~2"
set "ACTUAL_HASH="

for /f "tokens=1" %%H in ('certutil -hashfile "%HASH_FILE%" SHA256 2^>nul ^| findstr /R /I "^[0-9A-F][0-9A-F]"') do if not defined ACTUAL_HASH set "ACTUAL_HASH=%%H"

if /I "!ACTUAL_HASH!"=="!EXPECTED_HASH!" exit /b 0
exit /b 1

:sha256
set "SHA_FILE=%~1"
set "%~2="
set "TMP_HASH=%TEMP%\nagicoresha_%RANDOM%.txt"
certutil -hashfile "%SHA_FILE%" SHA256 >"%TMP_HASH%" 2>nul
for /f "tokens=1" %%H in ('findstr /R /I "^[0-9A-F][0-9A-F]" "%TMP_HASH%"') do if not defined SHA_RESULT set "SHA_RESULT=%%H"
del /q "%TMP_HASH%" >nul 2>&1
set "%~2=%SHA_RESULT%"
set "SHA_RESULT="
exit /b 0

:download
set "DOWNLOAD_URL=%~1"
set "DOWNLOAD_FILE=%~2"
set "CURL_EXE="

if exist "%DOWNLOAD_FILE%" del /q "%DOWNLOAD_FILE%" >nul 2>&1

for /f "delims=" %%P in ('where curl.exe 2^>nul') do if not defined CURL_EXE set "CURL_EXE=%%P"
if defined CURL_EXE (
    call :info "Downloading with curl."
    "!CURL_EXE!" -L --fail --retry 3 --connect-timeout 20 --output "%DOWNLOAD_FILE%" "%DOWNLOAD_URL%"
    if not errorlevel 1 call :validate_download && exit /b 0
    if exist "%DOWNLOAD_FILE%" del /q "%DOWNLOAD_FILE%" >nul 2>&1
)

where bitsadmin.exe >nul 2>&1
if not errorlevel 1 (
    call :info "Downloading with BITS."
    bitsadmin /transfer NagiCoreBootstrap /priority normal "%DOWNLOAD_URL%" "%DOWNLOAD_FILE%" >nul 2>&1
    if not errorlevel 1 call :validate_download && exit /b 0
    if exist "%DOWNLOAD_FILE%" del /q "%DOWNLOAD_FILE%" >nul 2>&1
)

call :warn "Automatic HTTPS download failed."
call :warn "Opening the official source in the default browser."
start "" "%DOWNLOAD_URL%"

echo.
echo Save the downloaded file exactly here:
echo   %DOWNLOAD_FILE%
echo.
choice /C YN /N /M "Is the file saved at that path? [Y/N]: "
if errorlevel 2 exit /b 1
call :validate_download
if errorlevel 1 (
    call :error "The expected downloaded file was not found or is incomplete."
    exit /b 1
)
exit /b 0

:validate_download
if not exist "%DOWNLOAD_FILE%" exit /b 1
for %%F in ("%DOWNLOAD_FILE%") do if %%~zF GTR 100000 exit /b 0
exit /b 1

:failed
echo.
echo ============================================================
echo                       SETUP FAILED
echo ============================================================
echo.
echo Review the error above.
echo Detailed log:
echo   %LOG_FILE%
echo.
call :log "SETUP FAILED"
pause
exit /b 1
