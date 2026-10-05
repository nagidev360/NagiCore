using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using PdfSharp.Drawing;
using PdfSharp.Pdf;
using ZXing;
using ZXing.Common;
namespace NagiCore.Modules.Barcode;
public sealed class BarcodeResult{public string Format{get;set;}="";public string Text{get;set;}="";}
public sealed class BarcodeModule{
 public string Name=>"Barcode"; public string Description=>"Generate, scan, validate, preview and export barcodes and QR codes.";
 public Bitmap Generate(string text,ZXing.BarcodeFormat format,int width,int height){if(string.IsNullOrWhiteSpace(text))throw new ArgumentException("Barcode text is required.");if(width<80||width>2400||height<40||height>2400)throw new ArgumentOutOfRangeException("Barcode dimensions are outside the safe range.");var w=new BarcodeWriter{Format=format,Options=new EncodingOptions{Width=width,Height=height,Margin=2, PureBarcode=false}};return w.Write(text.Trim());}
 public BarcodeResult Scan(Bitmap image){if(image==null)throw new ArgumentNullException(nameof(image));var r=new BarcodeReader().Decode(image);if(r==null)throw new InvalidDataException("No valid barcode or QR code was detected.");return new BarcodeResult{Format=r.BarcodeFormat.ToString(),Text=r.Text};}
 public void SavePng(Bitmap image,string path){Validate(path);image.Save(path,ImageFormat.Png);}
 public void SavePdf(Bitmap image,string path,double widthMm,double heightMm){Validate(path);using(var ms=new MemoryStream()){image.Save(ms,ImageFormat.Png);ms.Position=0;using(var doc=new PdfDocument()){var page=doc.AddPage();page.Width=XUnit.FromMillimeter(widthMm);page.Height=XUnit.FromMillimeter(heightMm);using(var g=XGraphics.FromPdfPage(page))using(var xi=XImage.FromStream(ms))g.DrawImage(xi,0,0,page.Width,page.Height);doc.Save(path);}}}
 static void Validate(string path){if(string.IsNullOrWhiteSpace(path))throw new ArgumentException("Destination is required.");var full=Path.GetFullPath(path);var dir=Path.GetDirectoryName(full);if(string.IsNullOrEmpty(dir))throw new IOException("Invalid destination.");Directory.CreateDirectory(dir);}
}