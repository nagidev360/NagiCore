using System;
using System.IO;
using Microsoft.Win32;
using NagiCore.Services;
namespace NagiCore.Modules.Windows;
public sealed class WindowsUtilitiesModule{
 public string Name=>"Windows";public string Description=>"Compatibility, hardware, storage, runtime and safe Windows utilities.";
 public CompatibilityReport GetCompatibility()=>CompatibilityService.Check();public SystemInfoSnapshot GetSystemInfo()=>SystemInfoService.Get();
 public bool IsStartupEnabled(){using(var k=Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Run",false))return k?.GetValue("NagiCore")!=null;}
 public void SetStartup(bool enabled){using(var k=Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Run",true)){if(k==null)throw new InvalidOperationException("Windows startup registry is unavailable.");if(enabled)k.SetValue("NagiCore","""+System.Reflection.Assembly.GetEntryAssembly().Location+""");else k.DeleteValue("NagiCore",false);}}
 public string GetFreeSpace(string drive=null){var root=string.IsNullOrWhiteSpace(drive)?Path.GetPathRoot(AppDomain.CurrentDomain.BaseDirectory):drive;return new DriveInfo(root).AvailableFreeSpace.ToString("N0")+" bytes";}
}