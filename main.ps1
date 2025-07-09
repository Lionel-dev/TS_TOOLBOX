Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName Microsoft.VisualBasic

if (-not (Get-Command ConvertFrom-Yaml -ErrorAction SilentlyContinue)) {
    Write-Error "Le module powershell-yaml est requis. Installez-le avec : Install-Module -Name powershell-yaml -Scope CurrentUser"
    exit 1
} else {
    Import-Module powershell-yaml
}

function Write-Log {
    param([string]$msg, [string]$color = 'Black')
    $ts = (Get-Date -Format 'HH:mm:ss')
    $line = "[$ts] $msg"
    if ($script:txtLog -and -not $script:txtLog.IsDisposed) {
        $script:txtLog.SelectionStart = $script:txtLog.TextLength
        $script:txtLog.SelectionColor = [System.Drawing.Color]::$color
        $script:txtLog.AppendText("$line`r`n")
        $script:txtLog.SelectionColor = $script:txtLog.ForeColor
        [System.Windows.Forms.Application]::DoEvents()
    } else {
        Write-Host $line
    }
}

function Load-YamlFile ($path) {
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

    [string] ToString() {
        return $this.label
    }
}

$scriptDir           = Split-Path -Parent $MyInvocation.MyCommand.Definition
$configDir           = Join-Path $scriptDir 'Config'
$optionsDir          = Join-Path $scriptDir 'Options'
$configMenuFile      = Join-Path $configDir 'config_menu.yaml'
$configInterfaceFile = Join-Path $configDir 'config_interface.yaml'

try {
    $configMenu      = Load-YamlFile $configMenuFile
    $configInterface = Load-YamlFile $configInterfaceFile
} catch {
    Write-Error $_.Exception.Message
    exit 1
}

$UI          = $configInterface.Interface
$ModeChooser = $configInterface.ModeChooser
$MenuOptions = $configMenu.MenuOptions

Get-ChildItem -Path $optionsDir -Filter *.ps1 | ForEach-Object {
    Write-Log "Chargement: $($_.Name)" 'DarkGreen'
    . $_.FullName
}

function Choose-Mode {
    $cfg = $ModeChooser

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

$DemoMode = Choose-Mode
Write-Log "Mode choisi : $(if ($DemoMode) {'Démo'})$(if (-not $DemoMode) {'Prod'})" 'Blue'

function Build-Form {
    param($UI, $MenuOptions, $DemoMode)

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "$($UI.Title) $(if ($DemoMode) {'(Démo)'})"
    $form.Size = New-Object System.Drawing.Size($UI.Size.Width, $UI.Size.Height)
    $form.StartPosition = $UI.StartPosition

    $lb = New-Object System.Windows.Forms.ListBox
    $lb.Location = New-Object System.Drawing.Point($UI.ListBox.Location.X, $UI.ListBox.Location.Y)
    $lb.Size = New-Object System.Drawing.Size($UI.ListBox.Size.Width, $UI.ListBox.Size.Height)
    $form.Controls.Add($lb) | Out-Null
    $script:lb = $lb

    foreach ($opt in $MenuOptions) {
        if (-not $opt.function) { continue }
        if ($DemoMode -and -not $opt.SupportsDemo) { continue }

        $item = [MenuItem]::new($opt.label, $opt.function, $opt.params)
        $lb.Items.Add($item) | Out-Null
    }

    Write-Log "DEBUG: Nombre d'éléments dans la ListBox = $($lb.Items.Count)" 'DarkGray'

    if ($lb.Items.Count -gt 0) { $lb.SelectedIndex = 0 }

    $btnRun = New-Object System.Windows.Forms.Button
    $btnRun.Text = $UI.Buttons.Run.Text
    $btnRun.Location = New-Object System.Drawing.Point($UI.Buttons.Run.Location.X, $UI.Buttons.Run.Location.Y)
    $btnRun.Size = New-Object System.Drawing.Size($UI.Buttons.Run.Size.Width, $UI.Buttons.Run.Size.Height)
    $form.Controls.Add($btnRun) | Out-Null

    $txtLog = New-Object System.Windows.Forms.RichTextBox
    $txtLog.Multiline  = $true
    $txtLog.ReadOnly   = $true
    $txtLog.ScrollBars = 'Vertical'
    $txtLog.Location   = New-Object System.Drawing.Point($UI.LogTextBox.Location.X, $UI.LogTextBox.Location.Y)
    $txtLog.Size       = New-Object System.Drawing.Size($UI.LogTextBox.Size.Width, $UI.LogTextBox.Size.Height)
    $form.Controls.Add($txtLog) | Out-Null
    $script:txtLog = $txtLog

    $pb = New-Object System.Windows.Forms.ProgressBar
    $pb.Location = New-Object System.Drawing.Point($UI.ProgressBar.Location.X, $UI.ProgressBar.Location.Y)
    $pb.Size = New-Object System.Drawing.Size($UI.ProgressBar.Size.Width, $UI.ProgressBar.Size.Height)
    $pb.Minimum = $UI.ProgressBar.Minimum
    $pb.Maximum = $UI.ProgressBar.Maximum
    $form.Controls.Add($pb) | Out-Null
    $script:pb = $pb

    $form.KeyPreview = $true
    $form.Add_KeyDown({
        if ($_.KeyCode -eq 'Escape') { $form.Close() }
        if ($_.KeyCode -eq 'Enter') { $btnRun.PerformClick() }
    }) | Out-Null

    $btnRun.Add_Click({
        if ($script:lb.Items.Count -eq 0) {
            Write-Log "La ListBox est vide" 'Red'
            return
        }
        if ($script:lb.SelectedIndex -lt 0) {
            Write-Log "Aucun élément sélectionné" 'Red'
            return
        }

        $item = $script:lb.Items[$script:lb.SelectedIndex]

        Write-Log "Sélection : $($item.label)" 'DarkCyan'

        if (-not $item.ScriptName -or [string]::IsNullOrWhiteSpace($item.ScriptName)) {
            Write-Log "Erreur: nom de script invalide" 'Red'
            return
        }

        $splat = @{ demo = $DemoMode }

        if ($item.params -and $item.params.Keys.Count -gt 0) {
            foreach ($key in $item.params.Keys) {
                $splat[$key] = $item.params[$key]
            }
        }

        $pb.Value = 0
        if (Get-Command $item.ScriptName -ErrorAction SilentlyContinue) {
            Write-Log "Exécution : $($item.ScriptName)" 'DarkGreen'
            & $item.ScriptName @splat
            $pb.Value = $pb.Maximum
            Write-Log "Terminé : $($item.ScriptName)" 'Green'
        } else {
            Write-Log "Erreur: fonction '$($item.ScriptName)' non trouvée." 'Red'
        }
    }) | Out-Null

    return $form
}

$mainForm = Build-Form -UI $UI -MenuOptions $MenuOptions -DemoMode $DemoMode

if ($mainForm -is [System.Windows.Forms.Form]) {
    [void]$mainForm.ShowDialog()
    $mainForm.Dispose()
} else {
    Write-Error "Build-Form n'a pas retourné un Form valide."
}
