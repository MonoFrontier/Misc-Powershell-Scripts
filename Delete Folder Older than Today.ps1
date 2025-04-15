# PowerShell script to delete files older than today's date in a specified folder

# Set the folder path
$folderPath = "$path"

# Get the current date
$currentDate = Get-Date

# Get all files in the folder older than today's date
$filesToDelete = Get-ChildItem -Path $folderPath | Where-Object { $_.LastWriteTime -lt $currentDate }

# Delete each file
foreach ($file in $filesToDelete) {
    try {
        Remove-Item -Path $file.FullName -Force -Recurse
        Write-Host "Deleted: $($file.FullName)"
    } catch {
        Write-Host "Error deleting $($file.FullName): $_"
    }
}

Write-Host "Deletion process completed."