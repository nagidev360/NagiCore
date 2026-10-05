using System.IO;
using System.Text.Json;
using System.Windows;
using NagiCore.Services;
namespace NagiCore;
public partial class MainWindow:Window{
 readonly LicenseService license=new();
 readonly string stateFile=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"NagiCore","license.json");
 public MainWindow(){InitializeComponent();Loaded+=async(_,_)=>await RestoreLicenseAsync();}
 async Task RestoreLicenseAsync(){try{if(!File.Exists(stateFile))return;var state=JsonSerializer.Deserialize<StoredLicense>(await File.ReadAllTextAsync(stateFile));if(state is null||state.DeviceId!=LicenseService.GetDeviceId()||string.IsNullOrWhiteSpace(state.Key))return;StatusText.Text="Checking saved license…";var result=await license.VerifyAsync(state.Key);if(result.Valid){OpenApp(result);return;}File.Delete(stateFile);StatusText.Text=result.Reason=="EXPIRED"?"License expired. Enter a new key.":"Saved license is no longer valid. Enter a new key.";}catch{StatusText.Text="License state could not be restored. Enter your key again.";}}
 async void Activate_Click(object sender,RoutedEventArgs e){var key=KeyBox.Text.Trim();if(key.Length<10){StatusText.Text="Enter a valid license key.";return;}ActivateButton.IsEnabled=false;StatusText.Text="Verifying license…";var result=await license.VerifyAsync(key);ActivateButton.IsEnabled=true;if(!result.Valid){StatusText.Text=result.Reason=="EXPIRED"?"This key has expired. Please enter a new key.":"License rejected: "+result.Reason;return;}Directory.CreateDirectory(Path.GetDirectoryName(stateFile)!);await File.WriteAllTextAsync(stateFile,JsonSerializer.Serialize(new StoredLicense(key,LicenseService.GetDeviceId(),result.ExpiresAt)));OpenApp(result);}
 void OpenApp(LicenseResult result){KeyBox.Visibility=Visibility.Collapsed;ActivateButton.Visibility=Visibility.Collapsed;TitleText.Text="NagiCore Dashboard";StatusText.Text=$"License active until {result.ExpiresAt?.ToLocalTime():dd MMM yyyy, HH:mm}.\n\nModules are ready to be added.";}
 void Dashboard_Click(object sender,RoutedEventArgs e){TitleText.Text="NagiCore Dashboard";}
 void Module_Click(object sender,RoutedEventArgs e){StatusText.Text="Module shell ready — implementation will be added here.";}
 sealed record StoredLicense(string Key,string DeviceId,DateTimeOffset? ExpiresAt);
}