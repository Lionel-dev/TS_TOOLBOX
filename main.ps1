Add-Type -AssemblyName System.Windows.Forms

# --- Charger ConvertFrom-Yaml si besoin ---
if (-not (Get-Command ConvertFrom-Yaml -ErrorAction SilentlyContinue)) {
    try {
        Install-Module -Name powershell-yaml -Force -Scope CurrentUser -SkipPublisherCheck
        Import-Module powershell-yaml
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show(
            "Le module 'powershell-yaml' est introuvable. Installez-le via : Install-Module -Name powershell-yaml",
            "Module YAML manquant",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
        exit
    }
}

# --- Chemins ---
$scriptDir            = Split-Path -Parent $MyInvocation.MyCommand.Definition
$configDir            = Join-Path $scriptDir 'Config'
$configMenuFile       = Join-Path $configDir 'config_menu.yaml'
$configInterfaceFile  = Join-Path $configDir 'config_interface.yaml'
$optionsDir           = Join-Path $scriptDir 'Options'
$logDir               = Join-Path $scriptDir 'Logs'
if (-not (Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory | Out-Null }

# --- Fichier de log quotidien ---
$user    = $env:USERNAME
$date    = (Get-Date).ToString('yyyy-MM-dd')
$logFile = Join-Path $logDir "$user`_$date.txt"

# --- Charger les configurations YAML ---
$configMenu      = Get-Content $configMenuFile      -Raw -Encoding UTF8 | ConvertFrom-Yaml
$configInterface = Get-Content $configInterfaceFile -Raw -Encoding UTF8 | ConvertFrom-Yaml

$MenuOptions = $configMenu.MenuOptions
$UI          = $configInterface.Interface

# --- Importer les scripts d'options ---
Get-ChildItem $optionsDir -Filter '*.ps1' | ForEach-Object { . $_.FullName }

# --- Construire l'interface ---
$form = New-Object System.Windows.Forms.Form
$form.Text          = $UI.Title
$form.Size          = New-Object System.Drawing.Size($UI.Size.Width, $UI.Size.Height)
$form.StartPosition = $UI.StartPosition

# ListBox
$listBox = New-Object System.Windows.Forms.ListBox
$listBox.Location   = New-Object System.Drawing.Point($UI.ListBox.Location.X, $UI.ListBox.Location.Y)
$listBox.Size       = New-Object System.Drawing.Size($UI.ListBox.Size.Width,     $UI.ListBox.Size.Height)
$listBox.DataSource = $MenuOptions.label
$form.Controls.Add($listBox)

# TextBox de logs
$txtLog = New-Object System.Windows.Forms.TextBox
$txtLog.Multiline   = $true
$txtLog.ReadOnly    = $true
$txtLog.ScrollBars  = 'Vertical'
$txtLog.Location    = New-Object System.Drawing.Point($UI.LogTextBox.Location.X, $UI.LogTextBox.Location.Y)
$txtLog.Size        = New-Object System.Drawing.Size($UI.LogTextBox.Size.Width,     $UI.LogTextBox.Size.Height)
$form.Controls.Add($txtLog)

# ProgressBar
$pb = New-Object System.Windows.Forms.ProgressBar
$pb.Location  = New-Object System.Drawing.Point($UI.ProgressBar.Location.X, $UI.ProgressBar.Location.Y)
$pb.Size      = New-Object System.Drawing.Size($UI.ProgressBar.Size.Width,     $UI.ProgressBar.Size.Height)
$pb.Minimum   = $UI.ProgressBar.Minimum
$pb.Maximum   = $UI.ProgressBar.Maximum
$form.Controls.Add($pb)

# Fonction de log partagée
function Write-Log {
    param([string]$message)
    $time  = (Get-Date).ToString('HH:mm:ss')
    $entry = "[$time] $message"
    $txtLog.AppendText($entry + "`r`n")
    Add-Content -Path $logFile -Value $entry
    [System.Windows.Forms.Application]::DoEvents()
}

# Bouton Exécuter
$btnRun = New-Object System.Windows.Forms.Button
$btnRun.Text     = $UI.Buttons.Run.Text
$btnRun.Size     = New-Object System.Drawing.Size($UI.Buttons.Run.Size.Width,  $UI.Buttons.Run.Size.Height)
$btnRun.Location = New-Object System.Drawing.Point($UI.Buttons.Run.Location.X, $UI.Buttons.Run.Location.Y)
$btnRun.Add_Click({
    $idx = $listBox.SelectedIndex
    if ($idx -lt 0) { Write-Log 'Erreur : aucune option sélectionnée'; return }
    $opt = $MenuOptions[$idx]

    Write-Log "Lancement : $($opt.function)"
    $pb.Value = 0

    # Préparer splatting
    $splat = @{}
    foreach ($k in $opt.params.Keys) { $splat[$k] = $opt.params[$k] }

    switch ($opt.function) {
        'Clear-DiskSpace' {
            $pb.Maximum = 4
            & $opt.function
        }
        'Compress-Images' {
            $dlg = [System.Windows.Forms.FolderBrowserDialog]::new()
            if ($dlg.ShowDialog() -eq 'OK') {
                $splat['FolderPath'] = $dlg.SelectedPath
                & $opt.function @splat
            }
        }
        default {
            & $opt.function @splat
        }
    }

    Write-Log "Terminé : $($opt.function)"
})
$form.Controls.Add($btnRun)

# Bouton Quitter
$btnExit = New-Object System.Windows.Forms.Button
$btnExit.Text     = $UI.Buttons.Exit.Text
$btnExit.Size     = New-Object System.Drawing.Size($UI.Buttons.Exit.Size.Width,  $UI.Buttons.Exit.Size.Height)
$btnExit.Location = New-Object System.Drawing.Point($UI.Buttons.Exit.Location.X, $UI.Buttons.Exit.Location.Y)
$btnExit.Add_Click({ $form.Close() })
$form.Controls.Add($btnExit)

# --- Affichage de la GUI ---
[void]$form.ShowDialog()
