function Clear-DiskSpace {
    <#
    .SYNOPSIS
        Nettoie différents emplacements temporaires et lance l'outil Windows Cleanmgr.

    .DESCRIPTION
        Cette version harmonisée du script prend en charge un mode démo (aucune
        suppression n'est réellement effectuée) et peut recevoir une barre de progression
        Windows Forms. Elle utilise la mécanique ShouldProcess/Confirm pour offrir
        davantage de contrôle à l'utilisateur avant chaque suppression.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [switch]$DemoMode,
        [System.Windows.Forms.ProgressBar]$ProgressBar
    )

    # Liste des tâches de nettoyage à effectuer.
    $tasks = @(
        @{ Description = 'Suppression de C:\\Windows\\Temp'; Path = 'C:\\Windows\\Temp\\*' },
        @{ Description = 'Suppression de $env:TEMP';         Path = "$env:TEMP\\*" },
        @{ Description = 'Suppression de C:\\ProgramData\\Adobe\\ARM'; Path = 'C:\\ProgramData\\Adobe\\ARM\\*' }
    )

    # Calcul du pas pour la barre de progression si elle est fournie.
    $step = if ($ProgressBar) { [Math]::Floor($ProgressBar.Maximum / ($tasks.Count + 1)) } else { 0 }

    foreach ($task in $tasks) {
        $desc = $task.Description
        # La variable $task.Path peut contenir des références à des variables d'environnement.
        $path = $ExecutionContext.InvokeCommand.ExpandString($task.Path)
        Write-Log $desc

        if ($DemoMode) {
            # En mode démo, on simule la suppression sans rien toucher.
            Write-Log "MODE DÉMO : suppression simulée de $path" 'Yellow'
        } else {
            # Le mécanisme ShouldProcess offre la possibilité de confirmer la suppression.
            if ($PSCmdlet.ShouldProcess($path, $desc)) {
                try {
                    Remove-Item -Path $path -Recurse -Force -ErrorAction Stop
                } catch {
                    Write-Log "Erreur durant $desc : $_" 'Red'
                }
            }
        }

        if ($ProgressBar) {
            $ProgressBar.Value = [Math]::Min($ProgressBar.Value + $step, $ProgressBar.Maximum)
        }
    }

    # Lancement de l'outil Cleanmgr pour finir le nettoyage.
    Write-Log 'Lancement de cleanmgr'
    if (-not $DemoMode) {
        Start-Process cleanmgr.exe -ArgumentList '/sagerun:1' -WindowStyle Hidden -Wait
    } else {
        Write-Log "MODE DÉMO : lancement simulé de cleanmgr.exe" 'Yellow'
    }

    if ($ProgressBar) {
        $ProgressBar.Value = $ProgressBar.Maximum
    }
    Write-Log 'Nettoyage terminé' 'Green'
}