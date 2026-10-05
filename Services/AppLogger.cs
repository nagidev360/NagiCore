using System;
using System.IO;
namespace NagiCore.Services;
public static class AppLogger {
 static readonly object Sync=new object();
 static readonly string Dir=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"NagiCore","logs");
 public static void Info(string message)=>Write("INFO",message);
 public static void Warning(string message)=>Write("WARN",message);
 public static void Error(string message)=>Write("ERROR",message);
 static void Write(string level,string message){try{Directory.CreateDirectory(Dir);var safe=(message??"").Replace(Environment.NewLine," ").Replace("\r"," ").Replace("\n"," ");lock(Sync)File.AppendAllText(Path.Combine(Dir,"nagicore.log"),string.Format("[{0:O}] [{1}] {2}{3}",DateTimeOffset.Now,level,safe,Environment.NewLine));}catch{}}
 public static string LogFile=>Path.Combine(Dir,"nagicore.log");
}