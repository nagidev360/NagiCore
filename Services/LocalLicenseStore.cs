using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using NagiCore.Models;
namespace NagiCore.Services;
public sealed class LocalLicenseStore{
 readonly string file=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"NagiCore","license.dat");
 public async Task SaveAsync(LicenseInfo info){Directory.CreateDirectory(Path.GetDirectoryName(file)!);var json=JsonSerializer.Serialize(info);var bytes=ProtectedData.Protect(Encoding.UTF8.GetBytes(json),null,DataProtectionScope.CurrentUser);await File.WriteAllBytesAsync(file,bytes);}
 public async Task<LicenseInfo?> LoadAsync(){if(!File.Exists(file))return null;try{var bytes=await File.ReadAllBytesAsync(file);var json=Encoding.UTF8.GetString(ProtectedData.Unprotect(bytes,null,DataProtectionScope.CurrentUser));return JsonSerializer.Deserialize<LicenseInfo>(json);}catch{return null;}}
 public void Clear(){if(File.Exists(file))File.Delete(file);}
}