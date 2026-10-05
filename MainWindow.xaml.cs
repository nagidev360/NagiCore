using Microsoft.Win32;
using NagiCore.Models;
using NagiCore.Modules.Barcode;
using NagiCore.Modules.Billing;
using NagiCore.Modules.Diamond;
using NagiCore.Modules.Windows;
using NagiCore.Services;
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Documents;
using System.Windows.Media.Imaging;

namespace NagiCore;

public partial class MainWindow : Window
{
 readonly LicenseService license=new LicenseService();
 readonly LocalLicenseStore store=new LocalLicenseStore();
 readonly SettingsService settings=new SettingsService();
 readonly DiscordService discord=new DiscordService();
 readonly SecureCredentialStore credentials=new SecureCredentialStore();
 readonly BarcodeModule barcode=new BarcodeModule();
 readonly BillingModule billing=new BillingModule();
 readonly DiamondModule diamond=new DiamondModule();
 readonly WindowsUtilitiesModule windows=new WindowsUtilitiesModule();
 readonly List<InvoiceItem> billItems=new List<InvoiceItem>();
 Bitmap barcodeBitmap;
 Invoice selectedInvoice;
 DiamondRecord selectedDiamond;
 AppSettings currentSettings;

 public MainWindow(){
  InitializeComponent();
  currentSettings=settings.Load();
  DarkModeBox.IsChecked=currentSettings.DarkMode;
  NotificationsBox.IsChecked=currentSettings.Notifications;
  UpdatesBox.IsChecked=currentSettings.CheckUpdates;
  Loaded+=async delegate{await RestoreLicenseAsync();ShowPage(DashboardPanel);RefreshDashboard();};
  Closed+=(s,e)=>{if(barcodeBitmap!=null)barcodeBitmap.Dispose();};
 }
 async Task RestoreLicenseAsync(){
  try{
   var state=await store.LoadAsync();
   if(state==null){LicenseDetails.Text="No active license. Enter a key to activate NagiCore.";return;}
   StatusText.Text="Checking saved license...";
   var result=await license.VerifyAsync(state.Key);
   if(result.Valid){LicenseDetails.Text="Active license until "+(result.ExpiresAt.HasValue?result.ExpiresAt.Value.ToLocalTime().ToString("dd MMM yyyy, HH:mm"):"unknown");StatusText.Text="License verified.";return;}
   store.Clear();LicenseDetails.Text="Saved license is no longer valid. Enter a new key.";StatusText.Text="License requires attention.";
  }catch(Exception ex){AppLogger.Error(ex.ToString());StatusText.Text="License state could not be restored.";}
 }
 void ShowPage(UIElement page){
  foreach(var p in new UIElement[]{DashboardPanel,BarcodePanel,BillingPanel,DiamondPanel,DiscordPanel,WindowsPanel,SettingsPanel,LogsPanel,LicensePanel,AboutPanel})p.Visibility=Visibility.Collapsed;
  page.Visibility=Visibility.Visible;
 }
 void Dashboard_Click(object s,RoutedEventArgs e){TitleText.Text="Dashboard";StatusText.Text="Ready";RefreshDashboard();ShowPage(DashboardPanel);}
 void RefreshDashboard(){var r=CompatibilityService.Check();var d=billing.List().Count;var di=diamond.Search().Count;DashboardDetails.Text="Application: NagiCore 1.0.0\nCompatibility: "+r.Status+"\nWindows: "+r.WindowsVersion+"\nArchitecture: "+(r.Is64Bit?"64-bit":"32-bit")+"\nInvoices: "+d+"\nDiamond records: "+di+"\nData: persistent local storage with backup recovery.";}
 void Barcode_Click(object s,RoutedEventArgs e){TitleText.Text="Barcode";StatusText.Text="Barcode and QR tools";ShowPage(BarcodePanel);}
 void Billing_Click(object s,RoutedEventArgs e){TitleText.Text="Billing";StatusText.Text="Invoice management";BillRefresh_Click(null,null);ShowPage(BillingPanel);}
 void Diamond_Click(object s,RoutedEventArgs e){TitleText.Text="Diamond";StatusText.Text="Diamond inventory";DiaRefresh_Click(null,null);ShowPage(DiamondPanel);}
 void Discord_Click(object s,RoutedEventArgs e){TitleText.Text="Discord";StatusText.Text="Discord integration";var token=credentials.Load("discord-bot-token");DiscordTokenBox.Clear();DiscordStatus.Text=string.IsNullOrEmpty(token)?"No bot token stored. Enter one and connect.":"A bot token is securely stored on this Windows account.";ShowPage(DiscordPanel);}
 void Windows_Click(object s,RoutedEventArgs e){TitleText.Text="Windows";StatusText.Text="Compatibility and utilities";WindowsRefresh_Click(null,null);ShowPage(WindowsPanel);}
 void Settings_Click(object s,RoutedEventArgs e){TitleText.Text="Settings";StatusText.Text="Persistent application settings";ShowPage(SettingsPanel);}
 void Logs_Click(object s,RoutedEventArgs e){TitleText.Text="Logs";StatusText.Text="Diagnostics";RefreshLogs_Click(null,null);ShowPage(LogsPanel);}
 void License_Click(object s,RoutedEventArgs e){TitleText.Text="License";StatusText.Text="License management";ShowPage(LicensePanel);}
 void About_Click(object s,RoutedEventArgs e){TitleText.Text="About";StatusText.Text="NagiCore information";ShowPage(AboutPanel);}

 void BarcodeGenerate_Click(object s,RoutedEventArgs e){
  try{
   if(!int.TryParse(BarcodeWidthBox.Text,out var w)||!int.TryParse(BarcodeHeightBox.Text,out var h))throw new ArgumentException("Width and height must be whole numbers.");
   var format=ParseBarcodeFormat((BarcodeFormatBox.SelectedItem as ComboBoxItem)?.Content?.ToString());
   if(barcodeBitmap!=null)barcodeBitmap.Dispose();
   barcodeBitmap=barcode.Generate(BarcodeTextBox.Text,format,w,h);
   BarcodePreview.Source=BitmapSourceFromBitmap(barcodeBitmap);
   BarcodeResultText.Text="Generated "+format+" successfully. The output can be scanned or exported.";
   AppLogger.Info("Barcode generated: "+format);
  }catch(Exception ex){BarcodeResultText.Text=ex.Message;AppLogger.Warning("Barcode generation failed: "+ex.Message);}
 }
 static ZXing.BarcodeFormat ParseBarcodeFormat(string name){
  switch(name){case "CODE_128":return ZXing.BarcodeFormat.CODE_128;case "EAN_13":return ZXing.BarcodeFormat.EAN_13;case "UPC_A":return ZXing.BarcodeFormat.UPC_A;case "DATA_MATRIX":return ZXing.BarcodeFormat.DATA_MATRIX;case "PDF_417":return ZXing.BarcodeFormat.PDF_417;default:return ZXing.BarcodeFormat.QR_CODE;}
 }
 void BarcodeScan_Click(object s,RoutedEventArgs e){
  var d=new OpenFileDialog{Filter="Images|*.png;*.jpg;*.jpeg;*.bmp"};
  if(d.ShowDialog()!=true)return;
  try{using(var img=new Bitmap(d.FileName)){var result=barcode.Scan(img);BarcodeResultText.Text="Detected "+result.Format+": "+result.Text;BarcodeTextBox.Text=result.Text;}StatusText.Text="Barcode scan completed.";}catch(Exception ex){BarcodeResultText.Text=ex.Message;AppLogger.Warning("Barcode scan failed: "+ex.Message);}
 }
 void BarcodePng_Click(object s,RoutedEventArgs e){if(barcodeBitmap==null){BarcodeResultText.Text="Generate a barcode first.";return;}var d=new SaveFileDialog{Filter="PNG image|*.png",FileName="NagiCore-barcode.png"};if(d.ShowDialog()!=true)return;try{barcode.SavePng(barcodeBitmap,d.FileName);StatusText.Text="PNG exported."; }catch(Exception ex){MessageBox.Show(ex.Message,"Barcode",MessageBoxButton.OK,MessageBoxImage.Error);}}
 void BarcodePdf_Click(object s,RoutedEventArgs e){if(barcodeBitmap==null){BarcodeResultText.Text="Generate a barcode first.";return;}var d=new SaveFileDialog{Filter="PDF document|*.pdf",FileName="NagiCore-barcode.pdf"};if(d.ShowDialog()!=true)return;try{barcode.SavePdf(barcodeBitmap,d.FileName,37,15);StatusText.Text="PDF exported."; }catch(Exception ex){MessageBox.Show(ex.Message,"Barcode",MessageBoxButton.OK,MessageBoxImage.Error);}}
 void BarcodePrint_Click(object s,RoutedEventArgs e){if(barcodeBitmap==null){BarcodeResultText.Text="Generate a barcode first.";return;}try{var pd=new PrintDialog();if(pd.ShowDialog()==true){var visual=new System.Windows.Controls.Image{Source=BitmapSourceFromBitmap(barcodeBitmap),Width=pd.PrintableAreaWidth,Height=pd.PrintableAreaHeight,Stretch=System.Windows.Media.Stretch.Uniform};pd.PrintVisual(visual,"NagiCore Barcode");StatusText.Text="Barcode sent to printer.";}}catch(Exception ex){MessageBox.Show(ex.Message,"Print",MessageBoxButton.OK,MessageBoxImage.Error);}}
 static BitmapSource BitmapSourceFromBitmap(Bitmap bmp){using(var ms=new MemoryStream()){bmp.Save(ms,System.Drawing.Imaging.ImageFormat.Png);ms.Position=0;var bi=new BitmapImage();bi.BeginInit();bi.CacheOption=BitmapCacheOption.OnLoad;bi.StreamSource=ms;bi.EndInit();bi.Freeze();return bi;}}
 
 void BillAddItem_Click(object s,RoutedEventArgs e){
  try{
   if(string.IsNullOrWhiteSpace(BillItem.Text))throw new ArgumentException("Item/service description is required.");
   if(!decimal.TryParse(BillQty.Text,NumberStyles.Number,CultureInfo.CurrentCulture,out var qty)||qty<=0)throw new ArgumentException("Quantity must be greater than zero.");
   if(!decimal.TryParse(BillPrice.Text,NumberStyles.Number,CultureInfo.CurrentCulture,out var price)||price<0)throw new ArgumentException("Price is invalid.");
   if(!decimal.TryParse(BillTax.Text,NumberStyles.Number,CultureInfo.CurrentCulture,out var tax)||tax<0)throw new ArgumentException("Tax is invalid.");
   if(!decimal.TryParse(BillDiscount.Text,NumberStyles.Number,CultureInfo.CurrentCulture,out var discount)||discount<0)throw new ArgumentException("Discount is invalid.");
   billItems.Add(new InvoiceItem{Description=BillItem.Text.Trim(),Quantity=qty,UnitPrice=price,TaxPercent=tax,Discount=discount});
   BillItemsList.Items.Add(BillItem.Text.Trim()+" | Qty "+qty.ToString("0.##")+" | Total "+billItems.Last().Total.ToString("0.00"));
   BillItem.Clear();BillQty.Text="1";BillPrice.Text="0";BillTax.Text="0";BillDiscount.Text="0";UpdateBillTotal();
  }catch(Exception ex){StatusText.Text=ex.Message;}
 }
 void UpdateBillTotal(){var total=billItems.Sum(x=>x.Total);BillTotalText.Text="Current items: "+billItems.Count+"    Total: "+total.ToString("0.00");}
 void BillCreate_Click(object s,RoutedEventArgs e){
  try{
   var status=(BillStatusBox.SelectedItem as ComboBoxItem)?.Content?.ToString()??"Pending";
   selectedInvoice=billing.Create(BillCustomer.Text,BillPhone.Text,BillAddress.Text,billItems,status);
   StatusText.Text="Created "+selectedInvoice.InvoiceNumber+" — total "+selectedInvoice.Total.ToString("0.00");
   billItems.Clear();BillItemsList.Items.Clear();UpdateBillTotal();BillRefresh_Click(null,null);
  }catch(Exception ex){MessageBox.Show(ex.Message,"Billing",MessageBoxButton.OK,MessageBoxImage.Error);}
 }
 void BillHistory_SelectionChanged(object s,SelectionChangedEventArgs e){selectedInvoice=BillHistoryList.SelectedItem as Invoice;if(selectedInvoice==null)return;BillCustomer.Text=selectedInvoice.CustomerName;BillPhone.Text=selectedInvoice.CustomerPhone;BillAddress.Text=selectedInvoice.CustomerAddress;for(var i=0;i<BillStatusBox.Items.Count;i++){var item=BillStatusBox.Items[i] as ComboBoxItem;if(item!=null&&string.Equals(item.Content?.ToString(),selectedInvoice.PaymentStatus,StringComparison.OrdinalIgnoreCase)){BillStatusBox.SelectedIndex=i;break;}}billItems.Clear();BillItemsList.Items.Clear();foreach(var item in selectedInvoice.Items){billItems.Add(item);BillItemsList.Items.Add(item.Description+" | Qty "+item.Quantity.ToString("0.##")+" | Total "+item.Total.ToString("0.00"));}UpdateBillTotal();}
 void BillUpdate_Click(object s,RoutedEventArgs e){if(selectedInvoice==null){StatusText.Text="Select an invoice first.";return;}try{selectedInvoice.CustomerName=BillCustomer.Text.Trim();selectedInvoice.CustomerPhone=BillPhone.Text.Trim();selectedInvoice.CustomerAddress=BillAddress.Text.Trim();selectedInvoice.PaymentStatus=(BillStatusBox.SelectedItem as ComboBoxItem)?.Content?.ToString()??"Pending";selectedInvoice.Items=new List<InvoiceItem>(billItems);billing.Update(selectedInvoice);BillRefresh_Click(null,null);StatusText.Text="Invoice "+selectedInvoice.InvoiceNumber+" updated.";}catch(Exception ex){MessageBox.Show(ex.Message,"Billing",MessageBoxButton.OK,MessageBoxImage.Error);}}
 void BillRefresh_Click(object s,RoutedEventArgs e){BillHistoryList.ItemsSource=billing.List();selectedInvoice=BillHistoryList.SelectedItem as Invoice;}
 void BillCsv_Click(object s,RoutedEventArgs e){var d=new SaveFileDialog{Filter="CSV file|*.csv",FileName="NagiCore-invoices.csv"};if(d.ShowDialog()!=true)return;try{billing.ExportCsv(d.FileName);StatusText.Text="Invoice CSV exported.";}catch(Exception ex){MessageBox.Show(ex.Message,"Billing",MessageBoxButton.OK,MessageBoxImage.Error);}}
 void BillDelete_Click(object s,RoutedEventArgs e){selectedInvoice=BillHistoryList.SelectedItem as Invoice;if(selectedInvoice==null){StatusText.Text="Select an invoice first.";return;}if(MessageBox.Show("Delete "+selectedInvoice.InvoiceNumber+"?","Billing",MessageBoxButton.YesNo,MessageBoxImage.Warning)!=MessageBoxResult.Yes)return;var id=selectedInvoice.Id;billing.Delete(id);selectedInvoice=null;billItems.Clear();BillItemsList.Items.Clear();BillRefresh_Click(null,null);StatusText.Text="Invoice deleted.";}
 void BillPdf_Click(object s,RoutedEventArgs e){selectedInvoice=BillHistoryList.SelectedItem as Invoice;if(selectedInvoice==null){StatusText.Text="Select an invoice first.";return;}var d=new SaveFileDialog{Filter="PDF document|*.pdf",FileName=selectedInvoice.InvoiceNumber+".pdf"};if(d.ShowDialog()!=true)return;try{billing.ExportPdf(selectedInvoice,d.FileName);StatusText.Text="Invoice PDF exported.";}catch(Exception ex){MessageBox.Show(ex.Message,"Billing",MessageBoxButton.OK,MessageBoxImage.Error);}}

 void DiaSave_Click(object s,RoutedEventArgs e){
  try{
   if(!decimal.TryParse(DiaWeight.Text,NumberStyles.Number,CultureInfo.CurrentCulture,out var weight))throw new ArgumentException("Weight is invalid.");
   if(!decimal.TryParse(DiaPrice.Text,NumberStyles.Number,CultureInfo.CurrentCulture,out var price))throw new ArgumentException("Price/value is invalid.");
   var r=selectedDiamond??new DiamondRecord();r.ReferenceNumber=DiaRef.Text;r.Weight=weight;r.Size=DiaSize.Text;r.Shape=DiaShape.Text;r.Color=DiaColor.Text;r.Clarity=DiaClarity.Text;r.Cut=DiaCut.Text;r.Price=price;diamond.Save(r);selectedDiamond=null;DiaRefresh_Click(null,null);StatusText.Text="Diamond record saved.";
  }catch(Exception ex){MessageBox.Show(ex.Message,"Diamond",MessageBoxButton.OK,MessageBoxImage.Error);}
 }
 void DiaRefresh_Click(object s,RoutedEventArgs e){DiaList.ItemsSource=diamond.Search(DiaSearch.Text);DiaList.SelectedItem=selectedDiamond;}
 void DiaDelete_Click(object s,RoutedEventArgs e){var r=DiaList.SelectedItem as DiamondRecord;if(r==null){StatusText.Text="Select a diamond record first.";return;}if(MessageBox.Show("Delete "+r.ReferenceNumber+"?","Diamond",MessageBoxButton.YesNo,MessageBoxImage.Warning)!=MessageBoxResult.Yes)return;diamond.Delete(r.Id);selectedDiamond=null;DiaRefresh_Click(null,null);StatusText.Text="Diamond record deleted.";}
 void DiaExport_Click(object s,RoutedEventArgs e){var d=new SaveFileDialog{Filter="CSV file|*.csv",FileName="NagiCore-diamonds.csv"};if(d.ShowDialog()!=true)return;try{diamond.ExportCsv(d.FileName);StatusText.Text="Diamond CSV exported.";}catch(Exception ex){MessageBox.Show(ex.Message,"Diamond",MessageBoxButton.OK,MessageBoxImage.Error);}}
 void DiaImport_Click(object s,RoutedEventArgs e){var d=new OpenFileDialog{Filter="CSV file|*.csv"};if(d.ShowDialog()!=true)return;try{var n=diamond.ImportCsv(d.FileName);DiaRefresh_Click(null,null);StatusText.Text="Imported "+n+" diamond records.";}catch(Exception ex){MessageBox.Show(ex.Message,"Diamond",MessageBoxButton.OK,MessageBoxImage.Error);}}
 
 void WindowsRefresh_Click(object s,RoutedEventArgs e){var r=windows.GetCompatibility();var si=windows.GetSystemInfo();StartupBox.IsChecked=windows.IsStartupEnabled();WindowsDetails.Text="Compatibility: "+r.Status+"\nWindows: "+si.OperatingSystem+"\nArchitecture: "+si.Architecture+"\nCPU: "+si.Cpu+"\nRAM: "+si.Memory+"\nStorage: "+si.Storage+"\nRuntime: "+si.Runtime+"\n"+r.Details;}
 void WindowsInfo_Click(object s,RoutedEventArgs e){var si=windows.GetSystemInfo();MessageBox.Show("OS: "+si.OperatingSystem+"\nCPU: "+si.Cpu+"\nRAM: "+si.Memory+"\nStorage: "+si.Storage+"\nRuntime: "+si.Runtime,"System information",MessageBoxButton.OK,MessageBoxImage.Information);}
 void Startup_Click(object s,RoutedEventArgs e){try{windows.SetStartup(StartupBox.IsChecked==true);StatusText.Text=StartupBox.IsChecked==true?"Startup enabled.":"Startup disabled.";}catch(Exception ex){MessageBox.Show(ex.Message,"Windows",MessageBoxButton.OK,MessageBoxImage.Error);}}

 async void DiscordConnect_Click(object s,RoutedEventArgs e){var token=DiscordTokenBox.Password.Trim();if(token.Length<20){DiscordStatus.Text="Enter a Discord bot token.";return;}DiscordConnectButton.IsEnabled=false;DiscordStatus.Text="Verifying token with Discord...";try{var identity=await discord.ConnectAsync(token);credentials.Save("discord-bot-token",token);DiscordIdentity.Text=identity.Username+" ("+identity.Id+")";DiscordStatus.Text="Connected and verified. Token is encrypted with Windows DPAPI.";AppLogger.Info("Discord bot connection verified.");}catch(Exception ex){DiscordStatus.Text=ex.Message;AppLogger.Warning("Discord connection failed: "+ex.Message);}finally{DiscordConnectButton.IsEnabled=true;}}
 void DiscordDisconnect_Click(object s,RoutedEventArgs e){credentials.Delete("discord-bot-token");DiscordTokenBox.Clear();DiscordIdentity.Text="Not connected";DiscordStatus.Text="Discord credentials removed.";}
 async void DiscordGuild_Click(object s,RoutedEventArgs e){await DiscordRequest(async token=>await discord.GetGuildAsync(token,DiscordGuildIdBox.Text));}
 async void DiscordUser_Click(object s,RoutedEventArgs e){await DiscordRequest(async token=>await discord.GetUserAsync(token,DiscordUserIdBox.Text));}
 async void DiscordGuilds_Click(object s,RoutedEventArgs e){await DiscordRequest(async token=>await discord.GetGuildsAsync(token));}
 async Task DiscordRequest(Func<string,Task<string>> action){var token=credentials.Load("discord-bot-token");if(string.IsNullOrEmpty(token)){DiscordStatus.Text="Connect a bot first.";return;}try{DiscordOutputBox.Text=await action(token);}catch(Exception ex){DiscordStatus.Text=ex.Message;AppLogger.Warning("Discord request failed: "+ex.Message);}}

 async void Activate_Click(object s,RoutedEventArgs e){var key=(KeyBox.Text??"").Trim();if(key.Length<10){StatusText.Text="Enter a valid license key.";return;}ActivateButton.IsEnabled=false;StatusText.Text="Verifying license...";var result=await license.VerifyAsync(key);ActivateButton.IsEnabled=true;if(!result.Valid){StatusText.Text="License rejected: "+result.Reason;return;}await store.SaveAsync(new LicenseInfo(key,LicenseService.GetDeviceId(),result.ExpiresAt,result.Product));LicenseDetails.Text="Active license until "+(result.ExpiresAt.HasValue?result.ExpiresAt.Value.ToLocalTime().ToString("dd MMM yyyy, HH:mm"):"unknown");StatusText.Text="License activated successfully.";}
 void SaveSettings_Click(object s,RoutedEventArgs e){currentSettings.DarkMode=DarkModeBox.IsChecked==true;currentSettings.Notifications=NotificationsBox.IsChecked==true;currentSettings.CheckUpdates=UpdatesBox.IsChecked==true;settings.Save(currentSettings);StatusText.Text="Settings saved.";}
 void ResetSettings_Click(object s,RoutedEventArgs e){if(MessageBox.Show("Reset all NagiCore settings?","NagiCore",MessageBoxButton.YesNo,MessageBoxImage.Question)!=MessageBoxResult.Yes)return;settings.Reset();currentSettings=new AppSettings();DarkModeBox.IsChecked=true;NotificationsBox.IsChecked=false;UpdatesBox.IsChecked=true;StatusText.Text="Settings reset.";}
 void ExportSettings_Click(object s,RoutedEventArgs e){var d=new SaveFileDialog{Filter="NagiCore settings|*.json",FileName="NagiCore-settings.json"};if(d.ShowDialog()!=true)return;try{settings.Save(currentSettings);settings.Export(d.FileName);StatusText.Text="Settings exported.";}catch(Exception ex){AppLogger.Error(ex.ToString());MessageBox.Show("Settings export failed.","NagiCore",MessageBoxButton.OK,MessageBoxImage.Error);}}
 void ImportSettings_Click(object s,RoutedEventArgs e){var d=new OpenFileDialog{Filter="NagiCore settings|*.json"};if(d.ShowDialog()!=true)return;try{settings.Import(d.FileName);currentSettings=settings.Load();DarkModeBox.IsChecked=currentSettings.DarkMode;NotificationsBox.IsChecked=currentSettings.Notifications;UpdatesBox.IsChecked=currentSettings.CheckUpdates;StatusText.Text="Settings imported.";}catch(Exception ex){AppLogger.Error(ex.ToString());MessageBox.Show("The selected settings file is invalid.","NagiCore",MessageBoxButton.OK,MessageBoxImage.Error);}}
 void RefreshLogs_Click(object s,RoutedEventArgs e){try{LogBox.Text=File.Exists(AppLogger.LogFile)?File.ReadAllText(AppLogger.LogFile):"No log entries yet.";}catch(Exception ex){LogBox.Text="Unable to read log.";AppLogger.Error(ex.ToString());}}
 void ExportLog_Click(object s,RoutedEventArgs e){var d=new SaveFileDialog{Filter="Text file|*.txt",FileName="NagiCore-log.txt"};if(d.ShowDialog()!=true)return;try{File.Copy(AppLogger.LogFile,d.FileName,true);StatusText.Text="Log exported.";}catch(Exception ex){AppLogger.Error(ex.ToString());MessageBox.Show("Log export failed.","NagiCore",MessageBoxButton.OK,MessageBoxImage.Error);}}
}