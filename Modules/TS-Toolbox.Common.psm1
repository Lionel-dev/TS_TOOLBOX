Add-Type -AssemblyName System.Windows.Forms

# Cible de log (RichTextBox) enregistrée par le main
$script:LogControl = $null

function Set-LogControl {
    param([System.Windows.Forms.RichTextBox]$Control)
    $script:LogControl = $Control
}

function Append-RtbLine {
    param([System.Windows.Forms.RichTextBox]$Rtb, [string]$Text, [string]$Color = 'Black')
    $action = {
        param($rtb,$t,$c)
        $rtb.SelectionStart  = $rtb.TextLength
        $rtb.SelectionColor  = [System.Drawing.Color]::$c
        $rtb.AppendText("$t`r`n")
        $rtb.SelectionColor  = $rtb.ForeColor
    }
    if ($Rtb.InvokeRequired) {
        $null = $Rtb.BeginInvoke($action, $Rtb, $Text, $Color)
    } else {
        & $action $Rtb $Text $Color
    }
}

function Write-Log {
    param([string]$Message, [string]$Color = 'Black')
    $ts   = (Get-Date -Format 'HH:mm:ss')
    $line = "[$ts] $Message"
    if ($script:LogControl -and -not $script:LogControl.IsDisposed) {
        Append-RtbLine -Rtb $script:LogControl -Text $line -Color $Color
        return
    }
    Write-Host $line
}

function Update-ProgressSafe {
    param([System.Windows.Forms.ProgressBar]$ProgressBar, [int]$Percent)
    if ($ProgressBar) {
        $p = [Math]::Max($ProgressBar.Minimum, [Math]::Min($Percent, $ProgressBar.Maximum))
        if ($ProgressBar.InvokeRequired) {
            $null = $ProgressBar.BeginInvoke([Action[int]]{ param($val) $ProgressBar.Value = $val }, $p)
        } else {
            $ProgressBar.Value = $p
        }
        [System.Windows.Forms.Application]::DoEvents()
    }
}

function Convert-StringToType {
    param(
        [Parameter(Mandatory)][string]$Input,
        [Parameter(Mandatory)][ValidateSet('string','int','datetime','bool','path','percent')]$Type
    )
    switch ($Type) {
        'string'   { return $Input }
        'int'      { return [int]$Input }
        'datetime' { return [datetime]$Input }
        'bool'     { return [bool]::Parse($Input) }
        'path'     {
            if (-not (Test-Path $Input)) { throw \"Chemin introuvable: $Input\" }
            return (Resolve-Path $Input).Path
        }
        'percent'  {
            $v = [int]$Input
            if ($v -lt 1 -or $v -gt 100) { throw \"Pourcentage invalide (1-100): $v\" }
            return $v
        }
    }
}

function Ensure-Admin {
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw \"Ce script nécessite des droits administrateur.\"
    }
}

Export-ModuleMember -Function Set-LogControl, Write-Log, Update-ProgressSafe, Convert-StringToType, Ensure-Admin
