param([switch]$SelfTest)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
$script:root = $PSScriptRoot
$script:process = $null
$script:cancelled = $false
$form = New-Object Windows.Forms.Form
$form.Text = 'Descargador de videos'
$form.Icon=New-Object Drawing.Icon((Join-Path $script:root 'Logo.ico'))
$form.ClientSize = New-Object Drawing.Size(760,610)
$form.MinimumSize = $form.Size
$form.MaximumSize = $form.Size
$form.StartPosition = 'CenterScreen'
$form.Font = New-Object Drawing.Font('Segoe UI',10)
$form.BackColor = [Drawing.Color]::FromArgb(245,247,251)
function Label($text,$x,$y,$w) {
    $c = New-Object Windows.Forms.Label
    $c.Text=$text; $c.SetBounds($x,$y,$w,26); $form.Controls.Add($c)
    return $c
}
function Button($text,$x,$y,$w) {
    $c=New-Object Windows.Forms.Button
    $c.Text=$text; $c.SetBounds($x,$y,$w,36); $form.Controls.Add($c)
    return $c
}
$logo=New-Object Windows.Forms.PictureBox
$logo.SetBounds(24,20,44,44)
$logo.SizeMode='Zoom'
$logo.Image=[Drawing.Image]::FromFile((Join-Path $script:root 'Logo.png'))
$form.Controls.Add($logo)
$title=Label 'Descarga tus videos' 80 20 654
$title.Font=New-Object Drawing.Font('Segoe UI',19,[Drawing.FontStyle]::Bold)
$title.Height=40
$null=Label 'Pega el enlace de un video para guardarlo en tu equipo.' 24 66 710
$null=Label 'Enlace del video' 24 108 500
$url=New-Object Windows.Forms.TextBox
$url.SetBounds(24,137,710,30); $form.Controls.Add($url)
$null=Label 'Calidad maxima' 24 183 250
$quality=New-Object Windows.Forms.ComboBox
$quality.DropDownStyle='DropDownList'; $quality.SetBounds(24,212,250,30)
$quality.Items.AddRange(@('Video MP4 compatible','Video MP4 hasta 1080p','Video MP4 hasta 720p','Video MP4 hasta 480p','Solo audio MP3 (sin video)'))
$quality.SelectedIndex=0; $form.Controls.Add($quality)
$null=Label 'Guardar en' 24 255 600
$folder=New-Object Windows.Forms.TextBox
$folder.SetBounds(24,284,585,30); $folder.Text=(Join-Path $script:root 'Descargas'); $form.Controls.Add($folder)
$browse=Button 'Elegir...' 620 280 114
$download=Button 'Descargar' 24 330 165
$download.BackColor=[Drawing.Color]::FromArgb(35,96,210); $download.ForeColor=[Drawing.Color]::White
$cancel=Button 'Cancelar' 200 330 115; $cancel.Enabled=$false
$open=Button 'Abrir carpeta' 326 330 140
$update=Button 'Actualizar motor' 477 330 170
$status=Label 'Listo. Los componentes se preparan en la primera descarga.' 24 382 710
$progress=New-Object Windows.Forms.ProgressBar
$progress.SetBounds(24,414,710,12); $form.Controls.Add($progress)
$log=New-Object Windows.Forms.TextBox
$log.SetBounds(24,440,710,110); $log.Multiline=$true; $log.ReadOnly=$true; $log.ScrollBars='Vertical'
$log.Font=New-Object Drawing.Font('Consolas',9); $form.Controls.Add($log)
$note=Label (([char]0x00A9).ToString()+' 2026 Pavel Damon') 24 568 710
$note.TextAlign='MiddleCenter'
$note.ForeColor=[Drawing.Color]::DimGray
$browse.Add_Click({
    $dialog=New-Object Windows.Forms.FolderBrowserDialog
    $dialog.Description='Elige donde guardar tus videos'
    if($dialog.ShowDialog() -eq 'OK') {$folder.Text=$dialog.SelectedPath}
    $dialog.Dispose()
})
$open.Add_Click({
    try { $null=New-Item -ItemType Directory -Force -Path $folder.Text; Start-Process explorer.exe -ArgumentList ('"'+$folder.Text+'"') }
    catch {[Windows.Forms.MessageBox]::Show($_.Exception.Message,'No se pudo abrir')}
})
function Start-Work($action) {
    if($script:process) { return }
    try {
        if($action -eq 'download') {
            $uri=$null
            if(-not [Uri]::TryCreate($url.Text.Trim(),[UriKind]::Absolute,[ref]$uri) -or $uri.Scheme -notin @('http','https')) {throw 'Introduce un enlace valido que empiece por https:// o http://.'}
            if([string]::IsNullOrWhiteSpace($folder.Text) -or -not [IO.Path]::IsPathRooted($folder.Text)) {throw 'Elige una carpeta de destino con ruta completa.'}
        }
        $run=Join-Path $script:root ('work\'+[Guid]::NewGuid().ToString('N'))
        $null=New-Item -ItemType Directory -Force -Path $run
        @{action=$action;url=$url.Text.Trim();folder=$folder.Text;quality=$quality.SelectedIndex} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $run 'request.json') -Encoding UTF8
        $script:logfile=Join-Path $run 'log.txt'
        $script:resultfile=Join-Path $run 'result.json'
        $script:cancelled=$false
        $script:currentAction=$action
        $script:startedAt=Get-Date
        $script:phase='Preparando descarga'
        $worker=Join-Path $script:root 'Worker.ps1'
        $script:process=Start-Process powershell.exe -ArgumentList ('-NoProfile -ExecutionPolicy Bypass -File "'+$worker+'" -RunFolder "'+$run+'"') -WindowStyle Hidden -PassThru
        $download.Enabled=$false; $update.Enabled=$false; $cancel.Enabled=$true; $url.Enabled=$false; $folder.Enabled=$false; $browse.Enabled=$false; $quality.Enabled=$false
        $status.Text='Preparando descarga...'; $log.Text=''; $progress.Value=0; $progress.Style='Marquee'
        $timer.Start()
    } catch {[Windows.Forms.MessageBox]::Show($_.Exception.Message,'Revisa los datos')}
}
$download.Add_Click({Start-Work 'download'})
$update.Add_Click({Start-Work 'update'})
function Stop-Work {
    if($script:process -and -not $script:process.HasExited) {
        $script:cancelled=$true
        & taskkill.exe /PID $script:process.Id /T /F 2>&1 | Out-Null
    }
}
$cancel.Add_Click({Stop-Work})
$timer=New-Object Windows.Forms.Timer
$timer.Interval=500
$timer.Add_Tick({
    try {
        if(Test-Path -LiteralPath $script:logfile) {
            $lines=Get-Content -LiteralPath $script:logfile -Tail 100 -Encoding UTF8
            $newText=$lines -join [Environment]::NewLine
            if($log.Text -ne $newText) {$log.Text=$newText; $log.SelectionStart=$log.TextLength; $log.ScrollToCaret()}
            $last=@($lines | Where-Object {-not [string]::IsNullOrWhiteSpace($_)}) | Select-Object -Last 1
            if($last -match '\[download\]\s+([0-9.]+)%') {
                $progress.Style='Continuous'
                $progress.Value=[Math]::Min(100,[int][double]::Parse($Matches[1],[Globalization.CultureInfo]::InvariantCulture))
                $script:phase='Descargando: '+$Matches[1]+'%'
            } elseif($last -match 'Convirtiendo|frame=|libx264|Output #|encoder') {
                $script:phase='Convirtiendo a MP4 compatible'; $progress.Style='Marquee'
            } elseif($last -match '\[Merger\]|\[ExtractAudio\]|Deleting original') {
                $script:phase='Finalizando el archivo'; $progress.Style='Marquee'
            } elseif($last -match 'Preparando (yt-dlp|FFmpeg|Deno)') {
                $script:phase='Instalando '+$Matches[1]+' (solo la primera vez)'
            } elseif($last -match 'Retrying|retry|timed out') {
                $script:phase='El sitio tarda en responder. Reintentando'
            } elseif($last -match '\[youtube|\[info\]|Conectando|Enlace directo') {
                $script:phase='Obteniendo el video y los formatos disponibles'
            }
        }
        $elapsed=(Get-Date)-$script:startedAt
        $status.Text=$script:phase+'  |  '+([int]$elapsed.TotalSeconds)+' s'
        if($script:process.HasExited) {
            $timer.Stop(); $progress.Style='Continuous'; $progress.Value=0
            $status.Text='No se pudo completar. Revisa el detalle de abajo.'
            if($script:cancelled) {$status.Text='Cancelado. Puedes reanudar descargando el mismo enlace.'}
            elseif(Test-Path -LiteralPath $script:resultfile) {
                $result=Get-Content -Raw -LiteralPath $script:resultfile -Encoding UTF8 | ConvertFrom-Json
                $status.Text=$result.message
                if($result.ok) {
                    $progress.Value=100
                    if($script:currentAction -eq 'download') {$url.Clear()}
                }
            }
            $script:process.Dispose(); $script:process=$null
            $download.Enabled=$true; $update.Enabled=$true; $cancel.Enabled=$false; $url.Enabled=$true; $folder.Enabled=$true; $browse.Enabled=$true; $quality.Enabled=$true
        }
    } catch {$status.Text='Esperando al proceso...'}
})
$form.Add_FormClosing({Stop-Work; $timer.Stop()})
if($SelfTest) { $form.Dispose(); 'UI_OK'; exit 0 }
[Windows.Forms.Application]::Run($form)
