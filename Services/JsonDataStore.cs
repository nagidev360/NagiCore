using System;
using System.IO;
using System.Text;
using System.Web.Script.Serialization;
namespace NagiCore.Services;
public sealed class JsonDataStore<T> where T:new()
{
 readonly string path; readonly string backup; readonly JavaScriptSerializer serializer=new JavaScriptSerializer{MaxJsonLength=int.MaxValue};
 public JsonDataStore(string fileName){var root=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"NagiCore","data");path=Path.Combine(root,fileName);backup=path+".bak";}
 public T Load(){try{if(!File.Exists(path))return new T();var v=serializer.Deserialize<T>(File.ReadAllText(path,Encoding.UTF8));return v==null?new T():v;}catch(Exception ex){AppLogger.Warning("Data load failed: "+Path.GetFileName(path)+": "+ex.Message);try{if(File.Exists(backup)){var v=serializer.Deserialize<T>(File.ReadAllText(backup,Encoding.UTF8));return v==null?new T():v;}}catch(Exception e){AppLogger.Warning("Backup restore failed: "+e.Message);}return new T();}}
 public void Save(T value){var dir=Path.GetDirectoryName(path);Directory.CreateDirectory(dir);var tmp=path+"."+Guid.NewGuid().ToString("N")+".tmp";File.WriteAllText(tmp,serializer.Serialize(value),Encoding.UTF8);if(File.Exists(path)){File.Copy(path,backup,true);File.Replace(tmp,path,null);}else File.Move(tmp,path);}
 public void Backup(){if(File.Exists(path))File.Copy(path,backup,true);}
 public void Restore(){if(!File.Exists(backup))throw new FileNotFoundException("No backup exists.");File.Copy(backup,path,true);}
}