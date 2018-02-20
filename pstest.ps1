$file = "C:\test.txt"

Try {
    If (!(Test-Path $file)) {
        New-Item $file -ItemType file
        Write-Host "Created new file and text content added"
        Add-Content -Path $file -Value "$((Get-Date).ToString('MM/dd/yyyy HH:mm:ss')) $(Get-Random -Maximum 10)"
    } Else {
        Add-Content -Path $file -Value "$((Get-Date).ToString('MM/dd/yyyy HH:mm:ss')) $(Get-Random -Maximum 10)"
        Write-Host "File already exists and new text content added"
    }
}
Catch {
    $ErrorMessage = $_.Exception.Message
    Write-Host $ErrorMessage
    Exit -1
}
