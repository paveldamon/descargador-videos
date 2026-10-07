using System;
using System.Diagnostics;
using System.IO;
using System.Windows.Forms;

internal static class Iniciar
{
    [STAThread]
    private static void Main()
    {
        try
        {
            string script = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "Descargador.ps1");
            if (!File.Exists(script)) throw new FileNotFoundException("Extrae toda la carpeta del ZIP antes de abrir el programa.");
            string shell = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), @"WindowsPowerShell\v1.0\powershell.exe");
            Process.Start(new ProcessStartInfo(shell, "-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File \"" + script + "\"")
            {
                UseShellExecute = false,
                CreateNoWindow = true,
                WorkingDirectory = AppDomain.CurrentDomain.BaseDirectory
            });
        }
        catch (Exception ex) { MessageBox.Show(ex.Message, "Descargador de videos"); }
    }
}
