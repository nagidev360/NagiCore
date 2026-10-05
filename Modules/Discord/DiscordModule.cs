namespace NagiCore.Modules.Discord;

public sealed class DiscordModule
{
    public string Name => "Discord Tools";
    public string Description => "Secure Discord bot connection, server/user lookup and developer utilities.";
    public string SecurityModel => "Bot credentials are encrypted with Windows DPAPI and never written to application logs.";
}