function Clear-DiskSpace {
    Write-Log '1 : Suppression C:\Windows\Temp'
    Remove-Item -Path 'C:\Windows\Temp\*' -Recurse -Force -ErrorAction SilentlyContinue
    $pb.Value++

    Write-Log "2 : Suppression $env:TEMP"
    Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
    $pb.Value++

    Write-Log '3 : Suppression C:\ProgramData\Adobe\ARM'
    Remove-Item -Path 'C:\ProgramData\Adobe\ARM\*' -Recurse -Force -ErrorAction SilentlyContinue
    $pb.Value++

    Write-Log '4 : Lancement cleanmgr'
    Start-Process cleanmgr.exe -ArgumentList '/sagerun:1' -WindowStyle Hidden -Wait
    $pb.Value++
}
