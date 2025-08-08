Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName Microsoft.VisualBasic

# Ce script harmonisé remplace le comportement interactif de l'ancienne version.
# Il charge l'interface et les options depuis des fichiers YAML, puis propose
# à l'utilisateur de saisir/valider les paramètres de chaque script avant exécution.

function Write-Log {
    param([string]$msg, [string]$color = 'Black')
    $ts = (Get-Date -Format 'HH:mm:ss')
    $line = "[$ts] $msg"
    if ($script:txtLog -and -not $script:txtLog.IsDisposed) {
        $script:txtLog.SelectionStart  = $script:txtLog.TextLength
        $script:txtLog.SelectionColor = [System.Drawing.Color]::$color
        $script:txtLog.AppendText("$line`r`n")
        $script:txtLog.SelectionColor = $script:txtLog.ForeColor
        [System.Windows.Forms.Application]::DoEvents()
    } else {
        Write-Host $line
    }
}

function Load-YamlFile ($path) {
    if (-not (Get-Command ConvertFrom-Yaml -ErrorAction SilentlyContinue)) {
        throw "Le module powershell-yaml est requis. Installez-le avec : Install-Module -Name powershell-yaml -Scope CurrentUser"
    }
    if (-not (Test-Path $path)) {
        throw "Fichier YAML manquant: $path"
    }
    Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Yaml
}

class MenuItem {
    [string]$label
    [string]$ScriptName
    [hashtable]$params
    MenuItem([string]$label, [string]$ScriptName, [hashtable]$params) {
        $this.label      = $label
        $this.ScriptName = $ScriptName
        $this.params     = $params
    }
    [string] ToString() { return $this.label }
}

# Demande à l'utilisateur de confirmer ou modifier les paramètres avant l'exécution.
function Prompt-ForParams {
    param([hashtable]$Params)
    $newParams = @{}
    foreach ($key in $Params.Keys) {
        $defaultValue = $Params[$key]
        $prompt = "Valeur pour '$key' (actuelle : $defaultValue) :"
        $title  = "Paramètre : $key"
        $value = [Microsoft.VisualBasic.Interaction]::InputBox($prompt, $title, [string]$defaultValue)
        if ($value) {
            $newParams[$key] = $value
        } else {
            $newParams[$key] = $defaultValue
        }
    }
    return $newParams
}

# Récupère les chemins relatifs au script
$scriptDir           = Split-Path -Parent $MyInvocation.MyCommand.Definition
$configDir           = Join-Path $scriptDir 'Config'
$optionsDir          = Join-Path $scriptDir 'Options'
$configMenuFile      = Join-Path $configDir 'config_menu.yaml'
$configInterfaceFile = Join-Path $configDir 'config_interface.yaml'

# Chargement des configurations YAML
$configMenu      = Load-YamlFile $configMenuFile
$configInterface = Load-YamlFile $configInterfaceFile
$UI          = $configInterface.Interface
$ModeChooser = $configInterface.ModeChooser
$MenuOptions = $configMenu.MenuOptions

# Charge dynamiquement tous les scripts .ps1 du dossier Options
Get-ChildItem -Path $optionsDir -Filter *.ps1 | ForEach-Object {
    Write-Log "Chargement: $($_.Name)" 'DarkGreen'
    . $_.FullName
}

# Fenêtre permettant de choisir entre le mode Démo et Prod
function Choose-Mode {
    $cfg  = $ModeChooser
    $form = New-Object System.Windows.Forms.Form
    $form.Text = $cfg.Title
    $form.Size = New-Object System.Drawing.Size($cfg.Size.Width, $cfg.Size.Height)
    $form.StartPosition = 'CenterScreen'

    $btnDemo = New-Object System.Windows.Forms.Button
    $btnDemo.Text = $cfg.Buttons.Demo.Text
    $btnDemo.Size = New-Object System.Drawing.Size($cfg.Buttons.Demo.Size.Width, $cfg.Buttons.Demo.Size.Height)
    $btnDemo.Location = New-Object System.Drawing.Point($cfg.Buttons.Demo.Location.X, $cfg.Buttons.Demo.Location.Y)
    $btnDemo.Add_Click({ $form.Tag = $true; $form.Close() }) | Out-Null
    $form.Controls.Add($btnDemo) | Out-Null

    $btnProd = New-Object System.Windows.Forms.Button
    $btnProd.Text = $cfg.Buttons.Prod.Text
    $btnProd.Size = New-Object System.Drawing.Size($cfg.Buttons.Prod.Size.Width, $cfg.Buttons.Prod.Size.Height)
    $btnProd.Location = New-Object System.Drawing.Point($cfg.Buttons.Prod.Location.X, $cfg.Buttons.Prod.Location.Y)
    $btnProd.Add_Click({ $form.Tag = $false; $form.Close() }) | Out-Null
    $form.Controls.Add($btnProd) | Out-Null

    $form.KeyPreview = $true
    $form.Add_KeyDown({
        if ($_.KeyCode -eq 'Escape') { $form.Tag = $false; $form.Close() }
    }) | Out-Null

    [void]$form.ShowDialog()
    $form.Dispose()
    return [bool]$form.Tag
}

# Choix du mode à l'ouverture
$DemoMode = Choose-Mode
Write-Log "Mode choisi : $(if ($DemoMode) {'Démo'})$(if (-not $DemoMode) {'Prod'})" 'Blue'

# Construit le formulaire principal selon la configuration
function Build-Form {
    param($UI, $MenuOptions, $DemoMode)
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "{0} {1}" -f $UI.Title, $(if ($DemoMode) {'(Démo)'} else {''})
    $form.Size = New-Object System.Drawing.Size($UI.Size.Width, $UI.Size.Height)
    $form.StartPosition = $UI.StartPosition

    # Liste des options
    $lb = New-Object System.Windows.Forms.ListBox
    $lb.Location = New-Object System.Drawing.Point($UI.ListBox.Location.X, $UI.ListBox.Location.Y)
    $lb.Size     = New-Object System.Drawing.Size($UI.ListBox.Size.Width, $UI.ListBox.Size.Height)
    $form.Controls.Add($lb) | Out-Null
    $script:lb = $lb

    foreach ($opt in $MenuOptions) {
        if (-not $opt.function) { continue }
        if ($DemoMode -and -not $opt.SupportsDemo) { continue }
        $item = [MenuItem]::new($opt.label, $opt.function, $opt.params)
        $lb.Items.Add($item) | Out-Null
    }

    if ($lb.Items.Count -gt 0) { $lb.SelectedIndex = 0 }

    # Bouton Exécuter
    $btnRun = New-Object System.Windows.Forms.Button
    $btnRun.Text     = $UI.Buttons.Run.Text
    $btnRun.Location = New-Object System.Drawing.Point($UI.Buttons.Run.Location.X, $UI.Buttons.Run.Location.Y)
    $btnRun.Size     = New-Object System.Drawing.Size($UI.Buttons.Run.Size.Width, $UI.Buttons.Run.Size.Height)
    $form.Controls.Add($btnRun) | Out-Null

    # Zone de log
    $txtLog = New-Object System.Windows.Forms.RichTextBox
    $txtLog.Multiline  = $true
    $txtLog.ReadOnly   = $true
    $txtLog.ScrollBars = 'Vertical'
    $txtLog.Location   = New-Object System.Drawing.Point($UI.LogTextBox.Location.X, $UI.LogTextBox.Location.Y)
    $txtLog.Size       = New-Object System.Drawing.Size($UI.LogTextBox.Size.Width, $UI.LogTextBox.Size.Height)
    $form.Controls.Add($txtLog) | Out-Null
    $script:txtLog = $txtLog

    # Barre de progression
    $pb = New-Object System.Windows.Forms.ProgressBar
    $pb.Location = New-Object System.Drawing.Point($UI.ProgressBar.Location.X, $UI.ProgressBar.Location.Y)
    $pb.Size     = New-Object System.Drawing.Size($UI.ProgressBar.Size.Width, $UI.ProgressBar.Size.Height)
    $pb.Minimum  = $UI.ProgressBar.Minimum
    $pb.Maximum  = $UI.ProgressBar.Maximum
    $form.Controls.Add($pb) | Out-Null
    $script:pb = $pb

    # Gestion des raccourcis clavier
    $form.KeyPreview = $true
    $form.Add_KeyDown({
        if ($_.KeyCode -eq 'Escape') { $form.Close() }
        if ($_.KeyCode -eq 'Enter')  { $btnRun.PerformClick() }
    }) | Out-Null

    # Action lors du clic sur "Exécuter"
    $btnRun.Add_Click({
        if ($script:lb.Items.Count -eq 0) {
            Write-Log "La liste des options est vide" 'Red'
            return
        }
        if ($script:lb.SelectedIndex -lt 0) {
            Write-Log "Aucune option sélectionnée" 'Red'
            return
        }

        $item = $script:lb.Items[$script:lb.SelectedIndex]
        Write-Log "Sélection : $($item.label)" 'DarkCyan'

        if (-not $item.ScriptName -or [string]::IsNullOrWhiteSpace($item.ScriptName)) {
            Write-Log "Erreur : nom de script invalide" 'Red'
            return
        }

        # Préparation des paramètres
        $splat = @{}
        $splat['DemoMode'] = $DemoMode

        # Copie et saisie des paramètres définis dans le YAML
        $paramsFromYaml = @{}
        if ($item.params -and $item.params.Keys.Count -gt 0) {
            foreach ($k in $item.params.Keys) {
                $paramsFromYaml[$k] = $item.params[$k]
            }
            if (-not $DemoMode) {
                $paramsFromYaml = Prompt-ForParams -Params $paramsFromYaml
            }
            foreach ($k in $paramsFromYaml.Keys) {
                $splat[$k] = $paramsFromYaml[$k]
            }
        }

        # Ajoute la barre de progression pour les scripts qui l'acceptent
        $splat['ProgressBar'] = $script:pb

        # Réinitialise et lance le script
        $script:pb.Value = 0
        if (Get-Command $item.ScriptName -ErrorAction SilentlyContinue) {
            Write-Log "Exécution : $($item.ScriptName)" 'DarkGreen'
            & $item.ScriptName @splat
            $script:pb.Value = $script:pb.Maximum
            Write-Log "Terminé : $($item.ScriptName)" 'Green'
        } else {
            Write-Log "Erreur : fonction '$($item.ScriptName)' non trouvée." 'Red'
        }
    }) | Out-Null

    return $form
}

$mainForm = Build-Form -UI $UI -MenuOptions $MenuOptions -DemoMode $DemoMode
if ($mainForm -is [System.Windows.Forms.Form]) {
    [void]$mainForm.ShowDialog()
    $mainForm.Dispose()
} else {
    Write-Error "La fonction Build-Form n'a pas retourné un objet Form valide."
}
