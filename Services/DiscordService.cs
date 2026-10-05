using System;
using System.Collections.Generic;
using System.Net;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Security;
using System.Text.Json;
using System.Threading.Tasks;

namespace NagiCore.Services;

public sealed class DiscordService
{
    private const string BaseUrl = "https://discord.com/api/v10";
    private readonly HttpClient http;
    public DiscordService()
    {
        ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12;
        http = new HttpClient { Timeout = TimeSpan.FromSeconds(15) };
        http.DefaultRequestHeaders.UserAgent.ParseAdd("NagiCore/1.0 (NagiDev)");
    }

    public async Task<DiscordConnection> ConnectAsync(string token)
    {
        if (string.IsNullOrWhiteSpace(token)) throw new ArgumentException("Bot token is required.");
        using (var request = new HttpRequestMessage(HttpMethod.Get, BaseUrl + "/users/@me"))
        {
            request.Headers.Authorization = new AuthenticationHeaderValue("Bot", token.Trim());
            using (var response = await http.SendAsync(request).ConfigureAwait(true))
            {
                var body = await response.Content.ReadAsStringAsync().ConfigureAwait(true);
                if (!response.IsSuccessStatusCode) throw new InvalidOperationException("Discord rejected the bot token (HTTP " + (int)response.StatusCode + ").");
                using (var doc = JsonDocument.Parse(body))
                {
                    var root = doc.RootElement;
                    return new DiscordConnection(root.GetProperty("id").GetString(), root.GetProperty("username").GetString(), root.TryGetProperty("discriminator", out var d) ? d.GetString() : "0");
                }
            }
        }
    }

    public async Task<string> GetGuildsAsync(string token)
    {
        return await GetAsync("/users/@me/guilds", token).ConfigureAwait(true);
    }

    public async Task<string> GetUserAsync(string token, string userId)
    {
        if (!ulong.TryParse(userId, out _)) throw new ArgumentException("Enter a valid Discord user ID.");
        return await GetAsync("/users/" + userId.Trim(), token).ConfigureAwait(true);
    }

    public async Task<string> GetGuildAsync(string token, string guildId)
    {
        if (!ulong.TryParse(guildId, out _)) throw new ArgumentException("Enter a valid Discord server ID.");
        return await GetAsync("/guilds/" + guildId.Trim(), token).ConfigureAwait(true);
    }

    private async Task<string> GetAsync(string path, string token)
    {
        using (var request = new HttpRequestMessage(HttpMethod.Get, BaseUrl + path))
        {
            request.Headers.Authorization = new AuthenticationHeaderValue("Bot", token.Trim());
            using (var response = await http.SendAsync(request).ConfigureAwait(true))
            {
                var body = await response.Content.ReadAsStringAsync().ConfigureAwait(true);
                if (!response.IsSuccessStatusCode) throw new InvalidOperationException("Discord API error (HTTP " + (int)response.StatusCode + ").");
                return body;
            }
        }
    }
}

public sealed class DiscordConnection
{
    public string Id { get; }
    public string Username { get; }
    public string Discriminator { get; }
    public DiscordConnection(string id, string username, string discriminator) { Id = id; Username = username; Discriminator = discriminator; }
}