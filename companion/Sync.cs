using System;
using System.Collections;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Net;
using System.Reflection;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Web.Script.Serialization;

namespace LifeOnAzeroth
{
    public class SyncResult
    {
        public bool Changed;
        public long Built;
        public long Latest;
        public int Snapshots;
        public int Items;
    }

    public static class Sync
    {
        public static readonly string Api = Environment.GetEnvironmentVariable("LOA_API") ?? "https://forever-live.sanredz.workers.dev/v1";
        public const string AddonName = "LifeOnAzeroth_Market";
        public const string DataName = "LifeOnAzeroth_Data";
        static readonly string[] LegacyFiles = { "LifeOnAzeroth.toc", "Core.lua", "Chart.lua", "Item.lua", "UI.lua", "Data.lua" };
        public static readonly string[] Regions = { "us", "eu", "kr", "tw" };
        static readonly CultureInfo Inv = CultureInfo.InvariantCulture;

        static string Get(string path)
        {
            Exception last = null;
            for (int attempt = 0; attempt < 3; attempt++)
            {
                try
                {
                    var req = (HttpWebRequest)WebRequest.Create(Api + path);
                    req.UserAgent = "LifeOnAzerothCompanion/" + Program.Version;
                    req.AutomaticDecompression = DecompressionMethods.GZip | DecompressionMethods.Deflate;
                    req.Timeout = 30000;
                    req.ReadWriteTimeout = 60000;
                    using (var res = (HttpWebResponse)req.GetResponse())
                    using (var sr = new StreamReader(res.GetResponseStream(), Encoding.UTF8))
                        return sr.ReadToEnd();
                }
                catch (Exception e)
                {
                    last = e;
                    Thread.Sleep(1500 * (attempt + 1));
                }
            }
            throw last;
        }

        static object Json(string s)
        {
            var js = new JavaScriptSerializer();
            js.MaxJsonLength = int.MaxValue;
            js.RecursionLimit = 256;
            return js.DeserializeObject(s);
        }

        static Dictionary<string, object> Obj(object o) { return o as Dictionary<string, object> ?? new Dictionary<string, object>(); }
        static object[] Arr(object o) { return o as object[] ?? new object[0]; }
        static object Field(Dictionary<string, object> d, string k) { object v; return d.TryGetValue(k, out v) ? v : null; }
        static double Num(object o) { return o == null ? 0 : Convert.ToDouble(o, Inv); }
        static long Lng(object o) { return o == null ? 0 : (long)Math.Round(Convert.ToDouble(o, Inv)); }

        static string LuaStr(string s)
        {
            var sb = new StringBuilder(s.Length + 8);
            sb.Append('"');
            foreach (char c in s)
            {
                if (c == '\\') sb.Append("\\\\");
                else if (c == '"') sb.Append("\\\"");
                else if (c == '\n') sb.Append("\\n");
                else if (c == '\r') sb.Append("\\r");
                else if (c == '\0') sb.Append("\\0");
                else sb.Append(c);
            }
            sb.Append('"');
            return sb.ToString();
        }

        static string B36(long v)
        {
            if (v <= 0) return "";
            const string digits = "0123456789abcdefghijklmnopqrstuvwxyz";
            var sb = new StringBuilder();
            while (v > 0) { sb.Insert(0, digits[(int)(v % 36)]); v /= 36; }
            return sb.ToString();
        }

        static string Dec(double v)
        {
            return Math.Round(v, 2).ToString("0.##", Inv);
        }

        static readonly string[] SetNames = { "PvP", "Normal", "Roleplay", "Roleplay PvP" };
        static readonly string[] SetSlugs = { "pvp", "normal", "roleplay", "roleplay-pvp" };

        static long[][] Align(object[] arrs, long[] st, Dictionary<long, int> pos, int K)
        {
            if (arrs.Length < 3) return null;
            var med = Arr(arrs[0]); var mn = Arr(arrs[1]); var q = Arr(arrs[2]);
            var outA = new long[3][] { new long[K], new long[K], new long[K] };
            bool any = false;
            for (int j = 0; j < st.Length && j < med.Length; j++)
            {
                int p;
                if (!pos.TryGetValue(st[j], out p)) continue;
                outA[0][p] = Lng(med[j]);
                outA[1][p] = j < mn.Length ? Lng(mn[j]) : 0;
                outA[2][p] = j < q.Length ? Lng(q[j]) : 0;
                if (outA[0][p] > 0) any = true;
            }
            return any ? outA : null;
        }

        static void WriteState(StringBuilder sb, Dictionary<string, object> state)
        {
            sb.Append("t = {").Append(string.Join(",", Arr(Field(state, "t")).Select(x => Lng(x).ToString(Inv)))).Append("},\n");
            sb.Append("idx = {\n");
            foreach (var kv in Obj(Field(state, "idx")))
            {
                var vals = Arr(kv.Value).Select(x => x == null ? "" : Dec(Num(x)));
                sb.Append("[").Append(LuaStr(kv.Key)).Append("] = ").Append(LuaStr(string.Join(",", vals))).Append(",\n");
            }
            sb.Append("},\ncounts = {\n");
            foreach (var kv in Obj(Field(state, "counts")))
                sb.Append("[").Append(LuaStr(kv.Key)).Append("] = ").Append(Lng(kv.Value)).Append(",\n");
            sb.Append("},\n");
        }

        static string LatestLines(Dictionary<string, object> lat)
        {
            var lines = new StringBuilder();
            foreach (var kv in lat)
            {
                var l = Arr(kv.Value);
                if (l.Length < 4) continue;
                lines.Append(kv.Key).Append(',').Append(Lng(l[0])).Append(',').Append(Lng(l[1])).Append(',').Append(Lng(l[2])).Append(',').Append(Lng(l[3])).Append(',');
                if (l.Length > 4 && l[4] != null) lines.Append(Dec(Num(l[4])));
                lines.Append('\n');
            }
            return lines.ToString();
        }

        static void WriteHist(StringBuilder sb, SortedDictionary<long, long[][]> hist)
        {
            sb.Append("hist = {\n");
            foreach (var kv in hist)
            {
                sb.Append("[").Append(kv.Key).Append("] = \"");
                for (int s = 0; s < 3; s++)
                {
                    if (s > 0) sb.Append(';');
                    var a = kv.Value[s];
                    for (int i = 0; i < a.Length; i++) { if (i > 0) sb.Append(','); sb.Append(B36(a[i])); }
                }
                sb.Append("\",\n");
            }
            sb.Append("},\n");
        }

        const int Format = 2;

        static int DataFormat(string file)
        {
            try
            {
                using (var r = new StreamReader(file))
                {
                    var buf = new char[64];
                    int n = r.Read(buf, 0, 64);
                    var m = System.Text.RegularExpressions.Regex.Match(new string(buf, 0, n), @"v = (\d+)");
                    return m.Success ? int.Parse(m.Groups[1].Value) : 0;
                }
            }
            catch { return 0; }
        }

        public static string AddonDir(string forever)
        {
            return Path.Combine(forever, "Interface", "AddOns", AddonName);
        }

        public static string DataDir(string forever)
        {
            return Path.Combine(forever, "Interface", "AddOns", DataName);
        }

        static string TocVersion(string text)
        {
            foreach (string line in text.Split('\n'))
                if (line.StartsWith("## Version:")) return line.Substring(11).Trim();
            return null;
        }

        static string TocInterface(string text)
        {
            foreach (string line in text.Split('\n'))
                if (line.StartsWith("## Interface:")) return line.Trim();
            return "## Interface: 11509";
        }

        static bool Newer(string a, string b)
        {
            Version va, vb;
            if (!Version.TryParse(a ?? "", out va)) return false;
            if (!Version.TryParse(b ?? "", out vb)) return true;
            return va > vb;
        }

        static byte[] Resource(string name)
        {
            using (var s = Assembly.GetExecutingAssembly().GetManifestResourceStream(name))
            {
                if (s == null) return null;
                using (var ms = new MemoryStream()) { s.CopyTo(ms); return ms.ToArray(); }
            }
        }

        public static long PeekLatest(string region)
        {
            var m = Obj(Json(Get("/market/" + region)));
            var t = Arr(Field(Obj(Field(m, "state")), "t"));
            return t.Length > 0 ? Lng(t[t.Length - 1]) : 0;
        }

        public static bool InstallAddon(string forever)
        {
            string dir = AddonDir(forever);
            bool fresh = !Directory.Exists(dir) || !Directory.Exists(DataDir(forever));
            RemoveLegacy(forever);
            var toc = Resource("addon/" + AddonName + ".toc");
            string tocText = toc == null ? "" : Encoding.UTF8.GetString(toc);
            if (toc != null)
            {
                string have = InstalledVersion(forever);
                if (have == null || Newer(TocVersion(tocText), have))
                {
                    Directory.CreateDirectory(dir);
                    foreach (string name in Assembly.GetExecutingAssembly().GetManifestResourceNames())
                    {
                        if (!name.StartsWith("addon/")) continue;
                        string dest = Path.Combine(dir, name.Substring(6));
                        var data = Resource(name);
                        if (File.Exists(dest) && File.ReadAllBytes(dest).SequenceEqual(data)) continue;
                        File.WriteAllBytes(dest, data);
                    }
                }
            }
            string ddir = DataDir(forever);
            Directory.CreateDirectory(ddir);
            string dtoc = TocInterface(tocText) + "\n## Title: Life on Azeroth: |cffffe08aData|r\n## Notes: Auction house prices for the Life on Azeroth Market, kept up to date by the companion app.\n## Author: sanredz\n## Version: " + Program.Version + "\n\nData.lua\n";
            string dtocPath = Path.Combine(ddir, DataName + ".toc");
            if (!File.Exists(dtocPath) || File.ReadAllText(dtocPath) != dtoc) File.WriteAllText(dtocPath, dtoc, new UTF8Encoding(false));
            return fresh;
        }

        static void RemoveLegacy(string forever)
        {
            string old = Path.Combine(forever, "Interface", "AddOns", "LifeOnAzeroth");
            string toc = Path.Combine(old, "LifeOnAzeroth.toc");
            if (!File.Exists(toc)) return;
            string text = File.ReadAllText(toc);
            if (!text.Contains("## Author: sanredz") || !text.Contains("Life on Azeroth")) return;
            foreach (string f in LegacyFiles)
            {
                string p = Path.Combine(old, f);
                if (File.Exists(p)) File.Delete(p);
            }
            if (Directory.GetFileSystemEntries(old).Length == 0) Directory.Delete(old);
        }

        public static string InstalledVersion(string forever)
        {
            string toc = Path.Combine(AddonDir(forever), AddonName + ".toc");
            if (!File.Exists(toc)) return null;
            foreach (string line in File.ReadAllLines(toc))
                if (line.StartsWith("## Version:")) return line.Substring(11).Trim();
            return "?";
        }

        public static SyncResult Run(string forever, string region, long lastLatest, Action<string, double> progress)
        {
            progress("Checking for new prices", 0.02);
            var markets = new Dictionary<string, Dictionary<string, object>>();
            var own = Obj(Json(Get("/market/" + region)));
            markets[region] = own;
            var state = Obj(Field(own, "state"));
            var T = Arr(Field(state, "t")).Select(Lng).ToArray();
            if (T.Length == 0) throw new Exception("No market data for this region yet.");
            long latest = T[T.Length - 1];
            string dataFile = Path.Combine(DataDir(forever), "Data.lua");
            if (latest == lastLatest && File.Exists(dataFile) && new FileInfo(dataFile).Length > 1000 && DataFormat(dataFile) == Format)
                return new SyncResult { Changed = false, Latest = latest, Snapshots = T.Length };

            progress("Downloading the item catalog", 0.06);
            var cat = Obj(Json(Get("/catalog")));
            int done = 0;
            foreach (string r in Regions)
            {
                if (r == region) continue;
                progress("Downloading prices in other regions", 0.1 + 0.03 * done++);
                try { markets[r] = Obj(Json(Get("/market/" + r))); } catch { }
            }
            var sets = new Dictionary<string, Dictionary<string, object>>();
            for (int si = 0; si < SetNames.Length; si++)
            {
                progress("Downloading ruleset prices", 0.19 + 0.01 * si);
                try { sets[SetNames[si]] = Obj(Json(Get("/market/" + region + "/rs/" + SetSlugs[si]))); } catch { }
            }

            var keep = new List<int>();
            long tmax = T[T.Length - 1];
            long lastBucket = long.MinValue;
            for (int i = 0; i < T.Length; i++)
            {
                long t = T[i];
                if (t >= tmax - 72 * 3600) { keep.Add(i); continue; }
                long bucket = t >= tmax - 14 * 86400 ? t / 21600 : -(t / 86400) - 1;
                if (bucket != lastBucket) { keep.Add(i); lastBucket = bucket; }
            }
            var pos = new Dictionary<long, int>();
            for (int k = 0; k < keep.Count; k++) pos[T[keep[k]]] = k;
            int K = keep.Count;

            var hist = new SortedDictionary<long, long[][]>();
            var histRs = new Dictionary<string, SortedDictionary<long, long[][]>>();
            foreach (string sn in SetNames) histRs[sn] = new SortedDictionary<long, long[][]>();
            int shardsDone = 0;
            var lockObj = new object();
            Exception shardErr = null;
            Parallel.For(0, 64, new ParallelOptions { MaxDegreeOfParallelism = 6 }, sh =>
            {
                try
                {
                    var d = Obj(Json(Get("/shard/" + region + "/" + sh)));
                    var st = Arr(Field(d, "t")).Select(Lng).ToArray();
                    var items = Obj(Field(d, "i"));
                    var local = new Dictionary<long, long[][]>();
                    var localRs = new List<KeyValuePair<string, KeyValuePair<long, long[][]>>>();
                    foreach (var kv in items)
                    {
                        var arrs = Arr(kv.Value);
                        if (arrs.Length < 3) continue;
                        long id = long.Parse(kv.Key, Inv);
                        var outA = Align(arrs, st, pos, K);
                        if (outA != null) local[id] = outA;
                        if (arrs.Length > 3)
                            foreach (var rkv in Obj(arrs[3]))
                            {
                                int si;
                                if (!int.TryParse(rkv.Key, out si) || si < 0 || si >= SetNames.Length) continue;
                                var ra = Align(Arr(rkv.Value), st, pos, K);
                                if (ra != null) localRs.Add(new KeyValuePair<string, KeyValuePair<long, long[][]>>(SetNames[si], new KeyValuePair<long, long[][]>(id, ra)));
                            }
                    }
                    lock (lockObj)
                    {
                        foreach (var kv in local) hist[kv.Key] = kv.Value;
                        foreach (var kv in localRs) histRs[kv.Key][kv.Value.Key] = kv.Value.Value;
                        shardsDone++;
                        progress("Downloading price history", 0.22 + 0.7 * shardsDone / 64.0);
                    }
                }
                catch (Exception e) { lock (lockObj) shardErr = e; }
            });
            if (shardErr != null) throw shardErr;

            progress("Writing the addon data", 0.95);
            var sb = new StringBuilder(4 << 20);
            long built = (long)(DateTime.UtcNow - new DateTime(1970, 1, 1)).TotalSeconds;
            sb.Append("LOA_DATA = {\nv = ").Append(Format).Append(",\nbuilt = ").Append(built).Append(",\nlatest = ").Append(latest).Append(",\nregion = ").Append(LuaStr(region)).Append(",\n");
            sb.Append("defs = {\n");
            foreach (var o in Arr(Field(own, "defs")))
            {
                var d = Obj(o);
                sb.Append("{").Append(LuaStr(Convert.ToString(Field(d, "k")))).Append(",").Append(LuaStr(Convert.ToString(Field(d, "n"))))
                  .Append(",").Append(LuaStr(Convert.ToString(Field(d, "g")))).Append(",").Append(LuaStr(Convert.ToString(Field(d, "ic"))))
                  .Append(",").Append(LuaStr(Convert.ToString(Field(d, "d")) ?? "")).Append("},\n");
            }
            sb.Append("},\n");
            WriteState(sb, state);
            sb.Append("ht = {").Append(string.Join(",", keep.Select(i => T[i].ToString(Inv)))).Append("},\n");

            var catLines = new StringBuilder();
            int itemCount = 0;
            foreach (var kv in cat)
            {
                var c = Arr(kv.Value);
                if (c.Length < 8) continue;
                string name = Convert.ToString(c[0]).Replace("\t", " ").Replace("\n", " ");
                catLines.Append(kv.Key).Append('\t').Append(name);
                for (int i = 1; i < 8; i++) catLines.Append('\t').Append(Lng(c[i]));
                catLines.Append('\n');
                itemCount++;
            }
            sb.Append("catS = ").Append(LuaStr(catLines.ToString())).Append(",\n");
            sb.Append("latS = {\n");
            foreach (var mk in markets)
                sb.Append(mk.Key).Append(" = ").Append(LuaStr(LatestLines(Obj(Field(mk.Value, "latest"))))).Append(",\n");
            sb.Append("},\n");
            WriteHist(sb, hist);
            sb.Append("rs = {\n");
            foreach (string sn in SetNames)
            {
                Dictionary<string, object> sm;
                if (!sets.TryGetValue(sn, out sm)) continue;
                var sst = Obj(Field(sm, "state"));
                if (Arr(Field(sst, "t")).Length == 0) continue;
                sb.Append("[").Append(LuaStr(sn)).Append("] = {\n");
                WriteState(sb, sst);
                sb.Append("latS = ").Append(LuaStr(LatestLines(Obj(Field(sm, "latest"))))).Append(",\n");
                WriteHist(sb, histRs[sn]);
                sb.Append("},\n");
            }
            sb.Append("},\n}\n");

            Directory.CreateDirectory(DataDir(forever));
            string tmp = dataFile + ".tmp";
            File.WriteAllText(tmp, sb.ToString(), new UTF8Encoding(false));
            if (File.Exists(dataFile)) File.Replace(tmp, dataFile, null); else File.Move(tmp, dataFile);
            progress("Done", 1);
            return new SyncResult { Changed = true, Built = built, Latest = latest, Snapshots = T.Length, Items = itemCount };
        }
    }
}
