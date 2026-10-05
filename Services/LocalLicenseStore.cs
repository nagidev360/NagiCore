using System;
using System.IO;
using System.Security.Cryptography;
using System.Text;
using System.Threading.Tasks;
using System.Web.Script.Serialization;
using NagiCore.Models;

namespace NagiCore.Services;

public sealed class LocalLicenseStore
{
    readonly string file = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "NagiCore", "license.dat");

    public async Task SaveAsync(LicenseInfo info)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(file));
        var json = new JavaScriptSerializer().Serialize(info);
        var bytes = ProtectedData.Protect(Encoding.UTF8.GetBytes(json), null, DataProtectionScope.CurrentUser);
        var temp = file + ".tmp";
        using (var fs = new FileStream(temp, FileMode.Create, FileAccess.Write, FileShare.None, 4096, true))
            await fs.WriteAsync(bytes, 0, bytes.Length).ConfigureAwait(false);
        if (File.Exists(file)) File.Replace(temp, file, null);
        else File.Move(temp, file);
    }

    public async Task<LicenseInfo> LoadAsync()
    {
        if (!File.Exists(file)) return null;
        try
        {
            byte[] bytes;\n            using (var fs = new FileStream(file, FileMode.Open, FileAccess.Read, FileShare.Read, 4096, true))\n            using (var ms = new MemoryStream())\n            {\n                await fs.CopyToAsync(ms).ConfigureAwait(false);\n                bytes = ms.ToArray();\n            }
            var json = Encoding.UTF8.GetString(ProtectedData.Unprotect(bytes, null, DataProtectionScope.CurrentUser));
            return new JavaScriptSerializer().Deserialize<LicenseInfo>(json);
        }
        catch { return null; }
    }

    public void Clear()
    {
        try { if (File.Exists(file)) File.Delete(file); } catch { }
    }
}