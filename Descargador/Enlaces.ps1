function Get-VideoUrl([string]$Value) {
    $parsed=$null
    if(-not [Uri]::TryCreate($Value.Trim(),[UriKind]::Absolute,[ref]$parsed) -or $parsed.Scheme -notin @('http','https')) {throw 'Enlace no valido.'}
    $videoId=$null
    $site=$parsed.DnsSafeHost.ToLowerInvariant()
    if($site -in @('youtube.com','www.youtube.com','m.youtube.com','music.youtube.com','youtube-nocookie.com','www.youtube-nocookie.com')) {
        if($parsed.AbsolutePath -eq '/watch' -and $parsed.Query -match '(?:\?|&)v=([^&]+)') {
            $videoId=[Uri]::UnescapeDataString($Matches[1])
        } elseif($parsed.AbsolutePath -match '^/(?:shorts|live|embed)/([^/]+)/?$') {$videoId=$Matches[1]}
    } elseif($site -in @('youtu.be','www.youtu.be')) {$videoId=$parsed.AbsolutePath.Trim('/')}
    if($videoId -cmatch '^[A-Za-z0-9_-]{11}$') {return 'https://www.youtube.com/watch?v='+$videoId}
    # Preserve signed URLs and query parameters on every other site.
    return $Value.Trim()
}
