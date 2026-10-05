using System; using System.Threading;
namespace NagiCore.Services;
public static class StartupGuard { static Mutex? mutex; public static bool TryAcquire(){bool created; mutex=new Mutex(true,"NagiCore.SingleInstance",out created); if(!created){mutex.Dispose();mutex=null;return false;} return true;} public static void Release(){try{mutex?.ReleaseMutex();}catch{} mutex?.Dispose();mutex=null;} }