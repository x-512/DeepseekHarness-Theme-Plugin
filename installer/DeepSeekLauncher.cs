using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Net;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Windows.Forms;
using Microsoft.Web.WebView2.Core;
using Microsoft.Web.WebView2.WinForms;

internal static class Program {
  [STAThread] static void Main() {
    Application.EnableVisualStyles();
    Application.SetCompatibleTextRenderingDefault(false);
    bool owns;
    using (var mutex = new Mutex(true, @"Local\DeepSeekHarnessLuluDesktop", out owns)) {
      if (!owns) return;
      Application.Run(new HarnessForm());
    }
  }
}

internal sealed class HarnessForm : Form {
  static readonly string Root = Directory.GetParent(AppDomain.CurrentDomain.BaseDirectory.TrimEnd(Path.DirectorySeparatorChar)).FullName;
  static readonly string Node = Path.Combine(Root, @"runtime\node-v24.19.0-win-x64\node.exe");
  static readonly string Cli = Path.Combine(Root, @"app\node_modules\@deepseek-ai\dsh\lib\bin.js");
  static readonly string Data = Path.Combine(Root, "data");
  static readonly string Workspace = Path.Combine(Root, "workspace");
  static readonly string Theme = Path.Combine(Root, @"launcher\desktop-theme.js");
  readonly Label status = new Label();
  readonly WebView2 browser = new WebView2();
  Process service;

  internal HarnessForm() {
    Text = "DeepSeek Harness";
    StartPosition = FormStartPosition.CenterScreen;
    MinimumSize = new Size(960, 640);
    Size = new Size(1280, 820);
    status.Dock = DockStyle.Fill;
    status.Text = "DeepSeek Harness 正在启动...";
    status.TextAlign = ContentAlignment.MiddleCenter;
    status.Font = new Font("Microsoft YaHei UI", 15F);
    browser.Dock = DockStyle.Fill;
    browser.Visible = false;
    Controls.Add(browser);
    Controls.Add(status);
    Shown += async delegate { await StartAsync(); };
    FormClosing += delegate { try { if (service != null && !service.HasExited) service.Kill(); } catch {} };
  }

  async Task StartAsync() {
    try {
      if (!File.Exists(Node)) throw new FileNotFoundException("Node.js 运行时缺失。", Node);
      if (!File.Exists(Cli)) throw new FileNotFoundException("DeepSeek Harness 主程序缺失。", Cli);
      if (!File.Exists(Theme)) throw new FileNotFoundException("Lulu 主题脚本缺失。", Theme);
      Directory.CreateDirectory(Data);
      Directory.CreateDirectory(Workspace);
      if (!Ready()) StartService();
      var deadline = DateTime.UtcNow.AddSeconds(90);
      while (!Ready() && DateTime.UtcNow < deadline) await Task.Delay(400);
      if (!Ready()) throw new TimeoutException("Harness 服务启动超时。请检查端口 3080。 ");
      var environment = await CoreWebView2Environment.CreateAsync(null, Path.Combine(Data, "webview2"));
      await browser.EnsureCoreWebView2Async(environment);
      string script = File.ReadAllText(Theme, Encoding.UTF8);
      await browser.CoreWebView2.AddScriptToExecuteOnDocumentCreatedAsync(script);
      browser.CoreWebView2.Settings.AreDevToolsEnabled = false;
      browser.CoreWebView2.Settings.AreDefaultContextMenusEnabled = false;
      browser.CoreWebView2.Settings.IsStatusBarEnabled = false;
      browser.CoreWebView2.NavigationStarting += delegate(object sender, CoreWebView2NavigationStartingEventArgs e) {
        Uri uri;
        if (!Uri.TryCreate(e.Uri, UriKind.Absolute, out uri) || uri.Scheme != "http" || uri.Host != "127.0.0.1" || uri.Port != 3080) e.Cancel = true;
      };
      browser.CoreWebView2.Navigate("http://127.0.0.1:3080/");
      browser.Visible = true;
      status.Visible = false;
      WindowState = FormWindowState.Maximized;
    } catch (Exception error) {
      status.ForeColor = Color.Firebrick;
      status.Text = "DeepSeek Harness 启动失败\n\n" + error.Message;
    }
  }

  void StartService() {
    var logDir = Path.Combine(Root, "logs");
    Directory.CreateDirectory(logDir);
    var info = new ProcessStartInfo(Node, "\"" + Cli + "\" web --host 127.0.0.1 --port 3080");
    info.WorkingDirectory = Workspace;
    info.UseShellExecute = false;
    info.CreateNoWindow = true;
    info.WindowStyle = ProcessWindowStyle.Hidden;
    info.EnvironmentVariables["DSH_HOME"] = Data;
    info.EnvironmentVariables["DSH_AGENTS_HOME"] = Path.Combine(Data, ".agents");
    info.EnvironmentVariables["NPM_CONFIG_CACHE"] = Path.Combine(Root, "npm-cache");
    service = Process.Start(info);
  }

  static bool Ready() {
    try {
      var request = (HttpWebRequest)WebRequest.Create("http://127.0.0.1:3080/");
      request.Timeout = 500;
      request.AllowAutoRedirect = false;
      using (var response = (HttpWebResponse)request.GetResponse()) return (int)response.StatusCode < 500;
    } catch { return false; }
  }
}
