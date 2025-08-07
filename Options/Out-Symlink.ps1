function Out-Symlink {
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
        [Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Host "Ce script doit être exécuté en tant qu'administrateur."
        pause
        exit
    }

    $usersPath = "C:\Users"
    $htmlTempPath = Join-Path $env:TEMP "Out-Symlink-Report.html"
    $timestamp = Get-Date -Format 'yyyy-MM-dd_HHmmss'
    $logFolder = Join-Path $PSScriptRoot "..\Logs"
    $htmlLogPath = Join-Path $logFolder "Out-Symlink_$timestamp.html"
    $batLogPath = Join-Path $logFolder "Out-Symlink_$timestamp.bat"

    # Logo en base64
    $logoPath = Join-Path $PSScriptRoot "..\Images\logo.png"
    $logoData = ""
    if (Test-Path $logoPath) {
        $bytes = [System.IO.File]::ReadAllBytes($logoPath)
        $base64 = [Convert]::ToBase64String($bytes)
        $logoData = "data:image/png;base64,$base64"
    }

    New-Item -ItemType Directory -Path $logFolder -Force | Out-Null

    $totalUsers = 0; $total = 0; $ok = 0; $ko = 0; $invalid = 0; $missing = 0; $multiOst = 0
    $multiOstPaths = @(); $mklinkCommands = @()
    $exclude = @("Default", "Default User", "Public", "All Users", "desktop.ini", "WDAGUtilityAccount", "Administrator", "DefaultAppPool", "zabbix")

    $html = @"
<!DOCTYPE html>
<html lang='fr'>
<head>
<meta charset='utf-8'>
<title>Rapport Symlinks Outlook</title>
<style>
body { font-family: sans-serif; margin: 20px; }
h1, h2, h3 { color: #003366; }
img.logo { display: block; margin: 20px auto; max-width: 400px; }
.ok { color: green; }
.ko { color: red; }
.note { color: orange; }
table { border-collapse: collapse; width: 100%; margin-top: 20px; }
td, th { border: 1px solid #ddd; padding: 8px; }
th { background-color: #f2f2f2; }
pre { background-color: #f8f8f8; padding: 10px; border: 1px solid #ddd; white-space: pre-wrap; }
</style>
</head>
<body>
"@

    if ($logoData) {
        $html += "<img src='$logoData' alt='Logo Convergence' class='logo' />"
    }

    $html += "<h1>Rapport de vérification des symlinks Outlook</h1>"
    $html += "<table><tr><th>Utilisateur</th><th>État</th><th>Détails</th><th>Dossier</th></tr>"

    Get-ChildItem $usersPath -Directory -Force | ForEach-Object {
        $user = $_.Name
        if ($exclude -contains $user) { return }

        $totalUsers++
        $outlookPath = "$usersPath\$user\AppData\Local\Microsoft\Outlook"
        $expectedTarget = "D:\USERS\$user\Outlook"
        $mklinkCommands += "mklink /D `"$outlookPath`" `"$expectedTarget`""

        try {
            $sid = (New-Object System.Security.Principal.NTAccount($user)).Translate([System.Security.Principal.SecurityIdentifier])
            $fullName = $sid.Translate([System.Security.Principal.NTAccount]).Value
        } catch { $fullName = $user }

        $link = ""
        if (Test-Path $expectedTarget) {
            $safePath = $expectedTarget.Replace('\', '/')
            $link = "<a href='file:///$safePath'>Ouvrir</a>"
        }

        if (Test-Path $outlookPath) {
            $total++
            $item = Get-Item $outlookPath -Force
            if (-not ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
                $html += "<tr><td>$fullName</td><td class='ko'>KO</td><td>Pas de symlink vers D:\USERS</td><td>$link</td></tr>`n"
                $ko++
            } else {
                $target = $item.Target
                if ($target -ne $expectedTarget) {
                    $html += "<tr><td>$fullName</td><td class='ko'>KO</td><td>Lien vers '$target' au lieu de '$expectedTarget'</td><td>$link</td></tr>`n"
                    $invalid++; $ko++
                } elseif (-not (Test-Path $target)) {
                    $html += "<tr><td>$fullName</td><td class='ko'>KO</td><td>La cible '$target' est absente</td><td></td></tr>`n"
                    $missing++; $ko++
                } else {
                    $html += "<tr><td>$fullName</td><td class='ok'>OK</td><td>Lien valide vers '$target'</td><td>$link</td></tr>`n"
                    $ok++
                    try {
                        $ostFiles = Get-ChildItem -Path $target -Filter *.ost -ErrorAction SilentlyContinue
                        if ($ostFiles.Count -gt 1) {
                            $multiOst++
                            $multiOstPaths += $target
                            $html += "<tr><td colspan='4' class='note'>[$fullName] : $($ostFiles.Count) fichiers OST détectés :</td></tr>`n"
                            foreach ($f in $ostFiles | Sort-Object Length -Descending) {
                                $size = [math]::Round($f.Length / 1MB, 1)
                                $noteClass = if ($size -ge 200) { "ko" } else { "note" }
                                $html += "<tr><td colspan='4' class='$noteClass'>- $($f.Name) : $size Mo</td></tr>`n"
                            }
                        }
                    } catch {}
                }
            }
        } else {
            $html += "<tr><td>$fullName</td><td class='note'>INFO</td><td>Aucun dossier Outlook détecté</td><td></td></tr>`n"
        }
    }

    $html += "</table>`n"
    $html += "<h2>Résumé</h2><ul>`n"
    $html += "<li>Profils utilisateurs détectés : <strong>$totalUsers</strong></li>`n"
    $html += "<li>Avec dossier Outlook : <strong>$total</strong></li>`n"
    $html += "<li><span class='ok'>OK</span> : $ok</li>`n"
    $html += "<li><span class='ko'>KO (pas de lien)</span> : $($ko - $invalid - $missing)</li>`n"
    $html += "<li><span class='ko'>KO (mauvais lien)</span> : $invalid</li>`n"
    $html += "<li><span class='ko'>KO (cible absente)</span> : $missing</li>`n"
    $html += "<li><span class='note'>Multi fichiers OST</span> : $multiOst</li>`n"
    $html += "</ul>`n"
    $html += "<h3>Commandes mklink proposées</h3><pre>" + ($mklinkCommands -join "`r`n") + "</pre>`n"
    $html += "</body></html>"

    $html | Out-File -Encoding utf8 -FilePath $htmlTempPath -Force
    $html | Out-File -Encoding utf8 -FilePath $htmlLogPath -Force
    $mklinkCommands -join "`r`n" | Out-File -Encoding ascii -FilePath $batLogPath -Force

    Start-Process $htmlTempPath
}