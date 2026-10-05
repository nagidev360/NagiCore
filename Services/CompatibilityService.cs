using System;
using System.IO;
namespace NagiCore.Services;
public sealed class CompatibilityReport
{
    public Version WindowsVersion { get; init; } = Environment.OSVersion.Version;
    public bool Is64Bit { get; init; } = Environment.Is64BitOperatingSystem;
    public long FreeDiskBytes { get; init; }
    public bool IsSupported { get; init; }
    public string Status { get; init; } = "UNKNOWN";
    public string Details { get; init; } = "";
}
public static class CompatibilityService
{
    public static CompatibilityReport Check()
    {
        var v = Environment.OSVersion.Version;
        var root = Path.GetPathRoot(AppDomain.CurrentDomain.BaseDirectory) ?? "C:\\";
        long free = 0;
        try { free = new DriveInfo(root).AvailableFreeSpace; } catch { }
        var isWin7 = v.Major == 6 && v.Minor == 1;
        var isWin8 = v.Major == 6 && v.Minor == 2;
        var isWin81 = v.Major == 6 && v.Minor == 3;
        var isModern = v.Major >= 10;
        var supported = isWin7 || isWin81 || isModern;
        var status = supported ? (isWin8 ? "WARNING" : "PASS") : "ERROR";
        var details = isWin8
            ? "Windows 8.0 is not supported by the .NET Framework 4.8 baseline. Upgrade to Windows 8.1 or newer."
            : supported ? "Windows baseline is supported. Individual features may report additional requirements."
            : "NagiCore requires Windows 7 SP1, Windows 8.1, Windows 10 or Windows 11.";
        return new CompatibilityReport { WindowsVersion = v, Is64Bit = Environment.Is64BitOperatingSystem, FreeDiskBytes = free, IsSupported = supported, Status = status, Details = details };
    }
}