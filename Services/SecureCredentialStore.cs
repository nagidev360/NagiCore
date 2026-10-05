using System;
using System.IO;
using System.Security.Cryptography;
using System.Text;

namespace NagiCore.Services;

public sealed class SecureCredentialStore
{
    private readonly string directory = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "NagiCore");
    private string PathFor(string name) => Path.Combine(directory, name + ".secret");

    public void Save(string name, string value)
    {
        Directory.CreateDirectory(directory);
        var protectedBytes = ProtectedData.Protect(Encoding.UTF8.GetBytes(value ?? ""), null, DataProtectionScope.CurrentUser);
        var temp = PathFor(name) + ".tmp";
        File.WriteAllBytes(temp, protectedBytes);
        if (File.Exists(PathFor(name))) File.Replace(temp, PathFor(name), null);
        else File.Move(temp, PathFor(name));
    }

    public string Load(string name)
    {
        try
        {
            var path = PathFor(name);
            if (!File.Exists(path)) return null;
            return Encoding.UTF8.GetString(ProtectedData.Unprotect(File.ReadAllBytes(path), null, DataProtectionScope.CurrentUser));
        }
        catch { return null; }
    }

    public void Delete(string name)
    {
        try { if (File.Exists(PathFor(name))) File.Delete(PathFor(name)); } catch { }
    }
}