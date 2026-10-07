# Rebuild the original geometric application logo and Windows icon.
Add-Type -AssemblyName System.Drawing
function New-LogoBitmap([int]$Size) {
    $bitmap=New-Object Drawing.Bitmap($Size,$Size)
    $g=[Drawing.Graphics]::FromImage($bitmap)
    $g.SmoothingMode='AntiAlias'
    $g.Clear([Drawing.Color]::Transparent)
    $g.ScaleTransform(($Size/256.0),($Size/256.0))
    $shape=New-Object Drawing.Drawing2D.GraphicsPath
    $shape.AddArc(8,8,72,72,180,90); $shape.AddArc(176,8,72,72,270,90)
    $shape.AddArc(176,176,72,72,0,90); $shape.AddArc(8,176,72,72,90,90); $shape.CloseFigure()
    $rect=New-Object Drawing.Rectangle(0,0,256,256)
    $fill=New-Object Drawing.Drawing2D.LinearGradientBrush($rect,[Drawing.Color]::FromArgb(42,112,235),[Drawing.Color]::FromArgb(26,54,148),45.0)
    $g.FillPath($fill,$shape)
    $play=[Drawing.PointF[]]@((New-Object Drawing.PointF(97,49)),(New-Object Drawing.PointF(97,126)),(New-Object Drawing.PointF(164,87)))
    $g.FillPolygon([Drawing.Brushes]::White,$play)
    $pen=New-Object Drawing.Pen([Drawing.Color]::FromArgb(123,230,255),14)
    $pen.StartCap='Round'; $pen.EndCap='Round'; $pen.LineJoin='Round'
    $g.DrawLine($pen,128,141,128,188)
    $g.DrawLines($pen,[Drawing.PointF[]]@((New-Object Drawing.PointF(108,171)),(New-Object Drawing.PointF(128,191)),(New-Object Drawing.PointF(148,171))))
    $g.DrawLines($pen,[Drawing.PointF[]]@((New-Object Drawing.PointF(76,188)),(New-Object Drawing.PointF(76,213)),(New-Object Drawing.PointF(180,213)),(New-Object Drawing.PointF(180,188))))
    $pen.Dispose(); $fill.Dispose(); $shape.Dispose(); $g.Dispose()
    return $bitmap
}
$image=New-LogoBitmap 256
$image.Save((Join-Path $PSScriptRoot 'Logo.png'),[Drawing.Imaging.ImageFormat]::Png)
$image.Dispose()
$small=New-LogoBitmap 64
$icon=[Drawing.Icon]::FromHandle($small.GetHicon())
$stream=[IO.File]::Create((Join-Path $PSScriptRoot 'Logo.ico'))
try {$icon.Save($stream)} finally {$stream.Dispose(); $icon.Dispose(); $small.Dispose()}
