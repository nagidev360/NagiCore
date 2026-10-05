using System;
namespace NagiCore.Models;
public sealed class LicenseInfo
{
    public string Key { get; set; }
    public string DeviceId { get; set; }
    public DateTimeOffset? ExpiresAt { get; set; }
    public string Product { get; set; }
    public LicenseInfo() { }
    public LicenseInfo(string key, string deviceId, DateTimeOffset? expiresAt, string product) { Key=key; DeviceId=deviceId; ExpiresAt=expiresAt; Product=product; }
}