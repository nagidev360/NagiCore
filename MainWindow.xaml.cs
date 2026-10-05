using System.Windows;
using NagiCore.Models;
using NagiCore.Services;
namespace NagiCore;
public partial class MainWindow:Window{
 readonly LicenseService license=new();
 readonly LocalLicenseStore store=new();
 public MainWindow(){InitializeComponent();Loaded+=async(_,_)=>await RestoreLicenseAsync();}
 async Task RestoreLicenseAsync(){
  try{var state=await store.LoadAsync();if(state is null)return;
   StatusText.Text="Checking saved license…";var result=await license.VerifyAsync(state.Key);
   if(result.Valid){OpenApp(result);return;}store.Clear();StatusText.Text=result.Reason=="EXPIRED"?"License expired. Enter a new key.":"Saved license is no longer valid. Enter a new key.";
  }catch(Exception ex){AppLogger.Error(ex.ToString());StatusText.Text="License state could not be restored. Enter your key again.";}
 }
 async void Activate_Click(object sender,RoutedEventArgs e){
  var key=KeyBox.Text.Trim();if(key.Length<10){StatusText.Text="Enter a valid license key.";return;}
  ActivateButton.IsEnabled=false;StatusText.Text="Verifying license…";
  var result=await license.VerifyAsync(key);ActivateButton.IsEnabled=true;
  if(!result.Valid){StatusText.Text=result.Reason=="EXPIRED"?"This key has expired. Please enter a new key.":"License rejected: "+result.Reason;return;}
  await store.SaveAsync(new LicenseInfo(key,LicenseService.GetDeviceId(),result.ExpiresAt,result.Product));AppLogger.Info("License activated.");OpenApp(result);
 }
 void OpenApp(LicenseResult result){KeyBox.Visibility=Visibility.Collapsed;ActivateButton.Visibility=Visibility.Collapsed;TitleText.Text="NagiCore Dashboard";StatusText.Text=$"License active until {result.ExpiresAt?.ToLocalTime():dd MMM yyyy, HH:mm}.\n\nSelect a module to continue.";}
 void Dashboard_Click(object sender,RoutedEventArgs e){TitleText.Text="NagiCore Dashboard";StatusText.Text="Select a module to continue.";}
 void Module_Click(object sender,RoutedEventArgs e){if(KeyBox.Visibility==Visibility.Visible)return;var b=(System.Windows.Controls.Button)sender;TitleText.Text=b.Content?.ToString()??"Module";StatusText.Text="Module foundation is ready for implementation.";}
}