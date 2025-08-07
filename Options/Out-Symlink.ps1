# Vérification des droits administrateur
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
    [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Ce script doit être exécuté en tant qu'administrateur."
    pause
    exit
}

$usersPath = "C:\Users"
$totalUsers = 0
$total = 0
$ok = 0
$ko = 0
$invalid = 0
$missing = 0
$multiOst = 0
$multiOstPaths = @()
$sizeThresholdMB = 200

# Dossiers à ignorer
$exclude = @(
    "Default", "Default User", "Public", "All Users", "desktop.ini",
    "WDAGUtilityAccount", "Administrator", "DefaultAppPool", "zabbix"
)

Get-ChildItem $usersPath -Directory -Force | ForEach-Object {
    $user = $_.Name
    if ($exclude -contains $user) { return }

    $totalUsers++
    $outlookPath = "$usersPath\$user\AppData\Local\Microsoft\Outlook"
    $expectedTarget = "D:\USERS\$user\Outlook"

    try {
        $sid = (New-Object System.Security.Principal.NTAccount($user)).Translate([System.Security.Principal.SecurityIdentifier])
        $fullName = $sid.Translate([System.Security.Principal.NTAccount]).Value
        $sidStr = $sid.Value
    } catch {
        $fullName = $user
        $sidStr = $null
    }

    try {
        if (Test-Path $outlookPath) {
            $total++
            $item = Get-Item $outlookPath -Force

            if (-not ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
                Write-Host "[$fullName] KO - pas de symlink vers D:\USERS"
                $ko++
            }
            else {
                $target = $item.Target

                if ($target -ne $expectedTarget) {
                    Write-Host "[$fullName] KO - lien pointe vers '$target' au lieu de '$expectedTarget'"
                    $invalid++
                    $ko++
                }
                elseif (-not (Test-Path $target)) {
                    Write-Host "[$fullName] KO - lien vers '$target' mais la cible est absente"
                    $missing++
                    $ko++
                }
                else {
                    Write-Host "[$fullName] OK - lien vers '$target'"
                    $ok++

                    # Détection des fichiers OST multiples (boîtes aux lettres additionnelles ou anciens profils)
                    try {
                        $ostFiles = Get-ChildItem -Path $target -Filter *.ost -ErrorAction SilentlyContinue
                        if ($ostFiles.Count -gt 1) {
                            $multiOst++
                            $multiOstPaths += $target
                            Write-Host "[$fullName] NOTE - $($ostFiles.Count) fichiers OST détectés (boîtes ou archives multiples ?)"

                            $ostFiles | Sort-Object Length -Descending | ForEach-Object {
                                $sizeMB = [math]::Round($_.Length / 1MB, 1)
                                if ($sizeMB -ge $sizeThresholdMB) {
                                    Write-Host "    - $($_.Name) : $sizeMB Mo  <== GROS FICHIER"
                                } else {
                                    Write-Host "    - $($_.Name) : $sizeMB Mo"
                                }
                            }
                        }
                    } catch {}
                }
            }
        } else {
            Write-Host "[$fullName] Aucun dossier Outlook détecté"
        }
    } catch {
        Write-Host "[$fullName] Ignoré - accès impossible ou profil incomplet"
    }
}

Write-Host ""
Write-Host "Profils utilisateurs détectés : $totalUsers"
Write-Host "Avec dossier Outlook        : $total"
Write-Host "   -> OK                    : $ok"
Write-Host "   -> KO (pas de lien)     : $($ko - $invalid - $missing)"
Write-Host "   -> KO (mauvais lien)    : $invalid"
Write-Host "   -> KO (cible absente)   : $missing"
Write-Host "   -> Dossiers avec plusieurs fichiers OST : $multiOst"

if ($multiOstPaths.Count -gt 0) {
    $open = Read-Host "Ouvrir les dossiers contenant plusieurs fichiers OST dans l'explorateur ? (O/N)"
    if ($open -eq 'O' -or $open -eq 'o') {
        foreach ($path in $multiOstPaths) {
            if (Test-Path $path) {
                Start-Process explorer.exe $path
            }
        }
    }
}

# Pause à la fin pour usage double-clic
Write-Host ""
Write-Host "Appuyez sur une touche pour quitter..."
cmd /c pause >$null
