﻿$OutputEncoding = [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 > $null

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$bandizip = "C:\Users\dioha\AppData\Local\Microsoft\WindowsApps\bandizip.exe"

$form = New-Object System.Windows.Forms.Form
$form.Text = "B站Yuki_114514资源解压工具"
$form.Size = New-Object System.Drawing.Size(500, 380)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox = $false
$form.BackColor = [System.Drawing.Color]::WhiteSmoke

$labelDir = New-Object System.Windows.Forms.Label
$labelDir.Text = "目标目录："
$labelDir.Location = New-Object System.Drawing.Point(20, 25)
$labelDir.Size = New-Object System.Drawing.Size(80, 23)

$textBoxDir = New-Object System.Windows.Forms.TextBox
$textBoxDir.Location = New-Object System.Drawing.Point(110, 22)
$textBoxDir.Size = New-Object System.Drawing.Size(290, 23)
$textBoxDir.ReadOnly = $true

$btnBrowse = New-Object System.Windows.Forms.Button
$btnBrowse.Text = "浏览..."
$btnBrowse.Location = New-Object System.Drawing.Point(410, 20)
$btnBrowse.Size = New-Object System.Drawing.Size(60, 25)
$btnBrowse.Add_Click({
    $fileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $fileDialog.Title = "选择 .lz4 资源文件"
    $fileDialog.Filter = "LZ4文件 (*.lz4)|*.lz4|所有文件 (*.*)|*.*"
    $fileDialog.Multiselect = $true
    if ($fileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $selectedFiles = $fileDialog.FileNames
        $firstFile = $selectedFiles[0]
        $dir = [System.IO.Path]::GetDirectoryName($firstFile)
        $textBoxDir.Text = $dir
        $script:SelectedFiles = $selectedFiles
    }
})

$labelInfo = New-Object System.Windows.Forms.Label
$labelInfo.Text = "待处理文件：0 个 .lz4 文件"
$labelInfo.Location = New-Object System.Drawing.Point(20, 65)
$labelInfo.Size = New-Object System.Drawing.Size(450, 23)

$listBoxLog = New-Object System.Windows.Forms.ListBox
$listBoxLog.Location = New-Object System.Drawing.Point(20, 100)
$listBoxLog.Size = New-Object System.Drawing.Size(450, 150)
$listBoxLog.HorizontalScrollbar = $true

$btnExtract = New-Object System.Windows.Forms.Button
$btnExtract.Text = "开始解压"
$btnExtract.Location = New-Object System.Drawing.Point(80, 270)
$btnExtract.Size = New-Object System.Drawing.Size(120, 35)
$btnExtract.Font = New-Object System.Drawing.Font($btnExtract.Font.FontFamily, $btnExtract.Font.Size, [System.Drawing.FontStyle]::Bold)
$btnExtract.BackColor = [System.Drawing.Color]::LightGreen
$btnExtract.Add_Click({
    $targetDir = $textBoxDir.Text
    if (-not $targetDir -or -not (Test-Path $targetDir)) {
        [System.Windows.Forms.MessageBox]::Show("请先选择文件！", "提示", "OK", "Warning")
        return
    }

    if ($script:SelectedFiles -and $script:SelectedFiles.Count -gt 0) {
        $lz4Files = $script:SelectedFiles | ForEach-Object { Get-Item $_ }
    } else {
        $lz4Files = Get-ChildItem -Path $targetDir -Filter *.lz4
    }

    if ($lz4Files.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("当前目录下没有找到 .lz4 文件！", "提示", "OK", "Information")
        return
    }

    $btnExtract.Enabled = $false
    $listBoxLog.Items.Clear()
    $listBoxLog.Items.Add("=== 开始解压 ===")

    $count = 0
    foreach ($lz4file in $lz4Files) {
        $lz4Path = $lz4file.FullName
        $basename = [System.IO.Path]::GetFileNameWithoutExtension($lz4file.Name)
        $outdir = $lz4file.DirectoryName

        $listBoxLog.Items.Add("[$(Get-Date -Format 'HH:mm:ss')] 处理：$($lz4file.Name)")

        $result1 = & "$bandizip" x -y -o:"$outdir" "$lz4Path" 2>&1
        $noext = Join-Path $outdir $basename
        if (Test-Path $noext) {
            $zxfile = "$noext.zx"
            Rename-Item $noext $zxfile
            $listBoxLog.Items.Add("  -> 已生成 .zx 文件")

            $result2 = & "$bandizip" x -y -o:"$outdir" "$zxfile" 2>&1
            $noext2 = Join-Path $outdir $basename
            if (Test-Path $noext2) {
                $mp4file = "$noext2.mp4"
                Rename-Item $noext2 $mp4file
                $listBoxLog.Items.Add("  -> 已生成 MP4 文件：$basename.mp4")
                $count++
            } else {
                $listBoxLog.Items.Add("  [错误] 未找到第二次解压的无后缀文件：$noext2")
            }
        } else {
            $listBoxLog.Items.Add("  [错误] 未找到第一次解压的无后缀文件：$noext")
        }
    }

    $listBoxLog.Items.Add("=== 解压完成，成功处理 $count 个文件 ===")
    $listBoxLog.TopIndex = $listBoxLog.Items.Count - 1
    $btnExtract.Enabled = $true

    [System.Windows.Forms.MessageBox]::Show("解压完成！成功处理 $count 个文件。", "完成", "OK", "Information")
})

$btnDelete = New-Object System.Windows.Forms.Button
$btnDelete.Text = "删除 .lz4 和 .zx 文件"
$btnDelete.Location = New-Object System.Drawing.Point(250, 270)
$btnDelete.Size = New-Object System.Drawing.Size(160, 35)
$btnDelete.BackColor = [System.Drawing.Color]::LightCoral
$btnDelete.Add_Click({
    $targetDir = $textBoxDir.Text
    if (-not $targetDir -or -not (Test-Path $targetDir)) {
        [System.Windows.Forms.MessageBox]::Show("请先选择文件！", "提示", "OK", "Warning")
        return
    }

    $confirm = [System.Windows.Forms.MessageBox]::Show("确定要删除当前目录下所有 .lz4 和 .zx 文件吗？此操作不可撤销！", "确认删除", "YesNo", "Warning")
    if ($confirm -ne "Yes") { return }

    $listBoxLog.Items.Clear()
    $listBoxLog.Items.Add("=== 开始删除 ===")

    $deletedLz4 = 0
    $deletedZx = 0

    Get-ChildItem -Path $targetDir -Filter *.lz4 | ForEach-Object {
        Remove-Item -Force $_.FullName
        $listBoxLog.Items.Add("已删除：$($_.Name)")
        $deletedLz4++
    }

    Get-ChildItem -Path $targetDir -Filter *.zx | ForEach-Object {
        Remove-Item -Force $_.FullName
        $listBoxLog.Items.Add("已删除：$($_.Name)")
        $deletedZx++
    }

    $listBoxLog.Items.Add("=== 删除完成，已删除 $deletedLz4 个 .lz4 文件，$deletedZx 个 .zx 文件 ===")
    $listBoxLog.TopIndex = $listBoxLog.Items.Count - 1

    [System.Windows.Forms.MessageBox]::Show("删除完成！已删除 $deletedLz4 个 .lz4 文件，$deletedZx 个 .zx 文件。", "完成", "OK", "Information")
})

$btnRefresh = New-Object System.Windows.Forms.Button
$btnRefresh.Text = "刷新文件列表"
$btnRefresh.Location = New-Object System.Drawing.Point(20, 315)
$btnRefresh.Size = New-Object System.Drawing.Size(100, 25)
$btnRefresh.Add_Click({
    $targetDir = $textBoxDir.Text
    if ($targetDir -and (Test-Path $targetDir)) {
        $count = (Get-ChildItem -Path $targetDir -Filter *.lz4).Count
        $labelInfo.Text = "待处理文件：$count 个 .lz4 文件"
    }
})

$btnExit = New-Object System.Windows.Forms.Button
$btnExit.Text = "退出"
$btnExit.Location = New-Object System.Drawing.Point(370, 315)
$btnExit.Size = New-Object System.Drawing.Size(100, 25)
$btnExit.Add_Click({ $form.Close() })

$form.Controls.AddRange(@($labelDir, $textBoxDir, $btnBrowse, $labelInfo, $listBoxLog, $btnExtract, $btnDelete, $btnRefresh, $btnExit))

[void]$form.ShowDialog()
