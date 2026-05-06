Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$script:sourceFile = $null
$script:intermediateXzFile = $null
$script:finalMp4File = $null

function Find-Bandizip {
    $paths = @(
        "${env:ProgramFiles}\Bandizip\Bandizip.exe",
        "${env:ProgramFiles(x86)}\Bandizip\Bandizip.exe",
        "${env:LocalAppData}\Programs\Bandizip\Bandizip.exe",
        "${env:LocalAppData}\Microsoft\WindowsApps\Bandizip.exe"
    )
    foreach ($p in $paths) {
        if (Test-Path $p) { return $p }
    }
    return $null
}

function Update-Status {
    param([string]$Text)
    $lblStatus.Text = $Text
    $form.Refresh()
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "B站Yuki_114514资源解压工具"
$form.Size = New-Object System.Drawing.Size(620, 320)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false

$lblFile = New-Object System.Windows.Forms.Label
$lblFile.Location = New-Object System.Drawing.Point(20, 20)
$lblFile.Size = New-Object System.Drawing.Size(80, 25)
$lblFile.Text = "选择文件:"
$lblFile.TextAlign = "MiddleLeft"
$form.Controls.Add($lblFile)

$txtFile = New-Object System.Windows.Forms.TextBox
$txtFile.Location = New-Object System.Drawing.Point(100, 20)
$txtFile.Size = New-Object System.Drawing.Size(380, 25)
$txtFile.ReadOnly = $true
$form.Controls.Add($txtFile)

$btnBrowse = New-Object System.Windows.Forms.Button
$btnBrowse.Location = New-Object System.Drawing.Point(490, 18)
$btnBrowse.Size = New-Object System.Drawing.Size(90, 30)
$btnBrowse.Text = "浏览..."
$btnBrowse.Add_Click({
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Filter = "LZ4 文件 (*.lz4)|*.lz4|所有文件 (*.*)|*.*"
    $dlg.Title = "选择 LZ4 文件"
    if ($dlg.ShowDialog() -eq "OK") {
        $txtFile.Text = $dlg.FileName
        $script:sourceFile = $dlg.FileName
        $script:intermediateXzFile = $null
        $script:finalMp4File = $null
        Update-Status "已选择文件，点击"解压"开始"
    }
})
$form.Controls.Add($btnBrowse)

$btnExtract = New-Object System.Windows.Forms.Button
$btnExtract.Location = New-Object System.Drawing.Point(100, 70)
$btnExtract.Size = New-Object System.Drawing.Size(150, 40)
$btnExtract.Text = "解压"
$btnExtract.Font = New-Object System.Drawing.Font("微软雅黑", 10, [System.Drawing.FontStyle]::Bold)
$btnExtract.Add_Click({
    if (-not $script:sourceFile) {
        [System.Windows.Forms.MessageBox]::Show("请先选择一个 LZ4 文件", "提示", "OK", "Information")
        return
    }

    $bandizip = Find-Bandizip
    if (-not $bandizip) {
        [System.Windows.Forms.MessageBox]::Show("未找到 Bandizip，请确认已安装", "错误", "OK", "Error")
        return
    }

    $sourceDir = [System.IO.Path]::GetDirectoryName($script:sourceFile)
    $sourceName = [System.IO.Path]::GetFileNameWithoutExtension($script:sourceFile)

    try {
        $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        $btnExtract.Enabled = $false
        $btnDelete.Enabled = $false

        Update-Status "正在解压 LZ4 ..."
        $proc = Start-Process -FilePath $bandizip -ArgumentList "x", "-o:`"$sourceDir`"", "-y", "`"$($script:sourceFile)`"" -Wait -PassThru -NoNewWindow
        if ($proc.ExitCode -ne 0) {
            throw "Bandizip 解压 LZ4 失败，退出码: $($proc.ExitCode)"
        }

        $extractedFile = [System.IO.Path]::Combine($sourceDir, $sourceName)
        if (-not (Test-Path $extractedFile)) {
            $possibleFiles = Get-ChildItem -Path $sourceDir -Filter "$sourceName*" -File | Where-Object { $_.FullName -ne $script:sourceFile }
            if ($possibleFiles.Count -eq 1) {
                $extractedFile = $possibleFiles[0].FullName
            } else {
                throw "未找到解压后的文件: $extractedFile"
            }
        }

        $xzFile = $extractedFile + ".xz"
        Update-Status "重命名为 .xz ..."
        Rename-Item -Path $extractedFile -NewName ([System.IO.Path]::GetFileName($xzFile)) -Force
        $script:intermediateXzFile = $xzFile

        Update-Status "正在解压 XZ ..."
        $proc = Start-Process -FilePath $bandizip -ArgumentList "x", "-o:`"$sourceDir`"", "-y", "`"$xzFile`"" -Wait -PassThru -NoNewWindow
        if ($proc.ExitCode -ne 0) {
            throw "Bandizip 解压 XZ 失败，退出码: $($proc.ExitCode)"
        }

        $xzNameWithoutExt = [System.IO.Path]::GetFileNameWithoutExtension($xzFile)
        $decompressedFile = [System.IO.Path]::Combine($sourceDir, $xzNameWithoutExt)
        if (-not (Test-Path $decompressedFile)) {
            $possibleFiles = Get-ChildItem -Path $sourceDir -Filter "$xzNameWithoutExt*" -File | Where-Object { $_.FullName -ne $xzFile }
            if ($possibleFiles.Count -eq 1) {
                $decompressedFile = $possibleFiles[0].FullName
            } else {
                throw "未找到 XZ 解压后的文件: $decompressedFile"
            }
        }

        $mp4File = $decompressedFile + ".mp4"
        Update-Status "重命名为 .mp4 ..."
        Rename-Item -Path $decompressedFile -NewName ([System.IO.Path]::GetFileName($mp4File)) -Force
        $script:finalMp4File = $mp4File

        Update-Status "解压完成！输出: $([System.IO.Path]::GetFileName($mp4File))"
        [System.Windows.Forms.MessageBox]::Show("解压完成！`n输出文件: $mp4File", "完成", "OK", "Information")
    }
    catch {
        Update-Status "错误: $_"
        [System.Windows.Forms.MessageBox]::Show("解压过程中出错:`n$_", "错误", "OK", "Error")
    }
    finally {
        $form.Cursor = [System.Windows.Forms.Cursors]::Default
        $btnExtract.Enabled = $true
        $btnDelete.Enabled = $true
    }
})
$form.Controls.Add($btnExtract)

$btnDelete = New-Object System.Windows.Forms.Button
$btnDelete.Location = New-Object System.Drawing.Point(280, 70)
$btnDelete.Size = New-Object System.Drawing.Size(150, 40)
$btnDelete.Text = "删除源/过程文件"
$btnDelete.Font = New-Object System.Drawing.Font("微软雅黑", 10, [System.Drawing.FontStyle]::Bold)
$btnDelete.ForeColor = [System.Drawing.Color]::Crimson
$btnDelete.Add_Click({
    $filesToDelete = @()
    if ($script:sourceFile -and (Test-Path $script:sourceFile)) {
        $filesToDelete += $script:sourceFile
    }
    if ($script:intermediateXzFile -and (Test-Path $script:intermediateXzFile)) {
        $filesToDelete += $script:intermediateXzFile
    }

    if ($filesToDelete.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("没有可删除的源文件或过程文件", "提示", "OK", "Information")
        return
    }

    $fileList = ($filesToDelete | ForEach-Object { "  - $_" }) -join "`n"
    $result = [System.Windows.Forms.MessageBox]::Show("确认删除以下文件？`n$fileList`n`n（最终 MP4 文件将保留）", "确认删除", "YesNo", "Question", "DefaultButton2")
    if ($result -ne "Yes") { return }

    $deleted = @()
    $failed = @()
    foreach ($f in $filesToDelete) {
        try {
            Remove-Item -Path $f -Force
            $deleted += $f
        }
        catch {
            $failed += $f
        }
    }

    $msg = ""
    if ($deleted.Count -gt 0) {
        $msg += "已删除:`n" + (($deleted | ForEach-Object { "  - $_" }) -join "`n")
    }
    if ($failed.Count -gt 0) {
        $msg += "`n删除失败:`n" + (($failed | ForEach-Object { "  - $_" }) -join "`n")
    }

    if ($deleted.Count -gt 0) {
        Update-Status "已删除源文件和过程文件"
    }

    [System.Windows.Forms.MessageBox]::Show($msg, "删除结果", "OK", "Information")
})
$form.Controls.Add($btnDelete)

$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Location = New-Object System.Drawing.Point(20, 140)
$lblStatus.Size = New-Object System.Drawing.Size(560, 60)
$lblStatus.Text = "请选择一个 .lz4 文件开始解压"
$lblStatus.BorderStyle = "Fixed3D"
$lblStatus.TextAlign = "MiddleLeft"
$form.Controls.Add($lblStatus)

$lblInfo = New-Object System.Windows.Forms.Label
$lblInfo.Location = New-Object System.Drawing.Point(20, 220)
$lblInfo.Size = New-Object System.Drawing.Size(560, 50)
$lblInfo.Text = "流程: .lz4 → Bandizip解压 → 加.xz后缀 → Bandizip解压 → 加.mp4后缀`n删除按钮仅删除源.lz4文件和中间.xz文件，保留最终.mp4"
$lblInfo.ForeColor = [System.Drawing.Color]::Gray
$form.Controls.Add($lblInfo)

$form.ShowDialog()
