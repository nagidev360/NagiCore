using System;
using System.IO;
using System.Text;
using System.Web.Script.Serialization;
namespace NagiCore.Services;
public sealed class AppSettings { public bool DarkMode{get;set;}=true; public bool StartWithWindows{get;set;}=false; public bool Notifications{get;set;}=true; public bool CheckUpdates{get;set;}=true; }
public sealed class SettingsService {
 readonly string file=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"NagiCore","settings.json");
 public AppSettings Load(){try{if(!File.Exists(file))return new AppSettings();return new JavaScriptSerializer().Deserialize<AppSettings>(File.ReadAllText(file,Encoding.UTF8))??new AppSettings();}catch(Exception ex){AppLogger.Warning("Settings load failed: "+ex.Message);return new AppSettings();}}
 public void Save(AppSettings s){Directory.CreateDirectory(Path.GetDirectoryName(file));var temp=file+".tmp";File.WriteAllText(temp,new JavaScriptSerializer().Serialize(s),Encoding.UTF8);if(File.Exists(file))File.Replace(temp,file,null);else File.Move(temp,file);}
 public void Reset(){try{if(File.Exists(file))File.Delete(file);}catch(Exception ex){AppLogger.Warning("Settings reset failed: "+ex.Message);}}
 public void Export(string destination){var full=Path.GetFullPath(destination);var dir=Path.GetDirectoryName(full);if(string.IsNullOrEmpty(dir))throw new IOException("Invalid destination.");Directory.CreateDirectory(dir);File.Copy(file,full,true);}
 public void Import(string source){var full=Path.GetFullPath(source);var imported=new JavaScriptSerializer().Deserialize<AppSettings>(File.ReadAllText(full,Encoding.UTF8));if(imported==null)throw new InvalidDataException("Invalid NagiCore settings file.");Save(imported);}
}