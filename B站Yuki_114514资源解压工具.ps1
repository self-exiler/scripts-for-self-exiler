#Requires -Version 5.1

$script:bandizipPath = $null
$script:SelectedFolder = $null
$script:LogFile = Join-Path $env:TEMP "FileDecompressor_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$script:IsProcessing = $false

function Write-Log {
    param(
        [Parameter(Mandatory=$true)][string]$Message,
        [ValidateSet('Info','Success','Warning','Error')]
        [string]$Level = 'Info'
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Add-Content -Path $script:LogFile -Value $logEntry -Encoding UTF8 -ErrorAction SilentlyContinue
    if ($script:txtStatus -ne $null -and $script:txtStatus.Handle -ne [IntPtr]::Zero) {
        try {
            $script:txtStatus.AppendText("$logEntry`r`n")
            $script:txtStatus.SelectionStart = $script:txtStatus.Text.Length
            $script:txtStatus.ScrollToCaret()
            [System.Windows.Forms.Application]::DoEvents()
        }
        catch {}
    }
    else {
        Write-Host $logEntry
    }
}

function Invoke-DoEvents {
    [System.Windows.Forms.Application]::DoEvents()
    Start-Sleep -Milliseconds 10
}

function Find-bandizip {
    $bandizipInPath = Get-Command 'bandizip.exe' -ErrorAction SilentlyContinue
    if ($bandizipInPath) {
        return $bandizipInPath.Source
    }
    $commonPaths = @(
        'C:\Program Files\Bandizip\bandizip.exe',
        'C:\Program Files (x86)\Bandizip\bandizip.exe'
    )
    foreach ($path in $commonPaths) {
        if (Test-Path $path) {
            return $path
        }
    }
    return $null
}

function Select-bandizipManually {
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Title = 'Select bandizip.exe'
    $dialog.Filter = 'Executable files (*.exe)|*.exe|All files (*.*)|*.*'
    $dialog.InitialDirectory = 'C:\Program Files'
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        if (Test-Path $dialog.FileName) {
            return $dialog.FileName
        }
    }
    return $null
}

function Configure-bandizip {
    $script:bandizipPath = Find-bandizip
    if ($null -eq $script:bandizipPath) {
        $msg = 'bandizip not detected. Select bandizip.exe manually?'
        $result = [System.Windows.Forms.MessageBox]::Show(
            $msg,
            'bandizip Not Found',
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
            $script:bandizipPath = Select-bandizipManually
            if ($null -eq $script:bandizipPath) {
                [System.Windows.Forms.MessageBox]::Show(
                    'bandizip.exe required to continue.',
                    'Error',
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Error
                )
                exit
            }
        }
        else {
            [System.Windows.Forms.MessageBox]::Show(
                'bandizip not configured.',
                'Error',
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
            exit
        }
    }
}

function Invoke-DecompressWithbandizip {
    param(
        [Parameter(Mandatory=$true)][string]$InputFile,
        [Parameter(Mandatory=$true)][string]$OutputDir
    )
    try {
        $arguments = "x -o:`"$OutputDir`" `"$InputFile`""
        $process = Start-Process -FilePath $script:bandizipPath `
            -ArgumentList $arguments `
            -NoNewWindow `
            -Wait `
            -PassThru
        return $process.ExitCode
    }
    catch {
        Write-Log "Error executing bandizip: $_" 'Error'
        return -1
    }
}

function Invoke-ProcessFile {
    param(
        [Parameter(Mandatory=$true)][System.IO.FileInfo]$Lz4File
    )
    $result = @{
        Success      = $false
        Lz4File      = $Lz4File.FullName
        Mp4File      = $null
        ErrorMessage = $null
    }
    try {
        $targetDir = $Lz4File.DirectoryName
        $baseNameWithoutLz4 = $Lz4File.BaseName
        Write-Log "[1/4] Decompressing: $($Lz4File.Name)" 'Info'
        $exitCode = Invoke-DecompressWithbandizip -InputFile $Lz4File.FullName -OutputDir $targetDir
        Invoke-DoEvents
        if ($exitCode -ne 0) {
            $result.ErrorMessage = "Failed to decompress .lz4 file (exit code: $exitCode)"
            Write-Log "FAILED: $($result.ErrorMessage)" 'Error'
            return $result
        }
        $decompressedLz4 = Join-Path $targetDir $baseNameWithoutLz4
        if (-not (Test-Path $decompressedLz4)) {
            $result.ErrorMessage = "Decompressed file not found: $decompressedLz4"
            Write-Log "FAILED: $($result.ErrorMessage)" 'Error'
            return $result
        }
        Write-Log "[2/4] Renaming to .xz: $baseNameWithoutLz4" 'Info'
        $xzFile = "$decompressedLz4.xz"
        if (Test-Path $xzFile) {
            Remove-Item -Path $xzFile -Force -ErrorAction SilentlyContinue
        }
        Rename-Item -Path $decompressedLz4 -NewName (Split-Path $xzFile -Leaf) -Force
        Invoke-DoEvents
        Write-Log "[3/4] Decompressing: $(Split-Path $xzFile -Leaf)" 'Info'
        $exitCode = Invoke-DecompressWithbandizip -InputFile $xzFile -OutputDir $targetDir
        Invoke-DoEvents
        if ($exitCode -ne 0) {
            $result.ErrorMessage = "Failed to decompress .xz file (exit code: $exitCode)"
            Write-Log "FAILED: $($result.ErrorMessage)" 'Error'
            return $result
        }
        $baseNameWithoutXz = [System.IO.Path]::GetFileNameWithoutExtension($xzFile)
        $decompressedXz = Join-Path $targetDir $baseNameWithoutXz
        if (-not (Test-Path $decompressedXz)) {
            $result.ErrorMessage = "Decompressed .xz file not found: $decompressedXz"
            Write-Log "FAILED: $($result.ErrorMessage)" 'Error'
            return $result
        }
        Write-Log "[4/4] Renaming to .mp4: $baseNameWithoutXz" 'Info'
        $mp4File = "$decompressedXz.mp4"
        if (Test-Path $mp4File) {
            Remove-Item -Path $mp4File -Force -ErrorAction SilentlyContinue
        }
        Rename-Item -Path $decompressedXz -NewName (Split-Path $mp4File -Leaf) -Force
        Invoke-DoEvents
        $result.Mp4File = $mp4File
        $result.Success = $true
        Write-Log "COMPLETED: $($Lz4File.Name) -> $(Split-Path $mp4File -Leaf)" 'Success'
    }
    catch {
        $result.ErrorMessage = "Exception during processing: $_"
        Write-Log $result.ErrorMessage 'Error'
    }
    return $result
}

function Invoke-DeleteFiles {
    if ($null -eq $script:SelectedFolder -or -not (Test-Path $script:SelectedFolder)) {
        [System.Windows.Forms.MessageBox]::Show(
            'Select target folder first!',
            'Warning',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        return
    }
    $lz4Files = Get-ChildItem -Path $script:SelectedFolder -Filter '*.lz4' -Recurse -File -ErrorAction SilentlyContinue
    $xzFiles = Get-ChildItem -Path $script:SelectedFolder -Filter '*.xz' -Recurse -File -ErrorAction SilentlyContinue
    $allFiles = @()
    if ($lz4Files) { $allFiles += @($lz4Files) }
    if ($xzFiles) { $allFiles += @($xzFiles) }
    if ($allFiles.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show(
            'No .lz4 or .xz files found.',
            'Info',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )
        return
    }
    $totalSize = ($allFiles | Measure-Object -Property Length -Sum).Sum
    $sizeText = Format-FileSize $totalSize
    $lz4Count = if ($lz4Files) { @($lz4Files).Count } else { 0 }
    $xzCount = if ($xzFiles) { @($xzFiles).Count } else { 0 }
    $totalCount = $allFiles.Count
    $confirmMessage = "Delete following files:`n`n.lz4: $lz4Count`n.xz: $xzCount`nTotal: $totalCount files, Size: $sizeText`n`nContinue?"
    $result = [System.Windows.Forms.MessageBox]::Show(
        $confirmMessage,
        'Confirm Delete',
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    )
    if ($result -ne [System.Windows.Forms.DialogResult]::Yes) {
        Write-Log 'User cancelled delete operation' 'Info'
        return
    }
    $deletedCount = 0
    $errorCount = 0
    foreach ($file in $allFiles) {
        try {
            Remove-Item -Path $file.FullName -Force
            $deletedCount++
            Write-Log "Deleted: $($file.FullName)" 'Success'
            Invoke-DoEvents
        }
        catch {
            $errorCount++
            Write-Log "Failed to delete: $($file.FullName) - $_" 'Error'
            Invoke-DoEvents
        }
    }
    [System.Windows.Forms.MessageBox]::Show(
        "Delete completed!`n`nDeleted: $deletedCount files`nFailed: $errorCount files",
        'Delete Result',
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    )
    Write-Log "Delete operation completed: $deletedCount succeeded, $errorCount failed" 'Info'
}

function Format-FileSize {
    param([long]$Bytes)
    if ($null -eq $Bytes) { return '0 bytes' }
    if ($Bytes -ge 1GB) { return '{0:F2} GB' -f ($Bytes / 1GB) }
    elseif ($Bytes -ge 1MB) { return '{0:F2} MB' -f ($Bytes / 1MB) }
    elseif ($Bytes -ge 1KB) { return '{0:F2} KB' -f ($Bytes / 1KB) }
    else { return "$Bytes bytes" }
}

function Invoke-ProcessFiles {
    if ($script:IsProcessing) {
        [System.Windows.Forms.MessageBox]::Show(
            'Processing in progress...',
            'Notice',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )
        return
    }
    if ($null -eq $script:SelectedFolder -or -not (Test-Path $script:SelectedFolder)) {
        [System.Windows.Forms.MessageBox]::Show(
            'Select target folder first!',
            'Warning',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        return
    }
    $script:IsProcessing = $true
    $btnDecompress.Enabled = $false
    $btnDelete.Enabled = $false
    $btnBrowse.Enabled = $false
    $txtStatus.Clear()
    $progressBar.Value = 0
    Invoke-DoEvents
    try {
        Write-Log "Scanning folder: $($script:SelectedFolder)" 'Info'
        Invoke-DoEvents
        $lz4Files = Get-ChildItem -Path $script:SelectedFolder -Filter '*.lz4' -Recurse -File -ErrorAction SilentlyContinue
        if ($null -eq $lz4Files -or $lz4Files.Count -eq 0) {
            Write-Log 'No .lz4 files found' 'Warning'
            [System.Windows.Forms.MessageBox]::Show(
                'No .lz4 files found in selected folder.',
                'Notice',
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            )
            return
        }
        $totalFiles = @($lz4Files).Count
        Write-Log "Found $totalFiles .lz4 files, starting processing..." 'Info'
        Invoke-DoEvents
        $processedCount = 0
        $successCount = 0
        $failedCount = 0
        $startTime = Get-Date
        foreach ($file in @($lz4Files)) {
            $processedCount++
            $progress = [math]::Round((($processedCount - 1) / $totalFiles) * 100)
            $progressBar.Value = $progress
            Write-Log "Progress: $processedCount/$totalFiles - $($file.Name)" 'Info'
            Invoke-DoEvents
            $result = Invoke-ProcessFile -Lz4File $file
            if ($result.Success) {
                $successCount++
            }
            else {
                $failedCount++
            }
        }
        $elapsed = (Get-Date) - $startTime
        $timeText = '{0:mm}:{1:ss}' -f $elapsed.Minutes, $elapsed.Seconds
        $progressBar.Value = 100
        Invoke-DoEvents
        $summary = "`n========== Processing Complete ==========`nTotal: $totalFiles`nSuccess: $successCount`nFailed: $failedCount`nTime: $timeText`n====================================="
        Write-Log $summary 'Success'
        $openResult = [System.Windows.Forms.MessageBox]::Show(
            "Processing complete!`nSuccess: $successCount, Failed: $failedCount, Time: $timeText`n`nOpen output folder?",
            'Processing Complete',
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )
        if ($openResult -eq [System.Windows.Forms.DialogResult]::Yes) {
            Start-Process $script:SelectedFolder
        }
    }
    catch {
        Write-Log "Fatal error during processing: $_" 'Error'
        [System.Windows.Forms.MessageBox]::Show(
            "Error during processing: $_",
            'Error',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
    }
    finally {
        $btnDecompress.Enabled = $true
        $btnDelete.Enabled = $true
        $btnBrowse.Enabled = $true
        $script:IsProcessing = $false
        Invoke-DoEvents
    }
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$form = New-Object System.Windows.Forms.Form
$form.Text = 'File Decompressor'
$form.Size = New-Object System.Drawing.Size(800, 600)
$form.MinimumSize = New-Object System.Drawing.Size(800, 600)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.Icon = [System.Drawing.SystemIcons]::Application

$topPanel = New-Object System.Windows.Forms.Panel
$topPanel.Location = New-Object System.Drawing.Point(10, 10)
$topPanel.Size = New-Object System.Drawing.Size(760, 60)
$topPanel.BorderStyle = 'FixedSingle'

$lblFolder = New-Object System.Windows.Forms.Label
$lblFolder.Text = 'Target Folder:'
$lblFolder.Location = New-Object System.Drawing.Point(10, 20)
$lblFolder.Size = New-Object System.Drawing.Size(90, 23)
$lblFolder.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)

$txtFolder = New-Object System.Windows.Forms.TextBox
$txtFolder.Location = New-Object System.Drawing.Point(100, 17)
$txtFolder.Size = New-Object System.Drawing.Size(500, 23)
$txtFolder.ReadOnly = $true
$txtFolder.Font = New-Object System.Drawing.Font('Consolas', 9)
$txtFolder.BackColor = [System.Drawing.Color]::LightYellow

$btnBrowse = New-Object System.Windows.Forms.Button
$btnBrowse.Text = 'Browse...'
$btnBrowse.Location = New-Object System.Drawing.Point(610, 15)
$btnBrowse.Size = New-Object System.Drawing.Size(80, 28)
$btnBrowse.Font = New-Object System.Drawing.Font('Segoe UI', 9)
$btnBrowse.BackColor = [System.Drawing.Color]::LightBlue
$btnBrowse.Cursor = [System.Windows.Forms.Cursors]::Hand

$middlePanel = New-Object System.Windows.Forms.Panel
$middlePanel.Location = New-Object System.Drawing.Point(10, 80)
$middlePanel.Size = New-Object System.Drawing.Size(760, 60)
$middlePanel.BorderStyle = 'FixedSingle'

$btnDecompress = New-Object System.Windows.Forms.Button
$btnDecompress.Text = 'Start Decompress'
$btnDecompress.Location = New-Object System.Drawing.Point(100, 15)
$btnDecompress.Size = New-Object System.Drawing.Size(150, 35)
$btnDecompress.Font = New-Object System.Drawing.Font('Segoe UI', 11, [System.Drawing.FontStyle]::Bold)
$btnDecompress.BackColor = [System.Drawing.Color]::LightGreen
$btnDecompress.ForeColor = [System.Drawing.Color]::DarkGreen
$btnDecompress.Cursor = [System.Windows.Forms.Cursors]::Hand
$btnDecompress.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat

$btnDelete = New-Object System.Windows.Forms.Button
$btnDelete.Text = 'Delete Original'
$btnDelete.Location = New-Object System.Drawing.Point(300, 15)
$btnDelete.Size = New-Object System.Drawing.Size(150, 35)
$btnDelete.Font = New-Object System.Drawing.Font('Segoe UI', 11, [System.Drawing.FontStyle]::Bold)
$btnDelete.BackColor = [System.Drawing.Color]::LightCoral
$btnDelete.ForeColor = [System.Drawing.Color]::DarkRed
$btnDelete.Cursor = [System.Windows.Forms.Cursors]::Hand
$btnDelete.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat

$btnViewLog = New-Object System.Windows.Forms.Button
$btnViewLog.Text = 'View Log'
$btnViewLog.Location = New-Object System.Drawing.Point(500, 15)
$btnViewLog.Size = New-Object System.Drawing.Size(120, 35)
$btnViewLog.Font = New-Object System.Drawing.Font('Segoe UI', 10)
$btnViewLog.BackColor = [System.Drawing.Color]::LightGray
$btnViewLog.Cursor = [System.Windows.Forms.Cursors]::Hand
$btnViewLog.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat

$bottomPanel = New-Object System.Windows.Forms.Panel
$bottomPanel.Location = New-Object System.Drawing.Point(10, 150)
$bottomPanel.Size = New-Object System.Drawing.Size(760, 400)
$bottomPanel.BorderStyle = 'FixedSingle'

$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(10, 15)
$progressBar.Size = New-Object System.Drawing.Size(740, 25)
$progressBar.Minimum = 0
$progressBar.Maximum = 100

$txtStatus = New-Object System.Windows.Forms.TextBox
$txtStatus.Location = New-Object System.Drawing.Point(10, 50)
$txtStatus.Size = New-Object System.Drawing.Size(740, 330)
$txtStatus.Multiline = $true
$txtStatus.ScrollBars = 'Vertical'
$txtStatus.ReadOnly = $true
$txtStatus.Font = New-Object System.Drawing.Font('Consolas', 9)
$txtStatus.BackColor = [System.Drawing.Color]::White
$txtStatus.WordWrap = $false

$btnBrowse.Add_Click({
    $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderBrowser.Description = 'Select target folder'
    $folderBrowser.ShowNewFolderButton = $false
    if ($folderBrowser.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $script:SelectedFolder = $folderBrowser.SelectedPath
        $txtFolder.Text = $folderBrowser.SelectedPath
        Write-Log "Selected folder: $($script:SelectedFolder)" 'Success'
    }
})

$btnDecompress.Add_Click({
    Invoke-ProcessFiles
})

$btnDelete.Add_Click({
    Invoke-DeleteFiles
})

$btnViewLog.Add_Click({
    if (Test-Path $script:LogFile) {
        Start-Process 'notepad.exe' -ArgumentList "`"$($script:LogFile)`""
    }
    else {
        [System.Windows.Forms.MessageBox]::Show(
            'Log file not created yet.',
            'Notice',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )
    }
})

$topPanel.Controls.Add($lblFolder)
$topPanel.Controls.Add($txtFolder)
$topPanel.Controls.Add($btnBrowse)
$middlePanel.Controls.Add($btnDecompress)
$middlePanel.Controls.Add($btnDelete)
$middlePanel.Controls.Add($btnViewLog)
$bottomPanel.Controls.Add($progressBar)
$bottomPanel.Controls.Add($txtStatus)
$form.Controls.Add($topPanel)
$form.Controls.Add($middlePanel)
$form.Controls.Add($bottomPanel)

$script:txtStatus = $txtStatus
$script:progressBar = $progressBar

try {
    Configure-bandizip
    Write-Log '========================================' 'Info'
    Write-Log 'File Decompressor' 'Info'
    Write-Log "bandizip: $($script:bandizipPath)" 'Info'
    Write-Log "Log: $($script:LogFile)" 'Info'
    Write-Log '========================================' 'Info'
    Write-Log 'Select target folder and click Start Decompress.' 'Info'
    [System.Windows.Forms.Application]::EnableVisualStyles()
    [System.Windows.Forms.Application]::Run($form)
}
catch {
    Write-Host "Fatal error: $_" -ForegroundColor Red
    [System.Windows.Forms.MessageBox]::Show(
        "Application failed to start: $_",
        'Fatal Error',
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    )
    exit 1
}