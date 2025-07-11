Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName Microsoft.VisualBasic

function Compress-Image {
    [CmdletBinding()]
    param (
        [switch]$demo,
        [string]$inputFolder,
        [int]$quality,
        [datetime]$dateLimit
    )

    if ($demo) {
        Run-DemoMode
        return
    }

    # En prod → proposer de valider/modifier les paramètres
    $inputFolder = Ask-IfNeeded -name 'inputFolder' -value $inputFolder
    $quality     = Ask-IfNeeded -name 'quality' -value $quality
    $dateLimit   = Ask-IfNeeded -name 'dateLimit' -value $dateLimit

    Write-Log "Compression des images dans : $inputFolder avec qualité $quality% avant $dateLimit" 'DarkGreen'
    Compress-Image-Internal -inputFolder $inputFolder -quality $quality -dateLimit $dateLimit
}

function Ask-IfNeeded {
    param(
        [string]$name,
        [string]$value
    )
    $val = [Microsoft.VisualBasic.Interaction]::InputBox(
        "Valeur pour '$name' (actuelle : $value) :", 
        "Paramètre : $name", 
        $value
    )
    if ($val) { return $val } else { return $value }
}

function Compress-Image-Internal {
    param (
        [string]$inputFolder,
        [int]$quality,
        [datetime]$dateLimit
    )

    $totalSizeBefore = 0
    $totalSizeAfter = 0

    Get-ChildItem -Path $inputFolder -Include *.jpg, *.jpeg, *.png -Recurse |
    Where-Object { $_.LastWriteTime -lt $dateLimit } | ForEach-Object {

        $inputPath = $_.FullName
        $tempPath = [System.IO.Path]::Combine($_.DirectoryName, "$($_.BaseName).temp$($_.Extension)")

        try {
            $originalSize = (Get-Item $inputPath).Length
            $totalSizeBefore += $originalSize

            $image = [System.Drawing.Image]::FromFile($inputPath)
            $bitmap = New-Object System.Drawing.Bitmap $image.Width, $image.Height
            $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
            $graphics.DrawImage($image, 0, 0, $image.Width, $image.Height)
            $image.Dispose()
            $graphics.Dispose()

            $ext = $_.Extension.ToLowerInvariant()
            if ($ext -eq '.jpg' -or $ext -eq '.jpeg') {
                Compress-Jpeg -bitmap $bitmap -tempPath $tempPath -quality $quality
            } else {
                Compress-Png -bitmap $bitmap -tempPath $tempPath
            }

            $bitmap.Dispose()

            Remove-Item $inputPath -Force
            Rename-Item -Path $tempPath -NewName $_.Name

            $compressedSize = (Get-Item $inputPath).Length
            $totalSizeAfter += $compressedSize

        } catch {
            Write-Log "Erreur traitement : $_" 'Red'
        }
    }

    $totalGain = [math]::Round(($totalSizeBefore - $totalSizeAfter) /1MB, 2)
    Write-Log "Compression terminée. Gain total : $totalGain MB" 'Green'
}

function Compress-Jpeg {
    param (
        [System.Drawing.Bitmap]$bitmap,
        [string]$tempPath,
        [int]$quality
    )
    try {
        $encoderParams = New-Object System.Drawing.Imaging.EncoderParameters(1)
        $encoderParam = New-Object System.Drawing.Imaging.EncoderParameter(
            [System.Drawing.Imaging.Encoder]::Quality, $quality
        )
        $encoderParams.Param[0] = $encoderParam
        $jpegCodec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageDecoders() |
                     Where-Object { $_.FormatID -eq [System.Drawing.Imaging.ImageFormat]::Jpeg.Guid }

        $bitmap.Save($tempPath, $jpegCodec, $encoderParams)
    } catch {
        Write-Log "Erreur JPEG : $_" 'Red'
    }
}

function Compress-Png {
    param (
        [System.Drawing.Bitmap]$bitmap,
        [string]$tempPath
    )
    try {
        $bitmap.Save($tempPath, [System.Drawing.Imaging.ImageFormat]::Png)
    } catch {
        Write-Log "Erreur PNG : $_" 'Red'
    }
}

function Run-DemoMode {
    $MinDemoSizeMB = 0.5
    $desktop = [Environment]::GetFolderPath('Desktop')
    $demoFolder = Join-Path $desktop 'DemoCompression'

    if (Test-Path $demoFolder) {
        Write-Log "Mode démo : suppression de l'ancien répertoire…" 'DarkGray'
        Remove-Item -Path $demoFolder -Recurse -Force
    }

    Write-Log "Mode démo : création des dossiers…" 'DarkGray'
    $originalFolder = Join-Path $demoFolder 'Original'
    $compressedFolder = Join-Path $demoFolder 'Compressé'

    New-Item -Path $originalFolder -ItemType Directory -Force | Out-Null
    New-Item -Path $compressedFolder -ItemType Directory -Force | Out-Null

    Write-Log "Mode démo : recherche d'un échantillon d'images…" 'DarkGray'
    $samplePaths = @(
        "$env:USERPROFILE\Pictures",
        "$env:PUBLIC\Pictures",
        "C:\Users",
        "C:\",
        "D:\", 
        "E:\"
    )

    $images = @()
    foreach ($path in $samplePaths) {
        if (Test-Path $path) {
            $found = Get-ChildItem -Path $path -Include *.jpg,*.jpeg,*.png -Recurse -ErrorAction SilentlyContinue |
                     Where-Object { $_.Length -gt ($MinDemoSizeMB * 1MB) } |
                     Sort-Object -Property Length -Descending

            foreach ($img in $found) {
                if ($images.Count -lt 5) {
                    $images += $img
                } else {
                    break
                }
            }

            if ($images.Count -ge 5) { break }
        }
    }

    if ($images.Count -eq 0) {
        Write-Log "Aucune image >${MinDemoSizeMB}MB trouvée pour la démonstration." 'Red'
        return
    }

    if ($images.Count -lt 5) {
        Write-Log "Seulement $($images.Count) images trouvées pour la démonstration." 'Yellow'
    }

    foreach ($img in $images) {
        Copy-Item -Path $img.FullName -Destination $originalFolder
    }

    Write-Log "Images sélectionnées :"
    $images | ForEach-Object {
        Write-Log "  - $($_.Name) [$([math]::Round($_.Length/1MB,2)) MB]" 'DarkCyan'
    }

    Write-Log "Lancement de la compression démo…"
    $sizeBefore = (Get-ChildItem -Path $originalFolder -File | Measure-Object -Property Length -Sum).Sum

    Compress-Image-Internal -inputFolder $originalFolder -quality 80 -dateLimit (Get-Date)

    $sizeAfter = (Get-ChildItem -Path $originalFolder -File | Measure-Object -Property Length -Sum).Sum

    Get-ChildItem -Path $originalFolder -File | ForEach-Object {
        Copy-Item -Path $_.FullName -Destination $compressedFolder
    }

    $gainMB = [math]::Round(($sizeBefore - $sizeAfter)/1MB,2)

    Write-Log "=== MODE DEMO TERMINÉ ===" 'Green'
    Write-Log "Gain obtenu : $gainMB MB" 'Green'
    Write-Log "Résultats dans : $demoFolder" 'Green'
}
