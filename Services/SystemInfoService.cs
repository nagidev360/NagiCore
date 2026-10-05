using System;
using System.IO;
using System.Management;
namespace NagiCore.Services;
public sealed class SystemInfoSnapshot { public string OperatingSystem{get;set;}="";public string Architecture{get;set;}="";public string Cpu{get;set;}="";public string Memory{get;set;}="";public string Storage{get;set;}="";public string Runtime{get;set;}=""; }
public static class SystemInfoService {
 public static SystemInfoSnapshot Get(){var s=new SystemInfoSnapshot{OperatingSystem=Environment.OSVersion.VersionString,Architecture=Environment.Is64BitOperatingSystem?"64-bit":"32-bit",Runtime=Environment.Version.ToString()};try{using(var q=new ManagementObjectSearcher("SELECT Name FROM Win32_Processor"))foreach(ManagementObject m in q.Get()){s.Cpu=m["Name"] as string??"Unknown";break;}}catch{s.Cpu="Unavailable";}try{using(var q=new ManagementObjectSearcher("SELECT TotalVisibleMemorySize FROM Win32_OperatingSystem"))foreach(ManagementObject m in q.Get()){var kb=Convert.ToInt64(m["TotalVisibleMemorySize"]);s.Memory=(kb/1024d/1024d).ToString("0.0")+" GB";break;}}catch{s.Memory="Unavailable";}try{var d=new DriveInfo(Path.GetPathRoot(AppDomain.CurrentDomain.BaseDirectory));s.Storage=(d.AvailableFreeSpace/1024d/1024d/1024d).ToString("0.0")+" GB free";}catch{s.Storage="Unavailable";}return s;}
}