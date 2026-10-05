using System.Net.Http;
using System.Net.Http.Json;
using System.Security.Cryptography;
using System.Text.Json;
namespace NagiCore.Services;
public sealed record LicenseResult(bool Valid,string Reason,string? Product,string? ClientId,DateTimeOffset? IssuedAt,DateTimeOffset? ExpiresAt);
public sealed class LicenseService {
 private const string VerifyUrl="https://nagi-key-4sli.onrender.com/api/key/verify";
 private static readonly HttpClient Http=new(){Timeout=TimeSpan.FromSeconds(12)};
 public static string GetDeviceId(){var raw=Environment.MachineName+"|"+Environment.UserName+"|"+Environment.OSVersion.VersionString;var hash=SHA256.HashData(System.Text.Encoding.UTF8.GetBytes(raw));return Convert.ToHexString(hash)[..32];}
 public async Task<LicenseResult> VerifyAsync(string key){
  try{using var response=await Http.PostAsJsonAsync(VerifyUrl,new{key});var json=await response.Content.ReadFromJsonAsync<JsonElement>();var valid=json.TryGetProperty("valid",out var v)&&v.GetBoolean();var reason=json.TryGetProperty("reason",out var r)?r.GetString()??"UNKNOWN":"UNKNOWN";if(!valid)return new(false,reason,null,null,null,null);
   DateTimeOffset? issued=json.TryGetProperty("issuedAt",out var i)&&DateTimeOffset.TryParse(i.GetString(),out var iv)?iv:null;
   DateTimeOffset? expires=json.TryGetProperty("expiresAt",out var e)&&DateTimeOffset.TryParse(e.GetString(),out var ev)?ev:null;
   var product=json.TryGetProperty("product",out var p)?p.GetString():null;var client=json.TryGetProperty("clientId",out var c)?c.GetString():null;return new(true,reason,product,client,issued,expires);}
  catch(Exception ex){return new(false,"NETWORK_ERROR: "+ex.Message,null,null,null,null);}
 }
}