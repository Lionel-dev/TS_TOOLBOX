# Chargement du module commun et des assemblies nécessaires
Import-Module "$PSScriptRoot\Modules\TS-Toolbox.Common.psm1" -Force
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName Microsoft.VisualBasic

function Get-IntValue {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)] $Value)
    if ($null -eq $Value) { return 0 }
    if ($Value -is [System.Array] -and $Value.Count -gt 0) { return [int]$Value[0] }
    return [int]$Value
}

function Write-Log {
    param([string]$msg, [string]$color = 'Black')
    $ts   = (Get-Date -Format 'HH:mm:ss')
    $line = "[$ts] $msg"
    if ($script:txtLog -and -not $script:txtLog.IsDisposed) {
        $script:txtLog.SelectionStart  = $script:txtLog.TextLength
        $script:txtLog.SelectionColor  = [System.Drawing.Color]::$color
        $script:txtLog.AppendText("$line`r`n")
        $script:txtLog.SelectionColor  = $script:txtLog.ForeColor
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
    [object]$params
    MenuItem([string]$label, [string]$ScriptName, [object]$params) {
        $this.label      = $label
        $this.ScriptName = $ScriptName
        $this.params     = $params
    }
    [string] ToString() { return $this.label }
}

function Prompt-ForParams {
    param([hashtable]$Params)
    $newParams = @{}
    foreach ($key in $Params.Keys) {
        $defaultValue = $Params[$key]
        $prompt = "Valeur pour '$key' (actuelle : $defaultValue) :"
        $title  = "Paramètre : $key"
        $value = [Microsoft.VisualBasic.Interaction]::InputBox($prompt, $title, [string]$defaultValue)
        if ($value) { $newParams[$key] = $value } else { $newParams[$key] = $defaultValue }
    }
    return $newParams
}

$scriptDir           = Split-Path -Parent $MyInvocation.MyCommand.Definition
$configDir           = Join-Path $scriptDir 'Config'
$optionsDir          = Join-Path $scriptDir 'Options'
$configMenuFile      = Join-Path $configDir 'config_menu.yaml'
$configInterfaceFile = Join-Path $configDir 'config_interface.yaml'

$configMenu      = Load-YamlFile $configMenuFile
$configInterface = Load-YamlFile $configInterfaceFile
$UI          = $configInterface.Interface
$ModeChooser = $configInterface.ModeChooser
$MenuOptions = $configMenu.MenuOptions

Get-ChildItem -Path $optionsDir -Filter *.ps1 | ForEach-Object {
    Write-Log "Chargement: $($_.Name)" 'DarkGreen'
    . $_.FullName
}

function Choose-Mode {
    $cfg  = $ModeChooser
    $form = New-Object System.Windows.Forms.Form
    $form.Text = $cfg.Title
    $form.Size = New-Object System.Drawing.Size($cfg.Size.Width, $cfg.Size.Height)
    $form.StartPosition = 'CenterScreen'
    $form.Font = New-Object System.Drawing.Font('Segoe UI', 10)

    $btnDemo = New-Object System.Windows.Forms.Button
    $btnDemo.Text = $cfg.Buttons.Demo.Text
    $btnDemo.Size = New-Object System.Drawing.Size($cfg.Buttons.Demo.Size.Width, $cfg.Buttons.Demo.Size.Height)
    $btnDemo.Location = New-Object System.Drawing.Point($cfg.Buttons.Demo.Location.X, $cfg.Buttons.Demo.Location.Y)
    $btnDemo.Add_Click({ $form.Tag = $true; $form.Close() })
    $form.Controls.Add($btnDemo)

    $btnProd = New-Object System.Windows.Forms.Button
    $btnProd.Text = $cfg.Buttons.Prod.Text
    $btnProd.Size = New-Object System.Drawing.Size($cfg.Buttons.Prod.Size.Width, $cfg.Buttons.Prod.Size.Height)
    $btnProd.Location = New-Object System.Drawing.Point($cfg.Buttons.Prod.Location.X, $cfg.Buttons.Prod.Location.Y)
    $btnProd.Add_Click({ $form.Tag = $false; $form.Close() })
    $form.Controls.Add($btnProd)

    [void]$form.ShowDialog()
    $form.Dispose()
    return [bool]$form.Tag
}

$DemoMode = Choose-Mode
Write-Log "Mode choisi : $(if ($DemoMode) {'Démo'} else {'Prod'})" 'Blue'

function Build-Form {
    param($UI, $MenuOptions, $DemoMode)

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "{0} {1}" -f $UI.Title, $(if ($DemoMode) {'(Démo)'} else {''})
    $form.Size = New-Object System.Drawing.Size($UI.Size.Width, $UI.Size.Height)
    $form.StartPosition = $UI.StartPosition

    $form.BackColor = [System.Drawing.Color]::Black
    $form.ForeColor = [System.Drawing.Color]::White
    $form.Font      = New-Object System.Drawing.Font('Segoe UI', 10)
    $toolTip = New-Object System.Windows.Forms.ToolTip

    # Logo avec fond noir
    $logoPath = Join-Path $scriptDir 'Images\logo.png'
    if (Test-Path $logoPath) {
        $logoPanel = New-Object System.Windows.Forms.Panel
        $logoPanel.Location = New-Object System.Drawing.Point(10, 10)
        $logoPanel.Size     = New-Object System.Drawing.Size(70, 70)

        $pic = New-Object System.Windows.Forms.PictureBox
        $pic.Image    = [System.Drawing.Image]::FromFile($logoPath)
        $pic.SizeMode = 'Zoom'
        $pic.Dock     = 'Fill'

        $logoPanel.Controls.Add($pic)
        $form.Controls.Add($logoPanel)
    }

    # GroupBox Actions
    $gbList = New-Object System.Windows.Forms.GroupBox
    $gbList.Text = 'Actions disponibles'
    $listX      = Get-IntValue $UI.ListBox.Location.X
    $listY      = Get-IntValue $UI.ListBox.Location.Y
    $listWidth  = Get-IntValue $UI.ListBox.Size.Width
    $listHeight = Get-IntValue $UI.ListBox.Size.Height
    $gbList.Location = New-Object System.Drawing.Point($($listX + 90), $listY) # espace avec logo
    $gbList.Size     = New-Object System.Drawing.Size($(($listWidth + 10)), ($listHeight + 20))
    $form.Controls.Add($gbList)

    $lb = New-Object System.Windows.Forms.ListBox
    $lb.Location = New-Object System.Drawing.Point(5, 15)
    $lb.Size     = New-Object System.Drawing.Size($listWidth, $listHeight)
    $script:lb   = $lb
    foreach ($opt in $MenuOptions) {
        if (-not $opt.function) { continue }
        if ($DemoMode -and -not $opt.SupportsDemo) { continue }
        $item = [MenuItem]::new($opt.label, $opt.function, $opt.params)
        $lb.Items.Add($item) | Out-Null
    }
    if ($lb.Items.Count -gt 0) { $lb.SelectedIndex = 0 }
    $gbList.Controls.Add($lb)

    # GroupBox Log
    $gbLog  = New-Object System.Windows.Forms.GroupBox
    $gbLog.Text = 'Journal'
    $logX      = Get-IntValue $UI.LogTextBox.Location.X
    $logY      = Get-IntValue $UI.LogTextBox.Location.Y
    $logWidth  = Get-IntValue $UI.LogTextBox.Size.Width
    $logHeight = Get-IntValue $UI.LogTextBox.Size.Height
    $gbLog.Location = New-Object System.Drawing.Point($logX, $logY)
    $gbLog.Size     = New-Object System.Drawing.Size(($logWidth + 10), ($logHeight + 20))
    $form.Controls.Add($gbLog)

    $txtLog = New-Object System.Windows.Forms.RichTextBox
    $txtLog.Multiline  = $true
    $txtLog.ReadOnly   = $true
    $txtLog.ScrollBars = 'Vertical'
    $txtLog.Location   = New-Object System.Drawing.Point(5, 15)
    $txtLog.Size       = New-Object System.Drawing.Size($logWidth, $logHeight)
    $txtLog.BackColor  = [System.Drawing.Color]::Lavender
    $gbLog.Controls.Add($txtLog)
    $script:txtLog = $txtLog

    # ProgressBar
    $pb = New-Object System.Windows.Forms.ProgressBar
    $pb.Location = New-Object System.Drawing.Point($UI.ProgressBar.Location.X, $UI.ProgressBar.Location.Y)
    $pb.Size     = New-Object System.Drawing.Size($UI.ProgressBar.Size.Width, $UI.ProgressBar.Size.Height)
    $pb.Minimum  = $UI.ProgressBar.Minimum
    $pb.Maximum  = $UI.ProgressBar.Maximum
    $form.Controls.Add($pb)
    $script:pb = $pb

    # Boutons
    $btnRun = New-Object System.Windows.Forms.Button
    $btnRun.Text     = $UI.Buttons.Run.Text
    $btnRun.Size     = New-Object System.Drawing.Size($UI.Buttons.Run.Size.Width, $UI.Buttons.Run.Size.Height)
    $btnRun.Location = New-Object System.Drawing.Point($UI.Buttons.Run.Location.X, $UI.Buttons.Run.Location.Y)
    $btnRun.BackColor = [System.Drawing.Color]::Gray
    $btnRun.ForeColor = [System.Drawing.Color]::White


    $form.Controls.Add($btnRun)

    $btnClose = New-Object System.Windows.Forms.Button
    $btnClose.Text     = $UI.Buttons.close.Text
    $btnClose.Size     = New-Object System.Drawing.Size($UI.Buttons.close.Size.Width, $UI.Buttons.close.Size.Height)
    $btnClose.Location = New-Object System.Drawing.Point($UI.Buttons.close.Location.X, $UI.Buttons.close.Location.Y)
    $btnClose.BackColor = [System.Drawing.Color]::DarkRed
    $btnClose.ForeColor = [System.Drawing.Color]::White
    $btnClose.Add_Click({
        $this.FindForm().Close()
    })

     $form.Controls.Add($btnClose)


    try { Set-LogControl -Control $txtLog } catch {}

    $btnRun.Add_Click({
        if ($script:lb.Items.Count -eq 0) { Write-Log 'La liste des options est vide' 'Red'; return }
        if ($script:lb.SelectedIndex -lt 0) { Write-Log 'Aucune option sélectionnée' 'Red'; return }
        $item = $script:lb.Items[$script:lb.SelectedIndex]
        Write-Log "Sélection : $($item.label)" 'DarkCyan'
        if (-not $item.ScriptName -or [string]::IsNullOrWhiteSpace($item.ScriptName)) {
            Write-Log 'Erreur : nom de script invalide' 'Red'; return
        }
        $splat = @{ DemoMode = $DemoMode; ProgressBar = $script:pb }
        if ($item.params) {
            if ($item.params -is [System.Collections.IEnumerable] -and -not ($item.params -is [hashtable])) {
                $final = @{}
                foreach ($p in $item.params) {
                    $default = [string]$p.Default
                    $input = if (-not $DemoMode) {
                        [Microsoft.VisualBasic.Interaction]::InputBox(($p.Prompt + " (actuelle : $default)"), ("Paramètre : " + $p.Name), $default)
                    } else { $default }
                    if ([string]::IsNullOrWhiteSpace($input)) { $input = $default }
                    $final[$p.Name] = Convert-StringToType -Input $input -Type $p.Type
                }
                foreach ($k in $final.Keys) { $splat[$k] = $final[$k] }
            } elseif ($item.params -is [hashtable]) {
                $paramsFromYaml = @{}
                foreach ($k in $item.params.Keys) { $paramsFromYaml[$k] = $item.params[$k] }
                if (-not $DemoMode) { $paramsFromYaml = Prompt-ForParams -Params $paramsFromYaml }
                foreach ($k in $paramsFromYaml.Keys) { $splat[$k] = $paramsFromYaml[$k] }
            }
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

$mainForm = Build-Form -UI $UI -MenuOptions $MenuOptions -DemoMode $DemoMode
if ($mainForm -is [System.Windows.Forms.Form]) {
    [void]$mainForm.ShowDialog()
    $mainForm.Dispose()
} else {
    Write-Error "La fonction Build-Form n'a pas retourné un objet Form valide."
}
