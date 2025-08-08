# main.ps1 — TS Toolbox harmonisé
# --------------------------------
# Chargement des modules nécessaires
Import-Module "$PSScriptRoot\Modules\TS-Toolbox.Common.psm1" -Force
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName Microsoft.VisualBasic

# --- Fonctions utilitaires internes au main ---

function Load-YamlFile {
    param([string]$Path)
    if (-not (Get-Command ConvertFrom-Yaml -ErrorAction SilentlyContinue)) {
        throw "Module powershell-yaml requis. Install-Module -Name powershell-yaml -Scope CurrentUser"
    }
    if (-not (Test-Path $Path)) {
        throw "Fichier YAML introuvable: $Path"
    }
    Get-Content $Path -Raw -Encoding UTF8 | ConvertFrom-Yaml
}

class MenuItem {
    [string]$Label
    [string]$ScriptName
    [object]$Params
    MenuItem([string]$Label, [string]$ScriptName, [object]$Params) {
        $this.Label = $Label
        $this.ScriptName = $ScriptName
        $this.Params = $Params
    }
    [string] ToString() { return $this.Label }
}

function Choose-Mode {
    param($Config)
    $form = New-Object System.Windows.Forms.Form
    $form.Text = $Config.Title
    $form.Size = New-Object System.Drawing.Size($Config.Size.Width, $Config.Size.Height)
    $form.StartPosition = 'CenterScreen'

    $btnDemo = New-Object System.Windows.Forms.Button
    $btnDemo.Text = $Config.Buttons.Demo.Text
    $btnDemo.Size = New-Object System.Drawing.Size($Config.Buttons.Demo.Size.Width, $Config.Buttons.Demo.Size.Height)
    $btnDemo.Location = New-Object System.Drawing.Point($Config.Buttons.Demo.Location.X, $Config.Buttons.Demo.Location.Y)
    $btnDemo.Add_Click({ $form.Tag = $true; $form.Close() }) | Out-Null
    $form.Controls.Add($btnDemo)

    $btnProd = New-Object System.Windows.Forms.Button
    $btnProd.Text = $Config.Buttons.Prod.Text
    $btnProd.Size = New-Object System.Drawing.Size($Config.Buttons.Prod.Size.Width, $Config.Buttons.Prod.Size.Height)
    $btnProd.Location = New-Object System.Drawing.Point($Config.Buttons.Prod.Location.X, $Config.Buttons.Prod.Location.Y)
    $btnProd.Add_Click({ $form.Tag = $false; $form.Close() }) | Out-Null
    $form.Controls.Add($btnProd)

    [void]$form.ShowDialog()
    return [bool]$form.Tag
}

function Build-Form {
    param($UIConfig, $MenuOptions, $DemoMode)

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "{0} {1}" -f $UIConfig.Title, $(if ($DemoMode) {'(Démo)'} else {''})
    $form.Size = New-Object System.Drawing.Size($UIConfig.Size.Width, $UIConfig.Size.Height)
    $form.StartPosition = $UIConfig.StartPosition

    $lb = New-Object System.Windows.Forms.ListBox
    $lb.Location = New-Object System.Drawing.Point($UIConfig.ListBox.Location.X, $UIConfig.ListBox.Location.Y)
    $lb.Size = New-Object System.Drawing.Size($UIConfig.ListBox.Size.Width, $UIConfig.ListBox.Size.Height)
    $form.Controls.Add($lb)
    $script:lb = $lb

    foreach ($opt in $MenuOptions) {
        if (-not $opt.function) { continue }
        if ($DemoMode -and -not $opt.SupportsDemo) { continue }
        $item = [MenuItem]::new($opt.label, $opt.function, $opt.params)
        $lb.Items.Add($item) | Out-Null
    }
    if ($lb.Items.Count -gt 0) { $lb.SelectedIndex = 0 }

    $btnRun = New-Object System.Windows.Forms.Button
    $btnRun.Text = $UIConfig.Buttons.Run.Text
    $btnRun.Location = New-Object System.Drawing.Point($UIConfig.Buttons.Run.Location.X, $UIConfig.Buttons.Run.Location.Y)
    $btnRun.Size = New-Object System.Drawing.Size($UIConfig.Buttons.Run.Size.Width, $UIConfig.Buttons.Run.Size.Height)
    $form.Controls.Add($btnRun)

    $txtLog = New-Object System.Windows.Forms.RichTextBox
    $txtLog.Multiline = $true
    $txtLog.ReadOnly = $true
    $txtLog.ScrollBars = 'Vertical'
    $txtLog.Location = New-Object System.Drawing.Point($UIConfig.LogTextBox.Location.X, $UIConfig.LogTextBox.Location.Y)
    $txtLog.Size = New-Object System.Drawing.Size($UIConfig.LogTextBox.Size.Width, $UIConfig.LogTextBox.Size.Height)
    $form.Controls.Add($txtLog)
    Set-LogControl -Control $txtLog
    $script:txtLog = $txtLog

    


    $pb = New-Object System.Windows.Forms.ProgressBar
    $pb.Location = New-Object System.Drawing.Point($UIConfig.ProgressBar.Location.X, $UIConfig.ProgressBar.Location.Y)
    $pb.Size = New-Object System.Drawing.Size($UIConfig.ProgressBar.Size.Width, $UIConfig.ProgressBar.Size.Height)
    $pb.Minimum = $UIConfig.ProgressBar.Minimum
    $pb.Maximum = $UIConfig.ProgressBar.Maximum
    $form.Controls.Add($pb)
    $script:pb = $pb

    $btnRun.Add_Click({
        if ($script:lb.SelectedIndex -lt 0) {
            Write-Log "Aucune option sélectionnée" 'Red'
            return
        }
        $item = $script:lb.Items[$script:lb.SelectedIndex]
        $splat = @{}
        $splat['DemoMode']    = $DemoMode
        $splat['ProgressBar'] = $script:pb

        # Gestion des paramètres typés
        if ($item.Params -and $item.Params.Count -gt 0) {
            $final = @{}
            foreach ($p in $item.Params) {
                $default = [string]$p.Default
                $input = if (-not $DemoMode) {
                    [Microsoft.VisualBasic.Interaction]::InputBox(
                        ($p.Prompt + " (actuelle : $default)"),
                        ("Paramètre : " + $p.Name),
                        $default
                    )
                } else { $default }

                if ([string]::IsNullOrWhiteSpace($input)) { $input = $default }
                try {
                    $final[$p.Name] = Convert-StringToType -Input $input -Type $p.Type
                } catch {
                    Write-Log "Paramètre invalide '$($p.Name)': $input (`"$($_.Exception.Message)`")" 'Red'
                    return
                }
            }
            foreach ($k in $final.Keys) { $splat[$k] = $final[$k] }
        }

        $script:pb.Value = 0
        if (Get-Command $item.ScriptName -ErrorAction SilentlyContinue) {
            Write-Log "Exécution : $($item.ScriptName)" 'DarkGreen'
            & $item.ScriptName @splat
            $script:pb.Value = $script:pb.Maximum
            Write-Log "Terminé : $($item.ScriptName)" 'Green'
        } else {
            Write-Log "Erreur : fonction '$($item.ScriptName)' non trouvée." 'Red'
        }
    })

    return $form
}

# --- Chargement config ---
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$configMenuFile      = Join-Path $scriptDir 'Config\config_menu.yaml'
$configInterfaceFile = Join-Path $scriptDir 'Config\config_interface.yaml'
$configMenu      = Load-YamlFile $configMenuFile
$configInterface = Load-YamlFile $configInterfaceFile

# --- Chargement scripts Options ---
Get-ChildItem -Path (Join-Path $scriptDir 'Options') -Filter *.ps1 | ForEach-Object {
    . $_.FullName
}

# --- Choix mode ---
$DemoMode = Choose-Mode $configInterface.ModeChooser
Write-Log "Mode choisi : $(if ($DemoMode) {'Démo'} else {'Prod'})" 'Blue'

# --- Lancement interface ---
$mainForm = Build-Form $configInterface.Interface $configMenu.MenuOptions $DemoMode
[void]$mainForm.ShowDialog()
$mainForm.Dispose()
