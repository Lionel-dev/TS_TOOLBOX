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
$logFile = Join-Path $logDir "$user`_$date.txt"

# --- Charger YAML avec UTF8 ---
$configMenu      = Get-Content $configMenuFile      -Raw -Encoding UTF8 | ConvertFrom-Yaml
$configInterface = Get-Content $configInterfaceFile -Raw -Encoding UTF8 | ConvertFrom-Yaml
$UI              = $configInterface.Interface
$MenuOptions     = $configMenu.MenuOptions

# --- Mode Démo ---
$DemoMode      = $true
$passwordInput = [Microsoft.VisualBasic.Interaction]::InputBox(
    "Mot de passe pour passer en mode réel (laissez vide pour démo) :", $UI.Title
)
if ($passwordInput -eq $UI.DemoPassword) {
    $DemoMode = $false
    [System.Windows.Forms.MessageBox]::Show("Mode réel activé.", $UI.Title) | Out-Null
} else {
    [System.Windows.Forms.MessageBox]::Show("Mode démo actif.", $UI.Title) | Out-Null
}

# --- Import des scripts d'options ---
Get-ChildItem $optionsDir -Filter '*.ps1' | ForEach-Object { . $_.FullName }

# --- Utilitaires ---
function Write-Log {
    param([string]$msg)
    $ts    = (Get-Date).ToString('HH:mm:ss')
    $entry = "[$ts] $msg"
    $script:txtLog.AppendText($entry + "`r`n")
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

# --- Construction de l'UI ---
function Build-Form {
    param($UI, $MenuOptions)

    $form = New-Object System.Windows.Forms.Form
    $form.Text          = "$($UI.Title)™"
    $form.Size          = New-Object System.Drawing.Size($UI.Size.Width, $UI.Size.Height)
    $form.StartPosition = $UI.StartPosition

    #
    # ListBox propriétaire du dessin
    #
    $lb = New-Object System.Windows.Forms.ListBox
    $lb.Location      = New-Object System.Drawing.Point($UI.ListBox.Location.X, $UI.ListBox.Location.Y)
    $lb.Size          = New-Object System.Drawing.Size($UI.ListBox.Size.Width, $UI.ListBox.Size.Height)
    $lb.DrawMode      = 'OwnerDrawFixed'
    $lb.ItemHeight    = 20
    $lb.DisplayMember = 'Text'        # à placer avant Items.Add
    $lb.ValueMember   = 'OriginalId'  # SelectedValue sera l’index original

    # Préparer les objets à ajouter
    $items = for ($i=0; $i -lt $MenuOptions.Count; $i++) {
        $lbl = $MenuOptions[$i].label
        if ($MenuOptions[$i].SupportsDemo) { $lbl += ' (démo)' }
        else                                { $lbl += ' (non démo)' }
        [PSCustomObject]@{
            Text        = $lbl
            OriginalId  = $i
            SupportsDemo= $MenuOptions[$i].SupportsDemo
        }
    }
    # Trier en mode démo
    if ($DemoMode) {
        $items = $items | Sort-Object @{Expression={ [int]$_.SupportsDemo }} -Descending
    }
    foreach ($it in $items) {
        $lb.Items.Add($it) | Out-Null
    }
    $form.Controls.Add($lb) | Out-Null

    #
    # Boutons
    #
    $btnRun = New-Object System.Windows.Forms.Button
    $btnRun.Text     = $UI.Buttons.Run.Text
    $btnRun.Location = New-Object System.Drawing.Point($UI.Buttons.Run.Location.X, $UI.Buttons.Run.Location.Y)
    $btnRun.Size     = New-Object System.Drawing.Size($UI.Buttons.Run.Size.Width, $UI.Buttons.Run.Size.Height)
    $btnRun.Enabled  = $false
    $form.Controls.Add($btnRun) | Out-Null

    $btnExit = New-Object System.Windows.Forms.Button
    $btnExit.Text     = $UI.Buttons.Exit.Text
    $btnExit.Location = New-Object System.Drawing.Point($UI.Buttons.Exit.Location.X, $UI.Buttons.Exit.Location.Y)
    $btnExit.Size     = New-Object System.Drawing.Size($UI.Buttons.Exit.Size.Width, $UI.Buttons.Exit.Size.Height)
    $btnExit.Add_Click({ $form.Close() }) | Out-Null
    $form.Controls.Add($btnExit) | Out-Null

    # Trademark à droite
    $lblTM = New-Object System.Windows.Forms.Label
    $lblTM.Text     = 'Convergence-IT™'
    $lblTM.AutoSize = $true
    $x = $btnExit.Right + 10
    $y = $btnExit.Top + [int](($btnExit.Height - $lblTM.PreferredHeight) / 2)
    $lblTM.Location = New-Object System.Drawing.Point($x, $y)
    $form.Controls.Add($lblTM) | Out-Null

    #
    # Zone de log et ProgressBar
    #
    $txtLog = New-Object System.Windows.Forms.TextBox
    $txtLog.Multiline  = $true
    $txtLog.ReadOnly   = $true
    $txtLog.ScrollBars = 'Vertical'
    $txtLog.Location   = New-Object System.Drawing.Point($UI.LogTextBox.Location.X, $UI.LogTextBox.Location.Y)
    $txtLog.Size       = New-Object System.Drawing.Size($UI.LogTextBox.Size.Width, $UI.LogTextBox.Size.Height)
    $form.Controls.Add($txtLog) | Out-Null

    $pb = New-Object System.Windows.Forms.ProgressBar
    $pb.Location = New-Object System.Drawing.Point($UI.ProgressBar.Location.X, $UI.ProgressBar.Location.Y)
    $pb.Size     = New-Object System.Drawing.Size($UI.ProgressBar.Size.Width, $UI.ProgressBar.Size.Height)
    $pb.Minimum  = $UI.ProgressBar.Minimum
    $pb.Maximum  = $UI.ProgressBar.Maximum
    $form.Controls.Add($pb) | Out-Null

    #
    # Owner-draw pour griser les non compatibles
    #
    $lb.Add_DrawItem({
        param($s,$e)
        $item     = $s.Items[$e.Index]
        $disabled = $DemoMode -and -not $item.SupportsDemo
        $e.DrawBackground()
        if ($e.State -band [System.Windows.Forms.DrawItemState]::Selected) {
            $e.Graphics.FillRectangle([System.Drawing.SystemBrushes]::Highlight, $e.Bounds)
            $brush = [System.Drawing.SystemBrushes]::HighlightText
        } else {
            $brush = if ($disabled) {[System.Drawing.Brushes]::Gray} else {[System.Drawing.Brushes]::Black}
        }
        $e.Graphics.DrawString($item.Text, $s.Font, $brush, [System.Drawing.RectangleF]$e.Bounds)
        $e.DrawFocusRectangle()
    })

    #
    # Activation du bouton Exécuter sur sélection
    #
    $lb.Add_SelectedIndexChanged({
        $orig = $lb.SelectedValue
        if ($null -eq $orig) {
            $btnRun.Enabled = $false; return
        }
        $opt = $MenuOptions[$orig]
        $btnRun.Enabled = (-not $DemoMode) -or $opt.SupportsDemo
    })
    if ($lb.Items.Count -gt 0) { $lb.SelectedIndex = 0 }

    #
    # Logique d’exécution
    #
    $btnRun.Add_Click({
        $orig = $lb.SelectedValue
        $opt  = $MenuOptions[$orig]
        Write-Log "Option : $($opt.function)"
        if ($DemoMode) {
            Write-Log "MODE DÉMO — simulation"
        } else {
            $splat = @{}
            if ($opt.params.Count -gt 0) {
                $p = Prompt-ForParams $opt.params
                if ($null -eq $p) { Write-Log "Annulé"; return }
                $splat = $p
            }
            & $opt.function @splat
        }
        Write-Log "Terminé"
    })

    # Expose pour Write-Log et ProgressBar
    $script:txtLog = $txtLog
    $script:pb     = $pb

    return $form
}

# --- Lancement ---
Remove-Variable form -ErrorAction SilentlyContinue
$mainForm = Build-Form -UI $UI -MenuOptions $MenuOptions
[void]$mainForm.ShowDialog()
