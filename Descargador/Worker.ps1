param([Parameter(Mandatory=$true)][string]$RunFolder)
$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
$log=Join-Path $RunFolder 'log.txt'
$result=Join-Path $RunFolder 'result.json'
$bin=Join-Path $PSScriptRoot 'bin'
. (Join-Path $PSScriptRoot 'Enlaces.ps1')
. (Join-Path $PSScriptRoot 'Video.ps1')
$null=New-Item -ItemType Directory -Force -Path $bin
function Write-Log($message) {Add-Content -LiteralPath $log -Value $message -Encoding UTF8}
function Fetch($url,$target) {
    $part=$target+'.part'
    $client=New-Object Net.WebClient
    $client.Headers.Add('User-Agent','Descargador-Windows')
    try {$client.DownloadFile($url,$part); Move-Item -LiteralPath $part -Destination $target -Force} finally {$client.Dispose()}
}
function Install-Engine {
    Write-Log 'Preparando yt-dlp desde su repositorio oficial...'
    $release=Invoke-RestMethod 'https://api.github.com/repos/yt-dlp/yt-dlp/releases/latest'
    $exe=@($release.assets | Where-Object name -eq 'yt-dlp.exe')[0]
    $checks=@($release.assets | Where-Object name -eq 'SHA2-256SUMS')[0]
    if(-not $exe -or -not $checks) {throw 'No se encontro la version de Windows de yt-dlp.'}
    $temp=Join-Path $RunFolder 'yt-dlp.exe'
    Fetch $exe.browser_download_url $temp
    $sumfile=Join-Path $RunFolder 'SHA2-256SUMS'
    Fetch $checks.browser_download_url $sumfile
    $entry=Get-Content -LiteralPath $sumfile | Where-Object {$_ -match '\s+\*?yt-dlp\.exe$'} | Select-Object -First 1
    if(-not $entry -or (Get-FileHash -LiteralPath $temp -Algorithm SHA256).Hash -ne ($entry -split '\s+')[0]) {throw 'No coincide la verificacion del archivo descargado.'}
    Move-Item -LiteralPath $temp -Destination (Join-Path $bin 'yt-dlp.exe') -Force
}
try {
    $request=Get-Content -Raw -LiteralPath (Join-Path $RunFolder 'request.json') -Encoding UTF8 | ConvertFrom-Json
    if($request.action -eq 'update' -or -not (Test-Path (Join-Path $bin 'yt-dlp.exe'))) {Install-Engine}
    if($request.action -eq 'update') {
        @{ok=$true;message='Motor actualizado. Ya puedes descargar.'} | ConvertTo-Json | Set-Content -LiteralPath $result -Encoding UTF8
        exit 0
    }
    if(-not (Test-Path (Join-Path $bin 'ffmpeg.exe')) -or -not (Test-Path (Join-Path $bin 'ffprobe.exe'))) {
        Write-Log 'Preparando FFmpeg para unir video y audio. Puede tardar varios minutos...'
        $archive=Join-Path $RunFolder 'ffmpeg.zip'
        Fetch 'https://github.com/yt-dlp/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip' $archive
        $extract=Join-Path $RunFolder 'ffmpeg'
        # Extract only the two executables, not the full archive and documentation.
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $zip=[IO.Compression.ZipFile]::OpenRead($archive)
        try {
            foreach($name in @('ffmpeg.exe','ffprobe.exe')) {
                $entry=$zip.Entries | Where-Object Name -eq $name | Select-Object -First 1
                if(-not $entry) {throw "Falta $name en el paquete descargado."}
                $staged=Join-Path $RunFolder $name
                [IO.Compression.ZipFileExtensions]::ExtractToFile($entry,$staged,$true)
                Move-Item -LiteralPath $staged -Destination (Join-Path $bin $name) -Force
            }
        } finally {$zip.Dispose()}
    }
    if(-not (Test-Path (Join-Path $bin 'deno.exe'))) {
        Write-Log 'Preparando Deno para sitios que necesitan JavaScript...'
        $archive=Join-Path $RunFolder 'deno.zip'
        Fetch 'https://github.com/denoland/deno/releases/latest/download/deno-x86_64-pc-windows-msvc.zip' $archive
        Expand-Archive -LiteralPath $archive -DestinationPath (Join-Path $RunFolder 'deno') -Force
        Copy-Item -LiteralPath (Join-Path $RunFolder 'deno\deno.exe') -Destination (Join-Path $bin 'deno.exe') -Force
    }
    $videoUrl=Get-VideoUrl $request.url
    if($videoUrl -ne $request.url) {Write-Log 'Preparando el enlace directo del reproductor.'}
    $null=New-Item -ItemType Directory -Force -Path $request.folder
    $arguments=@('--ignore-config','--no-playlist','--newline','--no-colors','--windows-filenames','--trim-filenames','160','--no-overwrites','--ffmpeg-location',$bin,'--js-runtimes',('deno:'+(Join-Path $bin 'deno.exe')),'-P',$request.folder,'-o','%(title)s [%(id)s].%(ext)s')
    $arguments+=@('--socket-timeout','15','--extractor-retries','2','--retries','3','--concurrent-fragments','4','--progress-delta','0.5','--cache-dir',(Join-Path $PSScriptRoot 'cache'))
    $arguments+=@(Get-FormatOptions ([int]$request.quality))
    if(([Uri]$videoUrl).DnsSafeHost -eq 'player.vimeo.com') {
        $arguments+=@('--referer',$request.url,'--extractor-args','vimeo:original_format_policy=never')
        Write-Log 'Usando el reproductor de Vimeo con el acceso incluido en el enlace.'
    }
    $manifest=Join-Path $RunFolder 'downloaded-files.jsonl'
    $arguments+=@('--print-to-file','after_move:%(filepath)j',$manifest)
    $arguments+=@('--',$videoUrl)
    Write-Log 'Conectando con el sitio...'
    $ErrorActionPreference='Continue'
    # Keep the log open while downloading instead of reopening it for each line.
    $writer=New-Object IO.StreamWriter($log,$true,(New-Object Text.UTF8Encoding($false)))
    $writer.AutoFlush=$true
    try {
        $runArguments=$arguments
        for($attempt=0; $attempt -lt 2; $attempt++) {
            $attemptLog=New-Object Text.StringBuilder
            & (Join-Path $bin 'yt-dlp.exe') @runArguments 2>&1 | ForEach-Object {
                $writer.WriteLine([string]$_)
                $null=$attemptLog.AppendLine([string]$_)
            }
            $code=$LASTEXITCODE
            $details=$attemptLog.ToString()
            if($code -eq 0) {break}
            if($attempt -eq 0 -and $details -match '(?i)could not resolve host|failed to resolve|name or service not known|getaddrinfo failed|temporary failure in name resolution') {
                $writer.WriteLine('Problema de conexion al sitio. Reintentando una vez con IPv4...')
                $runArguments=@('--force-ipv4')+$arguments
            } else {break}
        }
    } finally {$writer.Dispose()}
    $ErrorActionPreference='Stop'
    if($code -ne 0) {
        if($details -match '(?i)could not resolve host|failed to resolve|name or service not known|getaddrinfo failed|temporary failure in name resolution') {throw 'No se pudo localizar el sitio (DNS). Comprueba que el enlace abre en tu navegador y vuelve a intentar.'}
        if($details -match 'Requested format is not available') {throw 'No hay un formato para la calidad elegida. Prueba Video MP4 compatible, sin limite de resolucion.'}
        if($details -match '(?i)login required|log in|sign in|cookies|private|not available for this account') {throw 'La red social exige iniciar sesion o permiso para ver este video. Esta version admite enlaces accesibles sin iniciar sesion.'}
        if($details -match '(?i)429|too many requests|rate.limit') {throw 'La red social limita temporalmente las descargas. Espera unos minutos y vuelve a intentar.'}
        if($details -match '(?i)403|forbidden') {throw 'La red social bloqueo el acceso al video. Prueba Actualizar motor; puede requerir iniciar sesion.'}
        throw 'No se pudo descargar. Revisa el detalle del sitio en el registro o prueba Actualizar motor.'
    }
    if(-not (Test-Path -LiteralPath $manifest)) {throw 'No se pudo confirmar el archivo guardado.'}
    $savedFiles=@(Get-Content -LiteralPath $manifest -Encoding UTF8 | Where-Object {$_} | ForEach-Object {ConvertFrom-Json $_})
    if($savedFiles.Count -eq 0) {throw 'No se encontro el archivo descargado.'}
    $finalFiles=@(foreach($savedFile in $savedFiles) {
        if([int]$request.quality -eq 4) {$savedFile} else {Save-CompatibleVideo $savedFile $bin}
    })
    foreach($finalFile in $finalFiles) {Write-Log ('Archivo final: '+$finalFile)}
    $message=if([int]$request.quality -eq 4) {'Listo. Audio MP3 guardado.'} else {'Listo. MP4 con video verificado y guardado.'}
    @{ok=$true;message=$message;files=$finalFiles} | ConvertTo-Json | Set-Content -LiteralPath $result -Encoding UTF8
} catch {
    Write-Log $_.Exception.Message
    @{ok=$false;message=$_.Exception.Message} | ConvertTo-Json | Set-Content -LiteralPath $result -Encoding UTF8
    exit 1
}
