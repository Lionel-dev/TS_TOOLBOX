# Chargement des assemblies nécessaires pour manipuler les images et l’interface WinForms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

function Compress-Image {
    
    <#
    .SYNOPSIS
        Compresse les images JPEG et PNG d’un dossier.
    .DESCRIPTION
        Cette version harmonisée accepte un mode démo (aucune suppression/modification réelle),
        un dossier en entrée, un taux de qualité, une date limite pour filtrer les fichiers,
        ainsi qu’une barre de progression WinForms optionnelle. Elle supporte aussi
        -WhatIf/-Confirm via SupportsShouldProcess.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [switch]$DemoMode,
        [string]$InputFolder = (Get-Location),
        [ValidateRange(1,100)][int]$Quality = 80,
        [datetime]$DateLimit = (Get-Date),
        [System.Windows.Forms.ProgressBar]$ProgressBar
    )

    # Mode démonstration : on appelle simplement Run-DemoMode puis on quitte
    if ($DemoMode) {
        Run-DemoMode
        return
    }

    # Vérifie l’existence du dossier cible
    if (-not (Test-Path $InputFolder)) {
        throw "Le dossier spécifié '$InputFolder' n'existe pas."
    }

    Write-Log "Compression des images dans '$InputFolder' avec qualité $Quality % avant le $DateLimit" 'DarkGreen'

    # Récupération des fichiers à compresser
    $files = Get-ChildItem -Path $InputFolder -Include *.jpg,*.jpeg,*.png -Recurse |
             Where-Object { $_.LastWriteTime -lt $DateLimit }

    $total = $files.Count
    $index = 0

    foreach ($file in $files) {
        $index++
        # Mise à jour de la barre de progression si nécessaire
        if ($ProgressBar) {
            $ProgressBar.Value = [Math]::Min([Math]::Floor($index * 100 / $total), $ProgressBar.Maximum)
        }

        $inputPath = $file.FullName
        $tempPath  = Join-Path $file.DirectoryName "$($file.BaseName).temp$($file.Extension)"

        try {
            # Chargement de l’image et création d’un bitmap modifiable
            $image    = [System.Drawing.Image]::FromFile($inputPath)
            $bitmap   = New-Object System.Drawing.Bitmap $image.Width, $image.Height
            $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
            $graphics.DrawImage($image, 0, 0, $image.Width, $image.Height)
            $image.Dispose()
            $graphics.Dispose()

            # Choix du type de compression selon l’extension
            $ext = $file.Extension.ToLowerInvariant()
            if ($ext -in @('.jpg','.jpeg')) {
                Compress-Jpeg -bitmap $bitmap -tempPath $tempPath -quality $Quality
            } else {
                Compress-Png  -bitmap $bitmap -tempPath $tempPath
            }
            $bitmap.Dispose()

            # Suppression de l’original et renommage du fichier compressé si l’utilisateur confirme
            if ($PSCmdlet.ShouldProcess($inputPath, 'Compression')) {
                Remove-Item $inputPath -Force
                Rename-Item -Path $tempPath -NewName $file.Name
            } else {
                Remove-Item -Path $tempPath -Force
            }
        } catch {
            Write-Log "Erreur pendant le traitement de '$inputPath' : $_" 'Red'
            if (Test-Path $tempPath) { Remove-Item $tempPath -Force }
        }
    }

    if ($ProgressBar) { $ProgressBar.Value = $ProgressBar.Maximum }
    Write-Log "Compression terminée." 'Green'
}

function Compress-Jpeg {
    param(
        [System.Drawing.Bitmap]$bitmap,
        [string]$tempPath,
        [int]$quality
    )
    try {
        $encoderParams = New-Object System.Drawing.Imaging.EncoderParameters(1)
        $encoderParam  = New-Object System.Drawing.Imaging.EncoderParameter(
            [System.Drawing.Imaging.Encoder]::Quality, $quality
        )
        $encoderParams.Param[0] = $encoderParam
        $jpegCodec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageDecoders() |
                     Where-Object { $_.FormatID -eq [System.Drawing.Imaging.ImageFormat]::Jpeg.Guid }
        $bitmap.Save($tempPath, $jpegCodec, $encoderParams)
    } catch {
        Write-Log "Erreur JPEG : $_" 'Red'
    }
}

function Compress-Png {
    param(
        [System.Drawing.Bitmap]$bitmap,
        [string]$tempPath
    )
    try {
        $bitmap.Save($tempPath, [System.Drawing.Imaging.ImageFormat]::Png)
    } catch {
        Write-Log "Erreur PNG : $_" 'Red'
    }
}

function Run-DemoMode {
    <#
    Crée trois images de démonstration dans un dossier temporaire,
    puis lance la compression dessus.
    #>
    $demoDir = Join-Path ([System.IO.Path]::GetTempPath()) "DemoCompression_$([Guid]::NewGuid())"
    New-Item -Path $demoDir -ItemType Directory -Force | Out-Null

    $colors = @('Red','Green','Blue')
    foreach ($color in $colors) {
        $bmp      = New-Object System.Drawing.Bitmap 800, 600
        $graphics = [System.Drawing.Graphics]::FromImage($bmp)
        $graphics.Clear([System.Drawing.Color]::$color)
        $path = Join-Path $demoDir "$color-demo.png"
        $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
        $graphics.Dispose()
        $bmp.Dispose()
    }

    Write-Log "Mode démo : compression de 3 images générées dans '$demoDir'" 'DarkGray'
    Compress-Image -InputFolder $demoDir -Quality 75 -DateLimit (Get-Date)
    Write-Log "Mode démo terminé. Les images générées se trouvent dans '$demoDir'." 'DarkGray'
}
