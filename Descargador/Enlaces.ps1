function Get-VideoUrl([string]$Value) {
    $parsed=$null
    if(-not [Uri]::TryCreate($Value.Trim(),[UriKind]::Absolute,[ref]$parsed) -or $parsed.Scheme -notin @('http','https')) {throw 'Enlace no valido.'}
    $videoId=$null
    $site=$parsed.DnsSafeHost.ToLowerInvariant()
    if($site -in @('vimeo.com','www.vimeo.com') -and $parsed.AbsolutePath -match '^/(\d+)(?:/([a-fA-F0-9]{10}))?/?$') {
        $vimeoId=$Matches[1]
        $accessHash=$Matches[2]
        $remaining=@()
        foreach($part in $parsed.Query.TrimStart('?').Split('&')) {
            if(-not $part) {continue}
            $pair=$part.Split('=',2)
            $key=[Uri]::UnescapeDataString($pair[0])
            if($key -eq 'h') {if(-not $accessHash -and $pair.Count -gt 1) {$accessHash=[Uri]::UnescapeDataString($pair[1])}; continue}
            if($key -notin @('share','fl','fe')) {$remaining+=$part}
        }
        $player='https://player.vimeo.com/video/'+$vimeoId
        $query=@()
        if($accessHash) {$query+='h='+[Uri]::EscapeDataString($accessHash)}
        $query+=$remaining
        if($query.Count -gt 0) {$player+='?'+($query -join '&')}
        return $player
    }
    if($site -in @('youtube.com','www.youtube.com','m.youtube.com','music.youtube.com','youtube-nocookie.com','www.youtube-nocookie.com')) {
        if($parsed.AbsolutePath -eq '/watch' -and $parsed.Query -match '(?:\?|&)v=([^&]+)') {
            $videoId=[Uri]::UnescapeDataString($Matches[1])
        } elseif($parsed.AbsolutePath -match '^/(?:shorts|live|embed)/([^/]+)/?$') {$videoId=$Matches[1]}
    } elseif($site -in @('youtu.be','www.youtu.be')) {$videoId=$parsed.AbsolutePath.Trim('/')}
    if($videoId -cmatch '^[A-Za-z0-9_-]{11}$') {return 'https://www.youtube.com/watch?v='+$videoId}
    # Preserve signed URLs and query parameters on every other site.
    return $Value.Trim()
}
