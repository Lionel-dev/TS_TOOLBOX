Add-Type -AssemblyName System.Windows.Forms

# Cible de log (RichTextBox) enregistrée par le main
$script:LogControl = $null

function Set-LogControl {
    param([System.Windows.Forms.RichTextBox]$Control)
    $script:LogControl = $Control
}

function Append-RtbLine {
    param(
        [System.Windows.Forms.RichTextBox]$Rtb,
        [string]$Text,
        [string]$Color = 'Black'
    )

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

    # Fallback console si l'UI n'est pas initialisée/disponible
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

Export-ModuleMember -Function Set-LogControl, Write-Log, Update-ProgressSafe
