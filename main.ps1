# Project: Boîte à outils PowerShell
# Structure:
#   /BoiteOutils
#     Main.ps1       # Script principal : interface GUI interactive
#     /Options        # Dossier des scripts d'options

# Main.ps1
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Détermination des chemins
$scriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Definition
$optionsDir = Join-Path -Path $scriptDir -ChildPath 'Options'

# Vérifier que le dossier existe
if (-not (Test-Path -Path $optionsDir)) {
    [System.Windows.Forms.MessageBox]::Show("Le dossier d'options n'a pas été trouvé : $optionsDir", 'Erreur', 'OK', 'Error')
    exit
}

# Chargement des scripts d'options
Get-ChildItem -Path $optionsDir -Filter '*.ps1' | ForEach-Object { . $_.FullName }

# Récupération des noms d'options à partir des fichiers
$optionNames = Get-ChildItem -Path $optionsDir -Filter '*.ps1' | ForEach-Object { $_.BaseName }

# Création du formulaire
$form = New-Object System.Windows.Forms.Form
$form.Text = 'Boîte à outils PowerShell'
$form.Size = New-Object System.Drawing.Size(400, 500)
$form.StartPosition = 'CenterScreen'

# Liste des options
$listBox = New-Object System.Windows.Forms.ListBox
$listBox.Location = New-Object System.Drawing.Point(10, 10)
$listBox.Size = New-Object System.Drawing.Size(360, 380)
$listBox.DataSource = $optionNames
$form.Controls.Add($listBox)

# Bouton Exécuter
$btnRun = New-Object System.Windows.Forms.Button
$btnRun.Text = 'Exécuter'
$btnRun.Size = New-Object System.Drawing.Size(100, 30)
$btnRun.Location = New-Object System.Drawing.Point(80, 410)
$btnRun.Add_Click({
    if ($listBox.SelectedItem) {
        $func = $listBox.SelectedItem.ToString()
        try {
            & $func
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Erreur lors de l'exécution de $func : $($_.Exception.Message)", 'Erreur', 'OK', 'Error')
        }
    } else {
        [System.Windows.Forms.MessageBox]::Show('Veuillez sélectionner une option.', 'Avertissement', 'OK', 'Warning')
    }
})
$form.Controls.Add($btnRun)

# Bouton Quitter
$btnExit = New-Object System.Windows.Forms.Button
$btnExit.Text = 'Quitter'
$btnExit.Size = New-Object System.Drawing.Size(100, 30)
$btnExit.Location = New-Object System.Drawing.Point(220, 410)
$btnExit.Add_Click({ $form.Close() })
$form.Controls.Add($btnExit)

# Affichage de l'interface
[void]$form.ShowDialog()
