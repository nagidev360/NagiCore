using System;
using System.Net;
using System.Net.Http;
using System.Security.Cryptography;
using System.Text;
using System.Threading.Tasks;
using System.Web.Script.Serialization;

namespace NagiCore.Services;

public sealed class LicenseResult
{
    public bool Valid { get; set; }
    public string Reason { get; set; } = "UNKNOWN";
    public string Product { get; set; }
    public string ClientId { get; set; }
    public DateTimeOffset? IssuedAt { get; set; }
    public DateTimeOffset? ExpiresAt { get; set; }
}

public sealed class LicenseService
{
    private const string VerifyUrl = "https://nagi-key-4sli.onrender.com/api/key/verify";
    private static readonly HttpClient Http = CreateClient();

    private static HttpClient CreateClient()
    {
        ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12;
        var c = new HttpClient();
        c.Timeout = TimeSpan.FromSeconds(12);
        c.DefaultRequestHeaders.UserAgent.ParseAdd("NagiCore/1.0");
        return c;
    }

    public static string GetDeviceId()
    {
        var raw = Environment.MachineName + "|" + Environment.UserName + "|" + Environment.OSVersion.VersionString;
        using (var sha = SHA256.Create())
        {
            var hash = sha.ComputeHash(Encoding.UTF8.GetBytes(raw));
            var sb = new StringBuilder();
            foreach (var b in hash) sb.Append(b.ToString("X2"));
            return sb.ToString().Substring(0, 32);
        }
    }

    public async Task<LicenseResult> VerifyAsync(string key)
    {
        try
        {
            var payload = new JavaScriptSerializer().Serialize(new { key = key });
            using (var content = new StringContent(payload, Encoding.UTF8, "application/json"))
            using (var response = await Http.PostAsync(VerifyUrl, content).ConfigureAwait(true))
            {
                var json = await response.Content.ReadAsStringAsync().ConfigureAwait(true);
                if (!response.IsSuccessStatusCode)
                    return new LicenseResult { Valid = false, Reason = "HTTP_" + (int)response.StatusCode };

                var data = new JavaScriptSerializer().DeserializeObject(json) as System.Collections.Generic.Dictionary<string, object>;
                if (data == null) return new LicenseResult { Valid = false, Reason = "INVALID_RESPONSE" };

                bool valid = data.ContainsKey("valid") && data["valid"] is bool && (bool)data["valid"];
                var result = new LicenseResult { Valid = valid, Reason = GetString(data, "reason") ?? "UNKNOWN", Product = GetString(data, "product"), ClientId = GetString(data, "clientId") };
                DateTimeOffset parsed;
                if (DateTimeOffset.TryParse(GetString(data, "issuedAt"), out parsed)) result.IssuedAt = parsed;
                if (DateTimeOffset.TryParse(GetString(data, "expiresAt"), out parsed)) result.ExpiresAt = parsed;
                return result;
            }
        }
        catch (Exception ex)
        {
            return new LicenseResult { Valid = false, Reason = "NETWORK_ERROR: " + ex.Message };
        }
    }

    private static string GetString(System.Collections.Generic.Dictionary<string, object> data, string key)
    {
        object value;
        return data.TryGetValue(key, out value) ? value as string : null;
    }
}