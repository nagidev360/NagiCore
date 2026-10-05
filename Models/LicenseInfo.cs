namespace NagiCore.Models;
public sealed record LicenseInfo(string Key,string DeviceId,DateTimeOffset? ExpiresAt,string? Product);