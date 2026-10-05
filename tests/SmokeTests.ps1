$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$release = Join-Path $root "bin\Release"
$exe = Join-Path $release "NagiCore.exe"
if (!(Test-Path $exe)) { throw "NagiCore.exe was not produced." }
$dlls = Get-ChildItem $release -Filter "*.dll" -File
foreach ($dll in $dlls) { try { [Reflection.Assembly]::LoadFrom($dll.FullName) | Out-Null } catch { } }
$nagiAssembly = [Reflection.Assembly]::LoadFrom($exe)

$barcodeType = $nagiAssembly.GetType("NagiCore.Modules.Barcode.BarcodeModule")
$barcode = $barcodeType.GetConstructor([Type[]]@()).Invoke($null)
$zxingAssembly = [Reflection.Assembly]::LoadFrom(($dlls | Where-Object { $_.Name -match "^zxing\\.dll$" } | Select-Object -First 1).FullName)
$formatType = $zxingAssembly.GetType("ZXing.BarcodeFormat")
$qr = [Enum]::Parse($formatType, "QR_CODE")
$image = $barcode.Generate("NagiCore-Smoke-Test", $qr, 320, 320)
$result = $barcode.Scan($image)
if ($result.Text -ne "NagiCore-Smoke-Test") { throw "Barcode round-trip failed." }
$tmp = Join-Path $env:TEMP ("NagiCoreSmoke-" + [Guid]::NewGuid().ToString("N") + ".png")
$pdf = [IO.Path]::ChangeExtension($tmp, ".pdf")
$barcode.SavePng($image, $tmp)
$barcode.SavePdf($image, $pdf, 37, 15)
if (!(Test-Path $tmp) -or !(Test-Path $pdf)) { throw "Barcode export failed." }
$image.Dispose()

$billType = $nagiAssembly.GetType("NagiCore.Modules.Billing.BillingModule")
$itemType = $nagiAssembly.GetType("NagiCore.Modules.Billing.InvoiceItem")
$billing = $billType.GetConstructor([Type[]]@()).Invoke($null)
$item = $itemType.GetConstructor([Type[]]@()).Invoke($null)
$item.Description = "Smoke item"; $item.Quantity = 2; $item.UnitPrice = 100; $item.TaxPercent = 18; $item.Discount = 10
$invoice = $billing.Create("Smoke Customer", "0000000000", "Test", @($item), "Paid")
if ($invoice.Total -ne 224.20) { throw "Billing calculation failed: $($invoice.Total)" }
if (($billing.List($invoice.InvoiceNumber)).Count -lt 1) { throw "Billing persistence failed." }
$billing.Delete($invoice.Id)

$diaType = $nagiAssembly.GetType("NagiCore.Modules.Diamond.DiamondModule")
$recordType = $nagiAssembly.GetType("NagiCore.Modules.Diamond.DiamondRecord")
$diamond = $diaType.GetConstructor([Type[]]@()).Invoke($null)
$record = $recordType.GetConstructor([Type[]]@()).Invoke($null)
$record.ReferenceNumber = "SMOKE-" + [Guid]::NewGuid().ToString("N")
$record.Weight = 1.0; $record.Price = 0
$diamond.Save($record)
if (($diamond.Search($record.ReferenceNumber)).Count -ne 1) { throw "Diamond persistence failed." }
$diamond.Delete($record.Id)

$winType = $nagiAssembly.GetType("NagiCore.Modules.Windows.WindowsUtilitiesModule")
$win = $winType.GetConstructor([Type[]]@()).Invoke($null)
$compat = $win.GetCompatibility()
if ([string]::IsNullOrWhiteSpace($compat.Status)) { throw "Windows compatibility check failed." }

Remove-Item $tmp,$pdf -Force -ErrorAction SilentlyContinue
Write-Host "NagiCore smoke tests passed."
