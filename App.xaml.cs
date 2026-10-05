using System.Windows;
using NagiCore.Services;
namespace NagiCore;
public partial class App : Application
{
    protected override void OnStartup(StartupEventArgs e)
    {
        CrashHandler.Install();
        if (!StartupGuard.TryAcquire())
        {
            MessageBox.Show("NagiCore is already running.", "NagiCore", MessageBoxButton.OK, MessageBoxImage.Information);
            Shutdown();
            return;
        }
        var report = CompatibilityService.Check();
        if (!report.IsSupported)
        {
            MessageBox.Show(report.Details, "NagiCore Compatibility", MessageBoxButton.OK, MessageBoxImage.Error);
            StartupGuard.Release();
            Shutdown();
            return;
        }
        base.OnStartup(e);
    }
    protected override void OnExit(ExitEventArgs e) { StartupGuard.Release(); base.OnExit(e); }
}