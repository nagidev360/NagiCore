using System;
using System.IO;
namespace NagiCore.Services;
public sealed class CompatibilityReport { public Version WindowsVersion {get;init;}=Environment.OSVersion.Version; public bool Is64Bit {get;init;}=Environment.Is64BitOperatingSystem; public long FreeDiskBytes {get;init;} public bool IsSupported {get;init;} public string Status {get;init;}="UNKNOWN"; public string Details {get;init;}=""; }
public static class CompatibilityService {
 public static CompatibilityReport Check() {
  var v=Environment.OSVersion.Version; var root=Path.GetPathRoot(AppDomain.CurrentDomain.BaseDirectory)??"C:\";
  long free=0; try{free=new DriveInfo(root).AvailableFreeSpace;}catch{}
  bool supported=v.Major>6||(v.Major==6&&v.Minor>=1);
  return new CompatibilityReport{WindowsVersion=v,Is64Bit=Environment.Is64BitOperatingSystem,FreeDiskBytes=free,IsSupported=supported,Status=supported?"COMPATIBLE":"NOT_SUPPORTED",Details=supported?"Windows baseline detected. Optional features are checked individually.":"NagiCore requires Windows 7 SP1 or newer."};
 }
}