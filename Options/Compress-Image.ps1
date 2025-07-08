function Compress-Image {
    param (
        [string]$inputFolder,
        [int]   $quality    = 80,
        [datetime]$dateLimit = [datetime]::MaxValue
    )

    # Si pas de dossier fourni, ouvrir un FolderBrowserDialog
    if (-not $inputFolder) {
        Add-Type -AssemblyName System.Windows.Forms
        $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
        $dlg.Description = "Sélectionnez le dossier contenant les images à compresser"
        if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $inputFolder = $dlg.SelectedPath
        }
        else {
            Write-Host "Aucun dossier sélectionné. Annulation." -ForegroundColor Yellow
            return
        }
    }

    if (-not (Test-Path $inputFolder -PathType Container)) {
        [System.Windows.Forms.MessageBox]::Show(
            "Le dossier spécifié est introuvable ou n'est pas un dossier : `n$inputFolder",
            "Erreur",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
        return
    }

    # Préparer les variables de suivi
    $totalBefore = 0
    $totalAfter  = 0

    # Fonctions internes de compression
    function Compress-Jpeg { … }
    function Compress-Png  { … }

    # Récupère toutes les images dans le dossier et sous-dossiers
    $images = Get-ChildItem -Path $inputFolder -Include *.jpg,*.jpeg,*.png -Recurse |
              Where-Object { $_.LastWriteTime -lt $dateLimit }

    foreach ($img in $images) {
        $origSize = $img.Length
        $totalBefore += $origSize
        $bitmap = [System.Drawing.Bitmap]::FromFile($img.FullName)

        $temp = [IO.Path]::ChangeExtension($img.FullName, ".temp$($img.Extension)")
        switch ($img.Extension.ToLower()) {
            '.jpg' { Compress-Jpeg -bitmap $bitmap -tempPath $temp -quality $quality }
            '.jpeg'{ Compress-Jpeg -bitmap $bitmap -tempPath $temp -quality $quality }
            '.png' { Compress-Png  -bitmap $bitmap -tempPath $temp }
        }
        $bitmap.Dispose()

        Remove-Item $img.FullName -ErrorAction SilentlyContinue
        Rename-Item -Path $temp -NewName $img.Name

        $newSize = (Get-Item $img.FullName).Length
        $totalAfter += $newSize

        $gain = [math]::Round(($origSize - $newSize)/1MB, 2)
        Write-Host "$($img.Name): Avant $([math]::Round($origSize/1MB,2)) MB → Après $([math]::Round($newSize/1MB,2)) MB (Gain $gain MB)"
    }

    $totalGain = [math]::Round(($totalBefore - $totalAfter)/1MB, 2)
    [System.Windows.Forms.MessageBox]::Show(
        "Compression terminée.`nGain total : $totalGain MB",
        "Résultat",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    )
}
