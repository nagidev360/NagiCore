using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using NagiCore.Services;
namespace NagiCore.Modules.Diamond;
public sealed class DiamondRecord { public string Id{get;set;}=Guid.NewGuid().ToString("N"); public string ReferenceNumber{get;set;}=""; public decimal Weight{get;set;} public string Size{get;set;}=""; public string Shape{get;set;}=""; public string Color{get;set;}=""; public string Clarity{get;set;}=""; public string Cut{get;set;}=""; public decimal Price{get;set;} public DateTime UpdatedAt{get;set;}=DateTime.Now; }
public sealed class DiamondDatabase { public List<DiamondRecord> Records{get;set;}=new List<DiamondRecord>(); }
public sealed class DiamondModule {
 readonly JsonDataStore<DiamondDatabase> store=new JsonDataStore<DiamondDatabase>("diamonds.json");
 public string Name=>"Diamond"; public string Description=>"Diamond inventory attributes, search, history and neutral reporting.";
 public List<DiamondRecord> Search(string q=null){var l=store.Load().Records;if(string.IsNullOrWhiteSpace(q))return l.OrderByDescending(x=>x.UpdatedAt).ToList();q=q.Trim();return l.Where(x=>x.ReferenceNumber.IndexOf(q,StringComparison.OrdinalIgnoreCase)>=0||x.Shape.IndexOf(q,StringComparison.OrdinalIgnoreCase)>=0||x.Color.IndexOf(q,StringComparison.OrdinalIgnoreCase)>=0||x.Clarity.IndexOf(q,StringComparison.OrdinalIgnoreCase)>=0).OrderByDescending(x=>x.UpdatedAt).ToList();}
 public void Save(DiamondRecord r){if(r==null)throw new ArgumentNullException(nameof(r));if(string.IsNullOrWhiteSpace(r.ReferenceNumber))throw new ArgumentException("Reference number is required.");if(r.Weight<=0)throw new ArgumentException("Weight must be greater than zero.");if(r.Price<0)throw new ArgumentException("Price cannot be negative.");r.ReferenceNumber=r.ReferenceNumber.Trim();r.UpdatedAt=DateTime.Now;var d=store.Load();var old=d.Records.FirstOrDefault(x=>x.Id==r.Id);if(old==null)d.Records.Add(r);else d.Records[d.Records.IndexOf(old)]=r;store.Save(d);}
 public void Delete(string id){var d=store.Load();d.Records.RemoveAll(x=>x.Id==id);store.Save(d);}
 public void ExportCsv(string path){using(var w=new StreamWriter(path,false,new UTF8Encoding(true))){w.WriteLine("Reference,Weight,Size,Shape,Color,Clarity,Cut,Price,UpdatedAt");foreach(var x in Search())w.WriteLine(string.Join(",",Csv(x.ReferenceNumber),x.Weight.ToString("0.###"),Csv(x.Size),Csv(x.Shape),Csv(x.Color),Csv(x.Clarity),Csv(x.Cut),x.Price.ToString("0.00"),x.UpdatedAt.ToString("s")));}}
 public int ImportCsv(string path){var lines=File.ReadAllLines(path);if(lines.Length<=1)return 0;var d=store.Load();var n=0;for(var i=1;i<lines.Length;i++){var p=lines[i].Split(',');if(p.Length<9)continue;if(!decimal.TryParse(p[1],out var weight)||!decimal.TryParse(p[7],out var price))continue;var rf=Clean(p[0]);if(string.IsNullOrWhiteSpace(rf))continue;d.Records.Add(new DiamondRecord{ReferenceNumber=rf,Weight=weight,Size=Clean(p[2]),Shape=Clean(p[3]),Color=Clean(p[4]),Clarity=Clean(p[5]),Cut=Clean(p[6]),Price=price});n++;}store.Save(d);return n;}
 static string Clean(string s)=>(s??"").Trim().Trim('"'); static string Csv(string s){var q=((char)34).ToString();return q+(s??"").Replace(q,q+q)+q;}
}