function Get-MediaStreams([string]$Path,[string]$BinFolder) {
    $probeOutput=& (Join-Path $BinFolder 'ffprobe.exe') -v error -show_entries stream=codec_type,codec_name -of json $Path
    if($LASTEXITCODE -ne 0) {throw 'No se pudo verificar el archivo descargado.'}
    return @((($probeOutput -join "`n") | ConvertFrom-Json).streams)
}
function Save-CompatibleVideo([string]$Path,[string]$BinFolder) {
    $streams=@(Get-MediaStreams $Path $BinFolder)
    $video=@($streams | Where-Object codec_type -eq 'video')
    $audio=@($streams | Where-Object codec_type -eq 'audio')
    if($video.Count -eq 0) {throw 'El archivo no contiene video. No se marcara como descarga de video completada.'}
    $compatibleVideo=$video[0].codec_name -eq 'h264'
    $compatibleAudio=$audio.Count -eq 0 -or $audio[0].codec_name -eq 'aac'
    if([IO.Path]::GetExtension($Path) -eq '.mp4' -and $compatibleVideo -and $compatibleAudio) {return $Path}
    Write-Log 'Convirtiendo a MP4 compatible (video H.264 y audio AAC)...'
    $target=[IO.Path]::ChangeExtension($Path,'.mp4')
    $base=Join-Path ([IO.Path]::GetDirectoryName($Path)) ([IO.Path]::GetFileNameWithoutExtension($Path))
    $number=1
    while(Test-Path -LiteralPath $target) {$target=$base+' [MP4 '+$number+'].mp4'; $number++}
    $staged=Join-Path ([IO.Path]::GetDirectoryName($Path)) ([Guid]::NewGuid().ToString('N')+'.convirtiendo.mp4')
    $convertArgs=@('-hide_banner','-nostdin','-n','-i',$Path,'-map','0:v:0','-map','0:a:0?','-sn','-dn')
    if($compatibleVideo) {$convertArgs+=@('-c:v','copy')} else {$convertArgs+=@('-c:v','libx264','-preset','veryfast','-crf','23','-pix_fmt','yuv420p','-vf','pad=ceil(iw/2)*2:ceil(ih/2)*2')}
    if($compatibleAudio) {$convertArgs+=@('-c:a','copy')} else {$convertArgs+=@('-c:a','aac','-b:a','192k')}
    $convertArgs+=@('-movflags','+faststart',$staged)
    $oldPreference=$ErrorActionPreference
    try {
        $ErrorActionPreference='Continue'
        & (Join-Path $BinFolder 'ffmpeg.exe') @convertArgs 2>&1 | ForEach-Object {Write-Log ([string]$_)}
        $conversionCode=$LASTEXITCODE
        $ErrorActionPreference='Stop'
        if($conversionCode -ne 0) {throw 'No se pudo convertir a MP4. Se conserva el archivo original.'}
        $verified=@(Get-MediaStreams $staged $BinFolder)
        if(-not ($verified | Where-Object { $_.codec_type -eq 'video' -and $_.codec_name -eq 'h264' })) {throw 'El MP4 no paso la verificacion de video.'}
        if($audio.Count -gt 0 -and -not ($verified | Where-Object { $_.codec_type -eq 'audio' -and $_.codec_name -eq 'aac' })) {throw 'El MP4 no paso la verificacion de audio.'}
        Move-Item -LiteralPath $staged -Destination $target
        return $target
    } finally {$ErrorActionPreference=$oldPreference}
}

function Get-FormatOptions([int]$Quality) {
    if($Quality -eq 4) {return @('-f','ba/b','-x','--audio-format','mp3')}
    $limit=switch($Quality) {0 {''} 1 {'[height<=?1080]'} 2 {'[height<=?720]'} 3 {'[height<=?480]'} default {throw 'Calidad no valida.'}}
    # Social extractors may omit codec or height metadata. Prefer compatible
    # codecs by sorting, never reject a video just because its codec is unknown.
    # bv* accepts combined video/audio and silent video as well as video-only.
    $format='bv*'+$limit+'+ba/b'+$limit+'/bv*'+$limit
    return @('-f',$format,'-S','vcodec:h264,acodec:aac','--merge-output-format','mp4/mkv')
}
