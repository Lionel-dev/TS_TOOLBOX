function Out-Symlink {
    <#
    .SYNOPSIS
        Vérifie les symlinks Outlook pour chaque utilisateur et génère un rapport.

    .DESCRIPTION
        Ce script parcourt tous les dossiers utilisateurs du répertoire spécifié par UsersPath,
        vérifie si le dossier Outlook est un lien symbolique et compare sa cible avec
        ExpectedTargetPattern. Un rapport HTML et un fichier BAT sont générés.
        La barre de progression et les journaux sont mis à jour via les fonctions du
        module TS-Toolbox.Common (Write-Log et Update-ProgressSafe). Le paramètre
        DemoMode empêche l’ouverture automatique du rapport après génération.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory)][string]$UsersPath,
        [Parameter(Mandatory)][string]$ExpectedTargetPattern,
        [System.Windows.Forms.ProgressBar]$ProgressBar,
        [switch]$DemoMode
    )

    # Vérifie les droits administrateur
    Ensure-Admin
    Write-Log "Vérification des symlinks Outlook dans '$UsersPath'" 'DarkCyan'

    # Comptes à exclure
    $exclude = @(
        'Default','Default User','Public','All Users','desktop.ini',
        'WDAGUtilityAccount','Administrator','DefaultAppPool','zabbix'
    )

    # Collecte des dossiers utilisateurs
    $users = Get-ChildItem -Path $UsersPath -Directory -Force |
             Where-Object { $_.Name -notin $exclude }
    $countUsers = $users.Count
    if ($countUsers -eq 0) { $countUsers = 1 }
    $index = 0

    $rows    = New-Object System.Collections.Generic.List[string]
    $mklinks = New-Object System.Collections.Generic.List[string]

    foreach ($u in $users) {
        $index++
        $percent = [int]([math]::Floor($index * 100 / $countUsers))
        Update-ProgressSafe -ProgressBar $ProgressBar -Percent $percent

        $userName    = $u.Name
        $outlookPath = Join-Path $u.FullName 'AppData\Local\Microsoft\Outlook'
        $expected    = $ExpectedTargetPattern.Replace('{user}', $userName)
        $mklinks.Add("mklink /D `"$outlookPath`" `"$expected`"")

        $state   = 'KO'
        $details = ''

        if (-not (Test-Path $outlookPath)) {
            $details = 'Dossier Outlook introuvable'
        } else {
            $item = Get-Item $outlookPath -Force
            if (-not ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
                $details = 'Pas de symlink'
            } else {
                $target = $item.Target
                if ($target -ne $expected) {
                    $details = "Mauvaise cible : '$target' au lieu de '$expected'"
                } elseif (-not (Test-Path $target)) {
                    $details = "Cible absente : '$target'"
                } else {
                    $state   = 'OK'
                    $details = "Lien valide vers '$target'"
                    try {
                        $ostFiles = Get-ChildItem -Path $target -Filter '*.ost' -ErrorAction SilentlyContinue
                        if ($ostFiles.Count -gt 1) {
                            $details += ' - ' + $ostFiles.Count + ' fichiers OST détectés'
                        }
                    } catch {}
                }
            }
        }
        $class  = if ($state -eq 'OK') { 'ok' } else { 'ko' }
        $encoded = [System.Web.HttpUtility]::HtmlEncode($details)
        $rows.Add("<tr><td>$userName</td><td class='$class'>$state</td><td>$encoded</td></tr>")
    }

    # Résumé
    $okCount = ($rows | Where-Object { $_ -like "*class='ok'*" }).Count
    $koCount = ($rows | Where-Object { $_ -like "*class='ko'*" }).Count
    $summary = "Profils utilisateurs détectés : $($users.Count)`nOK : $okCount`nKO : $koCount"

    # Récupération du template HTML
    $tplPath = Join-Path $PSScriptRoot '..\Templates\OutSymlinkReport.html'
    if (-not (Test-Path $tplPath)) {
        throw "Template HTML introuvable : $tplPath"
    }
    $html = Get-Content $tplPath -Raw -Encoding UTF8
    $html = $html.Replace('{{GeneratedAt}}', (Get-Date).ToString())
    $html = $html.Replace('{{Rows}}', ($rows -join "`r`n"))
    $html = $html.Replace('{{Summary}}', $summary)
    $html = $html.Replace('{{Mklink}}', ($mklinks -join "`r`n"))

    # Sauvegarde dans le dossier Logs
    $logsDir = Join-Path $PSScriptRoot '..\Logs'
    New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
    $timestamp = Get-Date -Format 'yyyy-MM-dd_HHmmss'
    $htmlFile  = Join-Path $logsDir "Out-Symlink_$timestamp.html"
    $batFile   = Join-Path $logsDir "Out-Symlink_$timestamp.bat"

    if ($PSCmdlet.ShouldProcess($htmlFile, 'Écriture du rapport HTML')) {
        $html | Out-File -FilePath $htmlFile -Encoding UTF8 -Force
        ($mklinks -join "`r`n") | Out-File -FilePath $batFile -Encoding ascii -Force
        if (-not $DemoMode) {
            Start-Process $htmlFile
        }
    }
    Update-ProgressSafe -ProgressBar $ProgressBar -Percent 100
    Write-Log ("Rapport généré : $htmlFile") 'Green'
}