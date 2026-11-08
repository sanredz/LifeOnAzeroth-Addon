using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Text;
using System.IO;
using System.Linq;
using System.Net;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Threading;
using System.Threading.Tasks;
using System.Windows.Forms;
using Microsoft.Win32;

[assembly: AssemblyTitle("Life on Azeroth Companion")]
[assembly: AssemblyDescription("Keeps the Life on Azeroth Market addon up to date with auction house prices.")]
[assembly: AssemblyCompany("Life on Azeroth")]
[assembly: AssemblyProduct("Life on Azeroth Companion")]
[assembly: AssemblyCopyright("© 2026 Life on Azeroth")]
[assembly: AssemblyVersion("1.0.0.0")]
[assembly: AssemblyFileVersion("1.0.0.0")]
[assembly: AssemblyInformationalVersion("1.0.0")]

namespace LifeOnAzeroth
{
    static class Program
    {
        public const string Version = "1.0.0";
        public static int ShowMsg;

        [DllImport("user32.dll")] static extern int RegisterWindowMessage(string msg);
        [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr hwnd, int msg, IntPtr w, IntPtr l);

        [STAThread]
        static void Main(string[] args)
        {
            ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12;
            ShowMsg = RegisterWindowMessage("LifeOnAzerothCompanion.Show");
            bool fresh;
            using (var mutex = new Mutex(true, "LifeOnAzerothCompanion", out fresh))
            {
                if (!fresh)
                {
                    if (!args.Contains("--tray")) PostMessage((IntPtr)0xffff, ShowMsg, IntPtr.Zero, IntPtr.Zero);
                    return;
                }
                Application.EnableVisualStyles();
                Application.SetCompatibleTextRenderingDefault(false);
                Application.Run(new MainForm(args.Contains("--tray")));
            }
        }
    }

    static class Theme
    {
        public static readonly Color Bg = Color.FromArgb(18, 14, 9);
        public static readonly Color Card = Color.FromArgb(28, 22, 14);
        public static readonly Color CardHi = Color.FromArgb(36, 28, 17);
        public static readonly Color Line = Color.FromArgb(58, 45, 22);
        public static readonly Color Gold = Color.FromArgb(248, 211, 107);
        public static readonly Color GoldDim = Color.FromArgb(201, 154, 59);
        public static readonly Color Title = Color.FromArgb(255, 224, 138);
        public static readonly Color Ink = Color.FromArgb(243, 231, 207);
        public static readonly Color Ink2 = Color.FromArgb(201, 185, 154);
        public static readonly Color Muted = Color.FromArgb(143, 129, 112);
        public static readonly Color Up = Color.FromArgb(125, 220, 138);
        public static readonly Color Down = Color.FromArgb(239, 125, 109);
        public static readonly Color Busy = Color.FromArgb(120, 180, 255);

        public static GraphicsPath Round(RectangleF r, float rad)
        {
            var p = new GraphicsPath();
            float d = rad * 2;
            p.AddArc(r.X, r.Y, d, d, 180, 90);
            p.AddArc(r.Right - d, r.Y, d, d, 270, 90);
            p.AddArc(r.Right - d, r.Bottom - d, d, d, 0, 90);
            p.AddArc(r.X, r.Bottom - d, d, d, 90, 90);
            p.CloseFigure();
            return p;
        }

        public static void Smooth(Graphics g)
        {
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.TextRenderingHint = TextRenderingHint.ClearTypeGridFit;
            g.PixelOffsetMode = PixelOffsetMode.HighQuality;
        }
    }

    class FlatButton : Control
    {
        public bool Primary;
        bool hover, down;

        public FlatButton(string text, bool primary)
        {
            Text = text;
            Primary = primary;
            Cursor = Cursors.Hand;
            SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.UserPaint | ControlStyles.ResizeRedraw | ControlStyles.SupportsTransparentBackColor, true);
            BackColor = Color.Transparent;
            Font = new Font("Segoe UI Semibold", 9.75f);
        }

        protected override void OnMouseEnter(EventArgs e) { hover = true; Invalidate(); base.OnMouseEnter(e); }
        protected override void OnMouseLeave(EventArgs e) { hover = false; down = false; Invalidate(); base.OnMouseLeave(e); }
        protected override void OnMouseDown(MouseEventArgs e) { down = true; Invalidate(); base.OnMouseDown(e); }
        protected override void OnMouseUp(MouseEventArgs e) { down = false; Invalidate(); base.OnMouseUp(e); }
        protected override void OnEnabledChanged(EventArgs e) { Invalidate(); base.OnEnabledChanged(e); }

        protected override void OnPaint(PaintEventArgs e)
        {
            var g = e.Graphics;
            Theme.Smooth(g);
            var r = new RectangleF(0.5f, 0.5f, Width - 1.5f, Height - 1.5f);
            using (var path = Theme.Round(r, Height / 2f - 1))
            {
                Color fill, border, text;
                if (Primary)
                {
                    fill = !Enabled ? Color.FromArgb(70, 58, 34) : down ? Color.FromArgb(214, 170, 74) : hover ? Color.FromArgb(255, 226, 140) : Theme.Gold;
                    border = !Enabled ? Color.FromArgb(90, 74, 40) : Color.FromArgb(255, 236, 170);
                    text = !Enabled ? Theme.Muted : Color.FromArgb(32, 22, 6);
                    using (var lg = new LinearGradientBrush(new RectangleF(0, 0, Width, Height), Color.FromArgb(Math.Min(255, fill.R + 6), Math.Min(255, fill.G + 14), Math.Min(255, fill.B + 30)), Color.FromArgb(fill.R, Math.Max(0, fill.G - 30), Math.Max(0, fill.B - 40)), 90f))
                        g.FillPath(lg, path);
                }
                else
                {
                    fill = hover ? Color.FromArgb(44, 35, 20) : Color.FromArgb(30, 24, 15);
                    border = hover ? Theme.GoldDim : Theme.Line;
                    text = Enabled ? (hover ? Theme.Gold : Theme.Ink) : Theme.Muted;
                    using (var b = new SolidBrush(fill)) g.FillPath(b, path);
                }
                using (var p = new Pen(border, 1f)) g.DrawPath(p, path);
                TextRenderer.DrawText(g, Text, Font, new Rectangle(0, 0, Width, Height), text, TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter | TextFormatFlags.NoPadding);
            }
        }
    }

    class Toggle : Control
    {
        bool on, hover;
        public event EventHandler Changed;
        public bool On { get { return on; } set { on = value; Invalidate(); } }

        public Toggle(string text)
        {
            Text = text;
            Cursor = Cursors.Hand;
            SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.UserPaint | ControlStyles.ResizeRedraw | ControlStyles.SupportsTransparentBackColor, true);
            BackColor = Color.Transparent;
            Font = new Font("Segoe UI", 9.5f);
        }

        public int Fit(int height)
        {
            float h = height * 0.62f, w = h * 1.75f;
            return (int)Math.Ceiling(w + 12 + TextRenderer.MeasureText(Text, Font, Size.Empty, TextFormatFlags.NoPadding).Width + 6);
        }
        protected override void OnMouseEnter(EventArgs e) { hover = true; Invalidate(); base.OnMouseEnter(e); }
        protected override void OnMouseLeave(EventArgs e) { hover = false; Invalidate(); base.OnMouseLeave(e); }
        protected override void OnClick(EventArgs e) { On = !on; if (Changed != null) Changed(this, e); base.OnClick(e); }

        protected override void OnPaint(PaintEventArgs e)
        {
            var g = e.Graphics;
            Theme.Smooth(g);
            float h = Height * 0.62f, w = h * 1.75f, y = (Height - h) / 2f;
            var track = new RectangleF(1.5f, y, w, h);
            using (var path = Theme.Round(track, h / 2f))
            {
                using (var b = new SolidBrush(on ? Color.FromArgb(150, 116, 42) : Color.FromArgb(40, 32, 20))) g.FillPath(b, path);
                using (var p = new Pen(on ? Theme.Gold : (hover ? Theme.GoldDim : Theme.Line))) g.DrawPath(p, path);
            }
            float k = h - 6;
            float kx = on ? track.Right - k - 3 : track.X + 3;
            using (var b = new SolidBrush(on ? Theme.Title : Theme.Muted)) g.FillEllipse(b, kx, y + 3, k, k);
            TextRenderer.DrawText(g, Text, Font, new Rectangle((int)(w + 12), 0, Width - (int)(w + 12), Height), hover ? Theme.Ink : Theme.Ink2, TextFormatFlags.VerticalCenter | TextFormatFlags.Left | TextFormatFlags.NoPadding | TextFormatFlags.SingleLine);
        }
    }

    class Segmented : Control
    {
        public string[] Keys, Labels;
        public string Value;
        int hover = -1;
        public event EventHandler Changed;

        public Segmented(string[] keys, string[] labels)
        {
            Keys = keys;
            Labels = labels;
            Value = keys[0];
            Cursor = Cursors.Hand;
            SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.UserPaint | ControlStyles.ResizeRedraw | ControlStyles.SupportsTransparentBackColor, true);
            BackColor = Color.Transparent;
            Font = new Font("Segoe UI", 9f);
        }

        int At(int x) { int i = (int)((x - 3) / ((Width - 6) / (float)Keys.Length)); return Math.Max(0, Math.Min(Keys.Length - 1, i)); }
        protected override void OnMouseMove(MouseEventArgs e) { int h = At(e.X); if (h != hover) { hover = h; Invalidate(); } base.OnMouseMove(e); }
        protected override void OnMouseLeave(EventArgs e) { hover = -1; Invalidate(); base.OnMouseLeave(e); }
        protected override void OnMouseClick(MouseEventArgs e)
        {
            string v = Keys[At(e.X)];
            if (v != Value) { Value = v; Invalidate(); if (Changed != null) Changed(this, e); }
            base.OnMouseClick(e);
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            var g = e.Graphics;
            Theme.Smooth(g);
            var r = new RectangleF(0.5f, 0.5f, Width - 1.5f, Height - 1.5f);
            using (var path = Theme.Round(r, 8))
            {
                using (var b = new SolidBrush(Color.FromArgb(14, 11, 7))) g.FillPath(b, path);
                using (var p = new Pen(Theme.Line)) g.DrawPath(p, path);
            }
            float sw = (Width - 6) / (float)Keys.Length;
            for (int i = 0; i < Keys.Length; i++)
            {
                var cell = new RectangleF(3 + i * sw, 3, sw, Height - 6);
                bool sel = Keys[i] == Value;
                if (sel || i == hover)
                    using (var path = Theme.Round(new RectangleF(cell.X + 1, cell.Y, cell.Width - 2, cell.Height), 6))
                    using (var b = new SolidBrush(sel ? Color.FromArgb(70, 248, 211, 107) : Color.FromArgb(14, 255, 255, 255)))
                        g.FillPath(b, path);
                TextRenderer.DrawText(g, Labels[i], Font, Rectangle.Round(cell), sel ? Theme.Gold : (i == hover ? Theme.Ink : Theme.Muted), TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter | TextFormatFlags.NoPadding);
            }
        }
    }

    class LinkText : Label
    {
        public LinkText(string text)
        {
            Text = text;
            AutoSize = true;
            Cursor = Cursors.Hand;
            ForeColor = Theme.GoldDim;
            BackColor = Color.Transparent;
            Font = new Font("Segoe UI", 9f);
        }
        protected override void OnMouseEnter(EventArgs e) { ForeColor = Theme.Gold; base.OnMouseEnter(e); }
        protected override void OnMouseLeave(EventArgs e) { ForeColor = Theme.GoldDim; base.OnMouseLeave(e); }
    }

    class Settings
    {
        public string Wow = "";
        public string Region = "auto";
        public bool Tray = true;
        public long LastLatest;
        public long LastBuilt;
        public bool TrayHinted;

        static string FilePath { get { return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "LifeOnAzeroth", "companion.ini"); } }

        public static Settings Load()
        {
            var s = new Settings();
            try
            {
                if (!File.Exists(FilePath)) return s;
                foreach (string line in File.ReadAllLines(FilePath))
                {
                    int eq = line.IndexOf('=');
                    if (eq < 0) continue;
                    string k = line.Substring(0, eq).Trim(), v = line.Substring(eq + 1).Trim();
                    if (k == "wow") s.Wow = v;
                    else if (k == "region") s.Region = v;
                    else if (k == "tray") s.Tray = v == "1";
                    else if (k == "lastLatest") long.TryParse(v, out s.LastLatest);
                    else if (k == "lastBuilt") long.TryParse(v, out s.LastBuilt);
                    else if (k == "trayHinted") s.TrayHinted = v == "1";
                }
            }
            catch { }
            return s;
        }

        public void Save()
        {
            try
            {
                Directory.CreateDirectory(Path.GetDirectoryName(FilePath));
                File.WriteAllLines(FilePath, new[] {
                    "wow=" + Wow, "region=" + Region, "tray=" + (Tray ? "1" : "0"),
                    "lastLatest=" + LastLatest, "lastBuilt=" + LastBuilt, "trayHinted=" + (TrayHinted ? "1" : "0") });
            }
            catch { }
        }
    }

    static class Game
    {
        public static string Forever(string root)
        {
            if (string.IsNullOrEmpty(root)) return null;
            if (Path.GetFileName(root.TrimEnd('\\', '/')).Equals("_forever_", StringComparison.OrdinalIgnoreCase) && Directory.Exists(root)) return root.TrimEnd('\\', '/');
            string f = Path.Combine(root, "_forever_");
            return Directory.Exists(f) ? f : null;
        }

        public static string Detect()
        {
            var roots = new List<string>();
            foreach (string key in new[] { @"SOFTWARE\WOW6432Node\Blizzard Entertainment\World of Warcraft", @"SOFTWARE\Blizzard Entertainment\World of Warcraft" })
            {
                try
                {
                    using (var k = Registry.LocalMachine.OpenSubKey(key))
                    {
                        var p = k == null ? null : k.GetValue("InstallPath") as string;
                        if (!string.IsNullOrEmpty(p))
                        {
                            var d = new DirectoryInfo(p.TrimEnd('\\'));
                            while (d != null) { roots.Add(d.FullName); d = d.Parent; }
                        }
                    }
                }
                catch { }
            }
            foreach (var drive in DriveInfo.GetDrives())
            {
                if (drive.DriveType != DriveType.Fixed) continue;
                string dr = drive.Name;
                roots.Add(Path.Combine(dr, @"Program Files (x86)\World of Warcraft"));
                roots.Add(Path.Combine(dr, @"Program Files\World of Warcraft"));
                roots.Add(Path.Combine(dr, @"World of Warcraft"));
                roots.Add(Path.Combine(dr, @"Games\World of Warcraft"));
                roots.Add(Path.Combine(dr, @"Battle.net\World of Warcraft"));
                roots.Add(Path.Combine(dr, @"Blizzard\World of Warcraft"));
            }
            foreach (string r in roots)
            {
                try { if (Forever(r) != null) return r; } catch { }
            }
            return null;
        }

        public static string PortalRegion(string forever)
        {
            try
            {
                string cfg = Path.Combine(forever, "WTF", "Config.wtf");
                if (!File.Exists(cfg)) return null;
                foreach (string line in File.ReadAllLines(cfg))
                {
                    string l = line.Trim();
                    if (!l.StartsWith("SET portal ", StringComparison.OrdinalIgnoreCase)) continue;
                    string v = l.Substring(11).Trim().Trim('"').ToLowerInvariant();
                    if (Sync.Regions.Contains(v)) return v;
                }
            }
            catch { }
            return null;
        }
    }

    class MainForm : Form
    {
        [DllImport("dwmapi.dll")] static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int val, int size);

        static readonly Dictionary<string, string> RegionName = new Dictionary<string, string> { { "us", "Americas" }, { "eu", "Europe" }, { "kr", "Korea" }, { "tw", "Taiwan" } };

        Settings cfg = Settings.Load();
        float S = 1f;
        Image logo;
        Icon appIcon;
        NotifyIcon tray;
        FlatButton updateBtn;
        Segmented regionSeg;
        Toggle startToggle, trayToggle;
        LinkText changeLink, openLink, siteLink;
        System.Windows.Forms.Timer timer;
        bool busy, quitting, startHidden, freshInstall;
        double progress;
        string statusTitle = "Starting", statusDetail = "", progressText = "";
        Color statusColor = Theme.Muted;
        DateTime nextCheck = DateTime.MinValue, lastCheck = DateTime.MinValue;
        string forever;

        public MainForm(bool hidden)
        {
            startHidden = hidden;
            var asm = Assembly.GetExecutingAssembly();
            using (var s = asm.GetManifestResourceStream("app.ico")) appIcon = new Icon(s);
            using (var s = asm.GetManifestResourceStream("logo96.png")) logo = Image.FromStream(s);
            using (var g = CreateGraphics()) S = g.DpiX / 96f;
            Text = "Life on Azeroth Companion";
            Icon = appIcon;
            BackColor = Theme.Bg;
            ForeColor = Theme.Ink;
            FormBorderStyle = FormBorderStyle.FixedSingle;
            MaximizeBox = false;
            StartPosition = FormStartPosition.CenterScreen;
            AutoScaleMode = AutoScaleMode.None;
            ClientSize = new Size(P(560), P(440));
            DoubleBuffered = true;
            Font = new Font("Segoe UI", 9.5f);

            updateBtn = new FlatButton("Update now", true);
            updateBtn.Bounds = R(388, 134, 128, 36);
            updateBtn.Click += delegate { CheckNow(true); };
            Controls.Add(updateBtn);

            changeLink = new LinkText("Change");
            changeLink.Location = new Point(P(488), P(232));
            changeLink.Click += delegate { PickFolder(); };
            Controls.Add(changeLink);

            regionSeg = new Segmented(new[] { "auto", "us", "eu", "kr", "tw" }, new[] { "Auto", "US", "EU", "KR", "TW" });
            regionSeg.Bounds = R(232, 266, 304, 30);
            regionSeg.Value = cfg.Region;
            regionSeg.Changed += delegate { cfg.Region = regionSeg.Value; cfg.LastLatest = 0; cfg.Save(); Invalidate(); CheckNow(true); };
            Controls.Add(regionSeg);

            openLink = new LinkText("Open folder");
            openLink.Location = new Point(P(462), P(318));
            openLink.Click += delegate { if (forever != null) Process.Start("explorer.exe", "\"" + Sync.AddonDir(forever) + "\""); };
            Controls.Add(openLink);

            startToggle = new Toggle("Start with Windows");
            startToggle.Location = new Point(P(24), P(354));
            startToggle.Size = new Size(startToggle.Fit(P(28)), P(28));
            startToggle.On = AutoStart;
            startToggle.Changed += delegate { AutoStart = startToggle.On; };
            Controls.Add(startToggle);

            trayToggle = new Toggle("Keep running in the tray when closed");
            trayToggle.Size = new Size(trayToggle.Fit(P(28)), P(28));
            trayToggle.Location = new Point(ClientSize.Width - P(24) - trayToggle.Width, P(354));
            trayToggle.On = cfg.Tray;
            trayToggle.Changed += delegate { cfg.Tray = trayToggle.On; cfg.Save(); };
            Controls.Add(trayToggle);

            siteLink = new LinkText("lifeonazeroth.com");
            siteLink.Location = new Point(ClientSize.Width - P(24) - siteLink.PreferredWidth, P(50));
            siteLink.Click += delegate { Process.Start("https://lifeonazeroth.com/#economy"); };
            Controls.Add(siteLink);

            var menu = new ContextMenuStrip();
            menu.Items.Add("Open", null, delegate { ShowWindow(); });
            menu.Items.Add("Update now", null, delegate { CheckNow(true); });
            menu.Items.Add(new ToolStripSeparator());
            menu.Items.Add("Quit", null, delegate { quitting = true; Close(); });
            tray = new NotifyIcon { Icon = appIcon, Text = "Life on Azeroth Companion", ContextMenuStrip = menu, Visible = true };
            tray.DoubleClick += delegate { ShowWindow(); };
            tray.BalloonTipClicked += delegate { ShowWindow(); };

            timer = new System.Windows.Forms.Timer { Interval = 15000 };
            timer.Tick += delegate { if (!busy && DateTime.Now >= nextCheck) CheckNow(false); Invalidate(R(24, 108, 512, 100)); };
            timer.Start();

            Resolve();
        }

        int P(float v) { return (int)Math.Round(v * S); }
        Rectangle R(float x, float y, float w, float h) { return new Rectangle(P(x), P(y), P(w), P(h)); }

        protected override void OnHandleCreated(EventArgs e)
        {
            base.OnHandleCreated(e);
            int on = 1;
            try { if (DwmSetWindowAttribute(Handle, 20, ref on, 4) != 0) DwmSetWindowAttribute(Handle, 19, ref on, 4); } catch { }
            try { int col = (Theme.Bg.B << 16) | (Theme.Bg.G << 8) | Theme.Bg.R; DwmSetWindowAttribute(Handle, 35, ref col, 4); } catch { }
        }

        protected override void SetVisibleCore(bool value)
        {
            if (startHidden) { if (!IsHandleCreated) CreateHandle(); value = false; }
            base.SetVisibleCore(value);
        }

        protected override void OnShown(EventArgs e)
        {
            base.OnShown(e);
            CheckNow(false);
        }

        protected override void WndProc(ref Message m)
        {
            if (m.Msg == Program.ShowMsg) ShowWindow();
            base.WndProc(ref m);
        }

        void ShowWindow()
        {
            startHidden = false;
            Show();
            if (WindowState == FormWindowState.Minimized) WindowState = FormWindowState.Normal;
            Activate();
        }

        protected override void OnFormClosing(FormClosingEventArgs e)
        {
            if (!quitting && cfg.Tray && e.CloseReason == CloseReason.UserClosing)
            {
                e.Cancel = true;
                Hide();
                if (!cfg.TrayHinted)
                {
                    cfg.TrayHinted = true;
                    cfg.Save();
                    tray.ShowBalloonTip(4000, "Still keeping prices fresh", "Life on Azeroth Companion keeps running in the tray. Right-click the icon to quit.", ToolTipIcon.None);
                }
                return;
            }
            tray.Visible = false;
            base.OnFormClosing(e);
        }

        static bool AutoStart
        {
            get
            {
                try { using (var k = Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Run")) return k != null && k.GetValue("LifeOnAzerothCompanion") != null; }
                catch { return false; }
            }
            set
            {
                try
                {
                    using (var k = Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Run", true))
                    {
                        if (value) k.SetValue("LifeOnAzerothCompanion", "\"" + Application.ExecutablePath + "\" --tray");
                        else k.DeleteValue("LifeOnAzerothCompanion", false);
                    }
                }
                catch { }
            }
        }

        string GameRegion
        {
            get
            {
                if (cfg.Region != "auto" && Sync.Regions.Contains(cfg.Region)) return cfg.Region;
                return (forever != null ? Game.PortalRegion(forever) : null) ?? "us";
            }
        }

        void Resolve()
        {
            forever = Game.Forever(cfg.Wow);
            if (forever == null)
            {
                string found = Game.Detect();
                if (found != null) { cfg.Wow = found; cfg.Save(); forever = Game.Forever(found); }
            }
            if (forever != null)
            {
                try { if (Sync.InstallAddon(forever)) freshInstall = true; }
                catch (Exception ex) { SetStatus("Can't write to the game folder", ex.Message, Theme.Down); }
            }
            Invalidate();
        }

        void PickFolder()
        {
            using (var d = new FolderBrowserDialog())
            {
                d.Description = "Select your World of Warcraft folder (the one that contains _forever_).";
                d.ShowNewFolderButton = false;
                if (!string.IsNullOrEmpty(cfg.Wow) && Directory.Exists(cfg.Wow)) d.SelectedPath = cfg.Wow;
                if (d.ShowDialog(this) != DialogResult.OK) return;
                string pick = d.SelectedPath;
                if (Game.Forever(pick) == null)
                {
                    var parent = Directory.GetParent(pick);
                    if (parent != null && Game.Forever(parent.FullName) != null) pick = parent.FullName;
                }
                if (Game.Forever(pick) == null)
                {
                    SetStatus("That isn't a WoW folder", "Pick the World of Warcraft folder that contains _forever_.", Theme.Down);
                    return;
                }
                cfg.Wow = pick;
                cfg.LastLatest = 0;
                cfg.Save();
                Resolve();
                CheckNow(true);
            }
        }

        void SetStatus(string title, string detail, Color c)
        {
            statusTitle = title;
            statusDetail = detail;
            statusColor = c;
            Invalidate();
        }

        void CheckNow(bool force)
        {
            if (busy) return;
            if (forever == null)
            {
                Resolve();
                if (forever == null)
                {
                    SetStatus("Find your game folder", "Click Change and select your World of Warcraft folder.", Theme.Gold);
                    nextCheck = DateTime.Now.AddMinutes(5);
                    return;
                }
            }
            busy = true;
            updateBtn.Enabled = false;
            progress = 0;
            progressText = "";
            string rg = GameRegion, dir = forever;
            long last = force ? 0 : cfg.LastLatest;
            SetStatus("Checking for new prices", "Talking to lifeonazeroth.com", Theme.Busy);
            Task.Factory.StartNew(() =>
            {
                try
                {
                    if (Sync.InstallAddon(dir)) freshInstall = true;
                    var res = Sync.Run(dir, rg, last, (txt, p) => BeginInvoke((Action)(() =>
                    {
                        progress = p;
                        progressText = txt;
                        statusTitle = "Updating prices";
                        statusDetail = txt;
                        statusColor = Theme.Busy;
                        Invalidate(R(24, 108, 512, 100));
                    })));
                    BeginInvoke((Action)(() => Done(res, rg, null)));
                }
                catch (Exception ex)
                {
                    BeginInvoke((Action)(() => Done(null, rg, ex)));
                }
            });
        }

        void Done(SyncResult res, string rg, Exception ex)
        {
            busy = false;
            updateBtn.Enabled = true;
            lastCheck = DateTime.Now;
            if (ex != null)
            {
                nextCheck = DateTime.Now.AddMinutes(5);
                bool net = ex is WebException;
                SetStatus(net ? "Can't reach Life on Azeroth" : "Something went wrong", (net ? "Check your internet connection. " : ex.Message + " ") + "Trying again in 5 minutes.", Theme.Down);
                return;
            }
            nextCheck = DateTime.Now.AddMinutes(15);
            if (res.Changed)
            {
                cfg.LastBuilt = res.Built;
                cfg.LastLatest = res.Latest;
                cfg.Save();
                if (freshInstall && Process.GetProcessesByName("Wow").Length > 0) SetStatus("Addon installed", "Restart WoW to load it, then type /market.", Theme.Up);
                else SetStatus("New prices ready", "Type /reload in game to load them.", Theme.Up);
                freshInstall = false;
            }
            else
            {
                cfg.LastLatest = res.Latest;
                cfg.Save();
                SetStatus("Up to date", "", Theme.Up);
            }
            tray.Text = "Life on Azeroth · prices from " + Local(res.Latest).ToString("HH:mm");
        }

        static DateTime Local(long unix) { return new DateTime(1970, 1, 1, 0, 0, 0, DateTimeKind.Utc).AddSeconds(unix).ToLocalTime(); }

        static string Ago(DateTime t)
        {
            var s = DateTime.Now - t;
            if (s.TotalSeconds < 60) return "just now";
            if (s.TotalMinutes < 60) return (int)s.TotalMinutes + " min ago";
            return (int)s.TotalHours + " h ago";
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            var g = e.Graphics;
            Theme.Smooth(g);
            using (var lg = new LinearGradientBrush(new Rectangle(0, 0, ClientSize.Width, P(120)), Color.FromArgb(34, 26, 14), Theme.Bg, 90f))
                g.FillRectangle(lg, 0, 0, ClientSize.Width, P(120));

            g.InterpolationMode = InterpolationMode.HighQualityBicubic;
            g.DrawImage(logo, R(22, 18, 58, 58));
            using (var f = new Font("Georgia", 17f, FontStyle.Bold))
                TextRenderer.DrawText(g, "Life on Azeroth", f, new Point(P(90), P(22)), Theme.Title, TextFormatFlags.NoPadding);
            using (var f = new Font("Segoe UI", 9.5f))
                TextRenderer.DrawText(g, "Market companion for WoW: Forever", f, new Point(P(92), P(54)), Theme.Muted, TextFormatFlags.NoPadding);
            using (var f = new Font("Segoe UI", 8.5f))
                TextRenderer.DrawText(g, "v" + Program.Version, f, new Rectangle(0, P(26), ClientSize.Width - P(24), P(20)), Theme.Muted, TextFormatFlags.Right | TextFormatFlags.NoPadding);
            using (var lg = new LinearGradientBrush(new Rectangle(P(24), P(92), P(512), 2), Color.FromArgb(150, 248, 211, 107), Color.FromArgb(0, 248, 211, 107), 0f))
                g.FillRectangle(lg, P(24), P(92), P(512), Math.Max(1, P(1)));

            var card = new RectangleF(P(24), P(108), P(512), P(88));
            using (var path = Theme.Round(card, P(10)))
            {
                using (var b = new SolidBrush(Theme.Card)) g.FillPath(b, path);
                using (var p = new Pen(Theme.Line)) g.DrawPath(p, path);
            }
            using (var b = new SolidBrush(Color.FromArgb(40, statusColor))) g.FillEllipse(b, P(40), P(129), P(18), P(18));
            using (var b = new SolidBrush(statusColor)) g.FillEllipse(b, P(44), P(133), P(10), P(10));
            using (var f = new Font("Segoe UI Semibold", 12.5f))
                TextRenderer.DrawText(g, statusTitle, f, new Point(P(68), P(124)), Theme.Ink, TextFormatFlags.NoPadding);
            string detail = statusDetail;
            if (!busy && statusColor == Theme.Up && cfg.LastLatest > 0)
            {
                string when = RegionName[GameRegion] + " prices from " + Local(cfg.LastLatest).ToString("ddd HH:mm");
                detail = string.IsNullOrEmpty(statusDetail) ? when + " · checked " + Ago(lastCheck) : when + " · " + statusDetail;
            }
            using (var f = new Font("Segoe UI", 9.25f))
                TextRenderer.DrawText(g, detail, f, new Rectangle(P(68), P(150), P(330), P(36)), Theme.Ink2, TextFormatFlags.WordBreak | TextFormatFlags.NoPadding | TextFormatFlags.EndEllipsis);
            if (busy)
            {
                var track = new RectangleF(card.X + P(16), card.Bottom - P(12), card.Width - P(32), P(3));
                using (var b = new SolidBrush(Color.FromArgb(40, 255, 255, 255))) g.FillRectangle(b, track);
                using (var b = new SolidBrush(Theme.Gold)) g.FillRectangle(b, track.X, track.Y, (float)(track.Width * Math.Max(0.03, progress)), track.Height);
            }

            DrawRow(g, 232, "Game folder", forever ?? "Not found yet", forever == null ? Theme.Down : Theme.Ink, P(330));
            DrawRow(g, 274, "Region", null, Theme.Ink, 0);
            using (var f = new Font("Segoe UI", 8.5f))
                if (cfg.Region == "auto") TextRenderer.DrawText(g, "Detected: " + RegionName[GameRegion], f, new Point(P(120), P(276)), Theme.Muted, TextFormatFlags.NoPadding);
            string ver = forever != null ? Sync.InstalledVersion(forever) : null;
            DrawRow(g, 318, "Addon", ver != null ? "Life on Azeroth Market · installed, v" + ver : "Not installed yet", ver != null ? Theme.Ink : Theme.Muted, P(320));

            using (var p = new Pen(Theme.Line)) g.DrawLine(p, P(24), P(394), ClientSize.Width - P(24), P(394));
            using (var f = new Font("Segoe UI", 9f))
            {
                TextRenderer.DrawText(g, "In game, type /reload to load new prices and /market to open the Market.", f, new Rectangle(P(24), P(406), ClientSize.Width - P(48), P(22)), Theme.Muted, TextFormatFlags.NoPadding | TextFormatFlags.HorizontalCenter);
            }
        }

        void DrawRow(Graphics g, float y, string label, string value, Color c, int maxW)
        {
            using (var f = new Font("Segoe UI", 9f))
                TextRenderer.DrawText(g, label, f, new Point(P(24), P(y)), Theme.Muted, TextFormatFlags.NoPadding);
            if (value != null)
                using (var f = new Font("Segoe UI", 9.5f))
                    TextRenderer.DrawText(g, value, f, new Rectangle(P(120), P(y - 1), maxW, P(22)), c, TextFormatFlags.NoPadding | TextFormatFlags.PathEllipsis | TextFormatFlags.SingleLine);
        }
    }
}
