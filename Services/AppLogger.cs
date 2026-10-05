namespace NagiCore.Services;
public static class AppLogger{
 static readonly string Dir=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"NagiCore","logs");
 public static void Info(string message)=>Write("INFO",message);
 public static void Error(string message)=>Write("ERROR",message);
 static void Write(string level,string message){try{Directory.CreateDirectory(Dir);File.AppendAllText(Path.Combine(Dir,"nagicore.log"),$"[{DateTimeOffset.Now:O}] [{level}] {message}{Environment.NewLine}");}catch{}}
}