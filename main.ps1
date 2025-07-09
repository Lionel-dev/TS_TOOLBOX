# main.ps1
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName Microsoft.VisualBasic  # Pour InputBox

# --- Charger ConvertFrom-Yaml si besoin ---
if (-not (Get-Command ConvertFrom-Yaml -ErrorAction SilentlyContinue)) {
    Install-Module -Name powershell-yaml -Force -Scope CurrentUser -SkipPublisherCheck
    Import-Module powershell-yaml
}

# --- Chemins ---
$scriptDir           = Split-Path -Parent $MyInvocation.MyCommand.Definition
$configDir           = Join-Path $scriptDir 'Config'
$configMenuFile      = Join-Path $configDir 'config_menu.yaml'
$configInterfaceFile = Join-Path $configDir 'config_interface.yaml'
$optionsDir          = Join-Path $scriptDir 'Options'
$logDir              = Join-Path $scriptDir 'Logs'
if (-not (Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory | Out-Null }

# --- Log quotidien ---
$user    = $env:USERNAME
$date    = (Get-Date).ToString('yyyy-MM-dd')
$logFile = Join-Path $logDir "$user_$date.txt"

# --- Charger YAML avec UTF8 ---
$configMenu      = Get-Content $configMenuFile      -Raw -Encoding UTF8 | ConvertFrom-Yaml
$configInterface = Get-Content $configInterfaceFile -Raw -Encoding UTF8 | ConvertFrom-Yaml
$UI              = $configInterface.Interface
$MenuOptions     = $configMenu.MenuOptions

# --- Choix Mode Démo / Production ---
function Choose-Mode {
    $chooser = New-Object System.Windows.Forms.Form
    $chooser.Text = "$($UI.Title)™ - Sélection du mode"
    $chooser.Size = New-Object System.Drawing.Size(300,120)
    $chooser.StartPosition = 'CenterScreen'

    $btnDemo = New-Object System.Windows.Forms.Button
    $btnDemo.Text = 'Mode Démo'
    $btnDemo.Size = New-Object System.Drawing.Size(100,30)
    $btnDemo.Location = New-Object System.Drawing.Point(30,40)
    $btnDemo.Add_Click({ $chooser.Tag = $true; $chooser.Close() })
    $chooser.Controls.Add($btnDemo) | Out-Null

    $btnProd = New-Object System.Windows.Forms.Button
    $btnProd.Text = 'Mode Prod'
    $btnProd.Size = New-Object System.Drawing.Size(100,30)
    $btnProd.Location = New-Object System.Drawing.Point(160,40)
    $btnProd.Add_Click({ $chooser.Tag = $false; $chooser.Close() })
    $chooser.Controls.Add($btnProd) | Out-Null

    [void]$chooser.ShowDialog()
    return [bool]$chooser.Tag
}

$DemoMode = Choose-Mode

# --- Import des scripts d'options ---
Get-ChildItem $optionsDir -Filter '*.ps1' | ForEach-Object { . $_.FullName }

# --- Utilitaires ---
function Write-Log {
    param([string]$msg)
    $ts    = (Get-Date).ToString('HH:mm:ss')
    $entry = "[$ts] $msg"
    $script:txtLog.AppendText($entry + "rn")
    Add-Content -Path $logFile -Value $entry
    [System.Windows.Forms.Application]::DoEvents()
}

function Prompt-ForParams {
    param($params)
    $res = @{}
    foreach ($k in $params.Keys) {
        $default = [string]$params[$k]
        $input   = [Microsoft.VisualBasic.Interaction]::InputBox(
            "Valeur pour '$k' :", $UI.Title, $default
        )
        if ([string]::IsNullOrWhiteSpace($input)) { return $null }
        $res[$k] = $input
    }
    return $res
}

# --- Construction de l'UI Principale ---
function Build-Form {
    param($UI, $MenuOptions, $DemoMode)

    if ($DemoMode) {
        $menuOptionsLoc = $MenuOptions | Where-Object { $_.SupportsDemo }
    } else {
        $menuOptionsLoc = $MenuOptions
    }

    $form = New-Object System.Windows.Forms.Form
    $titleSuffix = if ($DemoMode) { ' (Démo)' } else { ' (Prod)' }
    $form.Text = "$($UI.Title)™$titleSuffix"
    $form.Size          = New-Object System.Drawing.Size($UI.Size.Width, $UI.Size.Height)
    $form.StartPosition = $UI.StartPosition

    $lb = New-Object System.Windows.Forms.ListBox
    $lb.Location      = New-Object System.Drawing.Point($UI.ListBox.Location.X, $UI.ListBox.Location.Y)
    $lb.Size          = New-Object System.Drawing.Size($UI.ListBox.Size.Width, $UI.ListBox.Size.Height)
    $lb.DisplayMember = 'label'

    foreach ($opt in $menuOptionsLoc) {
        $lbl = $opt.label
        if ($opt.SupportsDemo) { $lbl += ' (démo)' } else { $lbl += ' (non démo)' }
        $lb.Items.Add([PSCustomObject]@{ label=$lbl; ScriptName=$opt.function; params=$opt.params }) | Out-Null
    }
    $form.Controls.Add($lb) | Out-Null

    $btnRun = New-Object System.Windows.Forms.Button
    $btnRun.Text     = $UI.Buttons.Run.Text
    $btnRun.Location = New-Object System.Drawing.Point($UI.Buttons.Run.Location.X, $UI.Buttons.Run.Location.Y)
    $btnRun.Size     = New-Object System.Drawing.Size($UI.Buttons.Run.Size.Width, $UI.Buttons.Run.Size.Height)
    $btnRun.Enabled  = $true
    $form.Controls.Add($btnRun) | Out-Null

    $btnExit = New-Object System.Windows.Forms.Button
    $btnExit.Text     = $UI.Buttons.Exit.Text
    $btnExit.Location = New-Object System.Drawing.Point($UI.Buttons.Exit.Location.X, $UI.Buttons.Exit.Location.Y)
    $btnExit.Size     = New-Object System.Drawing.Size($UI.Buttons.Exit.Size.Width, $UI.Buttons.Exit.Size.Height)
    $btnExit.Add_Click({ $form.Close() }) | Out-Null
    $form.Controls.Add($btnExit) | Out-Null

    $lblTM = New-Object System.Windows.Forms.Label
    $lblTM.Text     = 'Convergence-IT™'
    $lblTM.AutoSize = $true
    $bounds = $btnExit.Bounds
    $x = $bounds.Right + 10
    $y = $bounds.Top + [int](($btnExit.Height - $lblTM.PreferredHeight) / 2)
    $lblTM.Location = New-Object System.Drawing.Point($x, $y)
    $form.Controls.Add($lblTM) | Out-Null

    $txtLog = New-Object System.Windows.Forms.TextBox
    $txtLog.Multiline  = $true; $txtLog.ReadOnly   = $true; $txtLog.ScrollBars = 'Vertical'
    $txtLog.Location   = New-Object System.Drawing.Point($UI.LogTextBox.Location.X, $UI.LogTextBox.Location.Y)
    $txtLog.Size       = New-Object System.Drawing.Size($UI.LogTextBox.Size.Width, $UI.LogTextBox.Size.Height)
    $form.Controls.Add($txtLog) | Out-Null

    $pb = New-Object System.Windows.Forms.ProgressBar
    $pb.Location = New-Object System.Drawing.Point($UI.ProgressBar.Location.X, $UI.ProgressBar.Location.Y)
    $pb.Size     = New-Object System.Drawing.Size($UI.ProgressBar.Size.Width, $UI.ProgressBar.Size.Height)
    $pb.Minimum  = $UI.ProgressBar.Minimum; $pb.Maximum = $UI.ProgressBar.Maximum
    $form.Controls.Add($pb) | Out-Null

    $lb.Add_SelectedIndexChanged({ $btnRun.Enabled = $true })

    $btnRun.Add_Click({
        $item = $lb.SelectedItem
        Write-Log "Exécution de $($item.ScriptName) en mode demo=$DemoMode"
        $splat = @{ demo = $DemoMode }
        if ($item.params.Count -gt 0) {
            $p = Prompt-ForParams $item.params
            if ($null -eq $p) { Write-Log "Annulé"; return }
            $splat += $p
        }
                # Vérifier que ScriptName n'est pas nul ou vide
        if ([string]::IsNullOrWhiteSpace($item.ScriptName)) {
            Write-Log "Erreur: nom de script manquant pour l'option sélectionnée"
            return
        }
        if (Get-Command $item.ScriptName -ErrorAction SilentlyContinue) {
            & $item.ScriptName @splat
        } elseif (Test-Path (Join-Path $optionsDir ($item.ScriptName + '.ps1'))) {
            & (Join-Path $optionsDir ($item.ScriptName + '.ps1')) @splat
        } else {
            Write-Log "Erreur: impossible de trouver la commande ou le script '$($item.ScriptName)'"
        }
        Write-Log "Terminé"
    })

    $script:txtLog = $txtLog; $script:pb = $pb
    return $form
}

Remove-Variable form -ErrorAction SilentlyContinue
$mainForm = Build-Form -UI $UI -MenuOptions $MenuOptions -DemoMode $DemoMode
[void]$mainForm.ShowDialog()