using System;
using System.Collections.Generic;
using System.Drawing;
using System.IO;
using System.IO.Compression;
using System.Net;
using System.Security.Cryptography;
using System.Threading.Tasks;
using System.Web.Script.Serialization;
using System.Windows.Forms;

public sealed class PackageInfo {
    public string version { get; set; }
    public string sha256 { get; set; }
    public string packageUrl { get; set; }
}

public static class Installation {
    public static readonly string[] Required = { "Abrir.cmd", "CrearLogo.ps1", "Descargador.exe", "Descargador.ps1", "Enlaces.ps1", "Iniciar.cs", "LEEME.txt", "Logo.ico", "Logo.png", "Video.ps1", "Worker.ps1" };

    public static void VerifyHash(string archive, string expected) {
        using (var stream = File.OpenRead(archive))
        using (var sha = SHA256.Create()) {
            var actual = BitConverter.ToString(sha.ComputeHash(stream)).Replace("-", "");
            if (!string.Equals(actual, expected, StringComparison.OrdinalIgnoreCase))
                throw new InvalidDataException("La descarga no paso la verificacion. Vuelve a intentar.");
        }
    }

    public static void Extract(string archive, string staging) {
        Directory.CreateDirectory(staging);
        var allowed = new HashSet<string>(Required, StringComparer.OrdinalIgnoreCase);
        var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        using (var zip = ZipFile.OpenRead(archive)) {
            long total = 0;
            foreach (var entry in zip.Entries) {
                string name = entry.FullName.Replace('\\', '/');
                if (name == "Descargador/") continue;
                if (!name.StartsWith("Descargador/", StringComparison.Ordinal)) throw new InvalidDataException("Paquete inesperado.");
                name = name.Substring("Descargador/".Length);
                if (!allowed.Contains(name) || !seen.Add(name)) throw new InvalidDataException("Archivo no permitido en el paquete.");
                total += entry.Length;
                if (total > 50 * 1024 * 1024) throw new InvalidDataException("El paquete supera el tamano permitido.");
                entry.ExtractToFile(Path.Combine(staging, name));
            }
        }
        foreach (var name in Required) if (!seen.Contains(name)) throw new InvalidDataException("Falta un archivo: " + name);
    }

    public static void Deploy(string staging, string destination, string backup) {
        Directory.CreateDirectory(destination);
        Directory.CreateDirectory(backup);
        var changed = new List<string>();
        try {
            foreach (var name in Required) {
                string target = Path.Combine(destination, name);
                if (File.Exists(target)) File.Copy(target, Path.Combine(backup, name));
                changed.Add(name);
                File.Copy(Path.Combine(staging, name), target, true);
            }
        } catch {
            changed.Reverse();
            foreach (var name in changed) {
                string old = Path.Combine(backup, name), target = Path.Combine(destination, name);
                try { if (File.Exists(old)) File.Copy(old, target, true); else if (File.Exists(target)) File.Delete(target); } catch { }
            }
            throw new IOException("No se pudo instalar. Cierra el Descargador y vuelve a intentar. Copia de respaldo: " + backup);
        }
    }

    public static void Shortcut(string destination, string directory) {
        Directory.CreateDirectory(directory);
        dynamic shell = Activator.CreateInstance(Type.GetTypeFromProgID("WScript.Shell"));
        dynamic link = shell.CreateShortcut(Path.Combine(directory, "Descargador de videos.lnk"));
        link.TargetPath = Path.Combine(destination, "Descargador.exe");
        link.WorkingDirectory = destination;
        link.IconLocation = Path.Combine(destination, "Logo.ico");
        link.Description = "Descargador de videos - Pavel Damon";
        link.Save();
    }
}

public sealed class InstallerWindow : Form {
    const string ManifestUrl = "https://raw.githubusercontent.com/paveldamon/descargador-videos/main/dist/latest.json";
    readonly string destination = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Programs", "Pavel Damon", "Descargador");
    readonly Label status = new Label();
    readonly ProgressBar progress = new ProgressBar();
    readonly Button install = new Button(), cancel = new Button(), open = new Button();
    WebClient client;
    bool busy;

    public InstallerWindow() {
        Text = "Instalar Descargador de videos";
        ClientSize = new Size(580,330);
        FormBorderStyle = FormBorderStyle.FixedDialog; MaximizeBox = false;
        StartPosition = FormStartPosition.CenterScreen;
        Font = new Font("Segoe UI", 10);
        BackColor = Color.FromArgb(245,247,251);
        Icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath);
        var logo = new PictureBox { Image = Icon.ToBitmap(), SizeMode = PictureBoxSizeMode.Zoom };
        logo.SetBounds(24,24,48,48); Controls.Add(logo);
        AddLabel("Descargador de videos", 84,24,470,36).Font = new Font("Segoe UI",19,FontStyle.Bold);
        AddLabel("Se descargara desde el repositorio de Pavel Damon en GitHub.",24,84,535,26);
        AddLabel("Instalacion para tu usuario, sin permisos de administrador.",24,113,535,26);
        var path = AddLabel(destination,24,148,535,38); path.Font = new Font("Segoe UI",9);
        status.SetBounds(24,192,535,40); status.Text="Listo para instalar. Cierra el Descargador si esta abierto."; Controls.Add(status);
        progress.SetBounds(24,240,535,12); Controls.Add(progress);
        install.Text="Instalar"; install.SetBounds(24,270,135,36); install.BackColor=Color.FromArgb(35,96,210); install.ForeColor=Color.White; Controls.Add(install);
        cancel.Text="Cancelar"; cancel.SetBounds(170,270,110,36); cancel.Enabled=false; Controls.Add(cancel);
        open.Text="Abrir programa"; open.SetBounds(291,270,140,36); open.Visible=false; Controls.Add(open);
        AddLabel("\u00a9 2026 Pavel Damon",443,279,130,24).Font=new Font("Segoe UI",8);
        install.Click += async delegate { await Install(); };
        cancel.Click += delegate { if(client != null) client.CancelAsync(); };
        open.Click += delegate { System.Diagnostics.Process.Start(Path.Combine(destination,"Descargador.exe")); Close(); };
        FormClosing += delegate(object sender, FormClosingEventArgs e) { if(busy) { e.Cancel=true; if(client != null) client.CancelAsync(); } };
    }
    Label AddLabel(string text,int x,int y,int w,int h) {
        var label=new Label { Text=text }; label.SetBounds(x,y,w,h); Controls.Add(label); return label;
    }
    async Task Install() {
        busy=true; install.Enabled=false; cancel.Enabled=true; open.Visible=false;
        string temp=Path.Combine(Path.GetTempPath(),"PavelDamon-Instalador-"+Guid.NewGuid().ToString("N"));
        bool preserveBackup=false;
        try {
            Directory.CreateDirectory(temp);
            ServicePointManager.SecurityProtocol=SecurityProtocolType.Tls12;
            using(client=new WebClient()) {
                client.Headers.Add("User-Agent","PavelDamon-Instalador/1.0");
                client.CachePolicy=new System.Net.Cache.RequestCachePolicy(System.Net.Cache.RequestCacheLevel.NoCacheNoStore);
                status.Text="Consultando la version disponible en GitHub...";
                progress.Style=ProgressBarStyle.Marquee;
                string json=await client.DownloadStringTaskAsync(new Uri(ManifestUrl+"?v="+DateTime.UtcNow.Ticks));
                var info=new JavaScriptSerializer().Deserialize<PackageInfo>(json);
                Uri packageUri;
                if(info==null || !Uri.TryCreate(info.packageUrl,UriKind.Absolute,out packageUri) || packageUri.Scheme!="https" || packageUri.Host!="raw.githubusercontent.com" || !packageUri.AbsolutePath.StartsWith("/paveldamon/descargador-videos/main/dist/",StringComparison.Ordinal) || string.IsNullOrEmpty(info.sha256))
                    throw new InvalidDataException("La informacion de GitHub no es valida.");
                string archive=Path.Combine(temp,"programa.zip");
                status.Text="Descargando version "+info.version+"...";
                progress.Style=ProgressBarStyle.Continuous; progress.Value=0;
                client.DownloadProgressChanged += delegate(object sender, DownloadProgressChangedEventArgs e) { progress.Value=Math.Max(0,Math.Min(100,e.ProgressPercentage)); };
                await client.DownloadFileTaskAsync(packageUri,archive);
                cancel.Enabled=false; progress.Style=ProgressBarStyle.Marquee;
                status.Text="Verificando e instalando...";
                await Task.Run(delegate {
                    Installation.VerifyHash(archive,info.sha256);
                    string staging=Path.Combine(temp,"archivos");
                    Installation.Extract(archive,staging);
                    preserveBackup=true;
                    Installation.Deploy(staging,destination,Path.Combine(temp,"respaldo"));
                    preserveBackup=false;
                });
                string shortcutNote="";
                try {
                    Installation.Shortcut(destination,Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory));
                    Installation.Shortcut(destination,Environment.GetFolderPath(Environment.SpecialFolder.Programs));
                } catch { shortcutNote=" No se pudo crear algun acceso directo."; }
                status.Text="Version "+info.version+" instalada."+shortcutNote;
                progress.Style=ProgressBarStyle.Continuous; progress.Value=100;
                open.Visible=true; install.Text="Reinstalar";
            }
        } catch(OperationCanceledException) { status.Text="Descarga cancelada. Puedes volver a intentar."; }
        catch(Exception ex) {
            status.Text="No se pudo completar la instalacion.";
            MessageBox.Show(this,ex.Message+"\n\nComprueba tu conexion a Internet y vuelve a intentar.","Instalacion",MessageBoxButtons.OK,MessageBoxIcon.Information);
        } finally {
            client=null; busy=false; install.Enabled=true; cancel.Enabled=false; progress.Style=ProgressBarStyle.Continuous;
            if(!open.Visible) progress.Value=0;
            // Only this run's generated temporary directory is eligible for cleanup.
            if(!preserveBackup && Directory.Exists(temp)) { try { Directory.Delete(temp,true); } catch {} }
        }
    }
    [STAThread] public static void Main() { Application.EnableVisualStyles(); Application.Run(new InstallerWindow()); }
}

