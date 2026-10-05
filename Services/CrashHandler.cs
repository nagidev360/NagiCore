using System;
using System.Threading.Tasks;
using System.Windows;
namespace NagiCore.Services;
public static class CrashHandler
{
    public static void Install()
    {
        AppDomain.CurrentDomain.UnhandledException += (_, e) => AppLogger.Error("Unhandled exception: " + e.ExceptionObject);
        TaskScheduler.UnobservedTaskException += (_, e) => { AppLogger.Error("Unobserved task exception: " + e.Exception); e.SetObserved(); };
        Application.Current.DispatcherUnhandledException += (_, e) =>
        {
            AppLogger.Error("UI exception: " + e.Exception);
            e.Handled = true;
            MessageBox.Show("NagiCore encountered an unexpected error. Details were saved to the log.", "NagiCore", MessageBoxButton.OK, MessageBoxImage.Error);
        };
    }
}