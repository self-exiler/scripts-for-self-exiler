#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
B站Yuki_114514资源解压工具
解压流程: lz4 -> xz -> mp4
"""

import io
import os
import sys
import time
from concurrent.futures import ProcessPoolExecutor, as_completed
from pathlib import Path

import lz4.frame
import lzma
from PySide6.QtCore import QThread, Signal, Qt, QUrl, QFileInfo
from PySide6.QtGui import QDragEnterEvent, QDropEvent, QFont, QColor, QPalette, QIcon
from PySide6.QtWidgets import (
    QApplication, QCheckBox, QFileDialog, QGroupBox, QHBoxLayout,
    QLabel, QMainWindow, QPushButton, QProgressBar, QTextEdit, QVBoxLayout,
    QWidget, QSpinBox, QTableWidget, QTableWidgetItem,
    QHeaderView, QAbstractItemView, QMessageBox
)

BUFFER_SIZE = 8 * 1024 * 1024
WRITE_BUFFER_SIZE = 2 * 1024 * 1024
PROGRESS_UPDATE_INTERVAL = 0.3

STYLE_SHEET = """
QLabel#file_count_label {
    font-weight: bold;
}
QLabel#status_label {
    color: #666;
}
QTextEdit {
    font-family: 'Consolas', 'Courier New', monospace;
}
QPushButton#btn_start {
    font-weight: bold;
    font-size: 14px;
    min-height: 32px;
}
"""


class DragDropListWidget(QTableWidget):
    """支持拖拽的文件列表"""
    files_dropped = Signal(list)

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setAcceptDrops(True)
        self.setDragDropMode(QAbstractItemView.InternalMove)
        self.setSelectionMode(QAbstractItemView.ExtendedSelection)
        self.setColumnCount(3)
        self.setHorizontalHeaderLabels(["文件名", "大小", "状态"])
        self.horizontalHeader().setSectionResizeMode(0, QHeaderView.Stretch)
        self.horizontalHeader().setSectionResizeMode(1, QHeaderView.ResizeToContents)
        self.horizontalHeader().setSectionResizeMode(2, QHeaderView.ResizeToContents)
        self.verticalHeader().setVisible(False)
        self.setEditTriggers(QAbstractItemView.NoEditTriggers)
        self.setSelectionBehavior(QAbstractItemView.SelectRows)
        self.setAlternatingRowColors(True)

    def dragEnterEvent(self, event: QDragEnterEvent):
        if event.mimeData().hasUrls():
            event.acceptProposedAction()

    def dragMoveEvent(self, event):
        event.acceptProposedAction()

    def dropEvent(self, event: QDropEvent):
        files = []
        for url in event.mimeData().urls():
            path = url.toLocalFile()
            if path.lower().endswith('.lz4'):
                files.append(path)
        if files:
            self.files_dropped.emit(files)
        event.acceptProposedAction()


class DecompressWorker(QThread):
    log_signal = Signal(str)
    progress_signal = Signal(int)
    finished_signal = Signal(bool, str)
    file_progress_signal = Signal(str)

    def __init__(self, file_paths, delete_source, delete_intermediate, max_workers=None):
        super().__init__()
        self.file_paths = file_paths
        self.delete_source = delete_source
        self.delete_intermediate = delete_intermediate
        self.max_workers = max_workers or min(len(file_paths), os.cpu_count() or 4)

    def log(self, msg):
        self.log_signal.emit(msg)

    def stream_decompress(self, input_stream, output_file: Path,
                          progress_start: int, progress_range: int,
                          total_progress_offset: int, file_progress_scale: float,
                          input_file_size: int = 0):
        bytes_read = 0
        last_update = time.monotonic()

        with output_file.open('wb', buffering=WRITE_BUFFER_SIZE) as f_out:
            while chunk := input_stream.read(BUFFER_SIZE):
                f_out.write(chunk)
                bytes_read += len(chunk)
                now = time.monotonic()
                if now - last_update >= PROGRESS_UPDATE_INTERVAL:
                    last_update = now
                    if input_file_size > 0:
                        file_progress = int(bytes_read / input_file_size * progress_range)
                        total_progress = int(total_progress_offset + file_progress * file_progress_scale)
                        self.progress_signal.emit(min(total_progress, 100))

        if input_file_size > 0:
            total_progress = int(total_progress_offset + progress_range * file_progress_scale)
            self.progress_signal.emit(min(total_progress, 100))

    def decompress_single(self, lz4_path: Path, file_index: int, total_files: int):
        try:
            if not lz4_path.exists():
                self.log(f"[{file_index}/{total_files}] 文件不存在: {lz4_path.name}")
                return False, f"文件不存在: {lz4_path.name}"

            work_dir = lz4_path.parent
            base_name = lz4_path.stem
            xz_file = work_dir / f"{base_name}.xz"
            mp4_file = work_dir / f"{base_name}.mp4"

            if mp4_file.exists():
                self.log(f"[{file_index}/{total_files}] 目标文件已存在，跳过: {mp4_file.name}")
                return True, f"已存在: {mp4_file.name}"

            progress_offset = (file_index - 1) * (100 // total_files)
            file_scale = 1.0 / total_files

            self.log(f"[{file_index}/{total_files}] 解压 {lz4_path.name} -> {mp4_file.name}")
            start_time = time.monotonic()

            lz4_size = lz4_path.stat().st_size
            with lz4.frame.open(str(lz4_path), 'rb') as f_lz4:
                self.stream_decompress(f_lz4, xz_file, 0, 50, progress_offset, file_scale, lz4_size)

            xz_size = xz_file.stat().st_size
            with lzma.open(str(xz_file), 'rb') as f_xz:
                self.stream_decompress(f_xz, mp4_file, 50, 50, progress_offset, file_scale, xz_size)

            elapsed = time.monotonic() - start_time
            mp4_size = mp4_file.stat().st_size / (1024 * 1024)
            speed = mp4_size / elapsed if elapsed > 0 else 0

            if self.delete_intermediate and xz_file.exists():
                xz_file.unlink()
            if self.delete_source and lz4_path.exists():
                lz4_path.unlink()

            self.log(f"[{file_index}/{total_files}] 完成: {mp4_file.name} ({mp4_size:.1f}MB, {speed:.1f}MB/s)")
            return True, str(mp4_file)

        except Exception as e:
            self.log(f"[{file_index}/{total_files}] 错误: {e}")
            return False, str(e)

    def run(self):
        try:
            total_files = len(self.file_paths)
            self.log(f"开始处理 {total_files} 个文件 (并行线程: {self.max_workers})")
            self.log("=" * 50)
            start_time = time.monotonic()

            success_count = 0
            fail_count = 0

            if total_files == 1:
                success, msg = self.decompress_single(Path(self.file_paths[0]), 1, 1)
                if success:
                    success_count = 1
                else:
                    fail_count = 1
            else:
                with ProcessPoolExecutor(max_workers=self.max_workers) as executor:
                    future_to_idx = {}
                    for idx, file_path in enumerate(self.file_paths, 1):
                        lz4_path = Path(file_path)
                        self.file_progress_signal.emit(f"提交: {lz4_path.name}")
                        future = executor.submit(
                            _decompress_worker, str(lz4_path), idx, total_files,
                            self.delete_source, self.delete_intermediate
                        )
                        future_to_idx[future] = idx

                    for future in as_completed(future_to_idx):
                        idx = future_to_idx[future]
                        try:
                            success, msg, log_lines = future.result()
                            for line in log_lines:
                                self.log(line)
                            if success:
                                success_count += 1
                            else:
                                fail_count += 1
                        except Exception as e:
                            self.log(f"[{idx}/{total_files}] 线程异常: {e}")
                            fail_count += 1

            total_elapsed = time.monotonic() - start_time
            self.progress_signal.emit(100)
            self.log("=" * 50)
            self.log(f"处理完成: 成功 {success_count}, 失败 {fail_count} (耗时 {total_elapsed:.1f}s)")

            self.finished_signal.emit(fail_count == 0,
                f"完成 {success_count}/{total_files}" + (f"，失败 {fail_count}" if fail_count > 0 else ""))

        except Exception as e:
            self.log(f"严重错误: {e}")
            self.finished_signal.emit(False, str(e))


def _decompress_worker(file_path: str, file_index: int, total_files: int,
                       delete_source: bool, delete_intermediate: bool):
    log_lines = []
    lz4_path = Path(file_path)

    def log(msg):
        log_lines.append(msg)

    try:
        if not lz4_path.exists():
            log(f"[{file_index}/{total_files}] 文件不存在: {lz4_path.name}")
            return False, f"文件不存在: {lz4_path.name}", log_lines

        work_dir = lz4_path.parent
        base_name = lz4_path.stem
        xz_file = work_dir / f"{base_name}.xz"
        mp4_file = work_dir / f"{base_name}.mp4"

        if mp4_file.exists():
            log(f"[{file_index}/{total_files}] 目标文件已存在，跳过")
            return True, f"已存在", log_lines

        start_time = time.monotonic()

        with lz4.frame.open(str(lz4_path), 'rb') as f_in:
            with xz_file.open('wb', buffering=WRITE_BUFFER_SIZE) as f_out:
                while chunk := f_in.read(BUFFER_SIZE):
                    f_out.write(chunk)

        if xz_file.stat().st_size == 0:
            raise ValueError(f"解压 lz4 生成的 xz 文件为空")

        with lzma.open(str(xz_file), 'rb') as f_in:
            with mp4_file.open('wb', buffering=WRITE_BUFFER_SIZE) as f_out:
                while chunk := f_in.read(BUFFER_SIZE):
                    f_out.write(chunk)

        elapsed = time.monotonic() - start_time
        mp4_size = mp4_file.stat().st_size / (1024 * 1024)
        speed = mp4_size / elapsed if elapsed > 0 else 0

        if delete_intermediate and xz_file.exists():
            xz_file.unlink()
        if delete_source and lz4_path.exists():
            lz4_path.unlink()

        log(f"[{file_index}/{total_files}] 完成: {mp4_file.name} ({mp4_size:.1f}MB, {speed:.1f}MB/s)")
        return True, str(mp4_file), log_lines

    except Exception as e:
        log(f"[{file_index}/{total_files}] 错误: {e}")
        return False, str(e), log_lines


class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("B站Yuki_114514资源解压工具 v2.0")
        self.setMinimumSize(680, 520)
        self.resize(750, 580)
        self.selected_files = []
        self.worker = None
        self.init_ui()

    def init_ui(self):
        central = QWidget()
        self.setCentralWidget(central)
        main_layout = QVBoxLayout(central)
        main_layout.setSpacing(10)
        main_layout.setContentsMargins(12, 12, 12, 12)

        # 顶部区域：文件选择 + 选项
        top_layout = QHBoxLayout()

        # 文件选择
        file_group = QGroupBox("文件选择")
        file_layout = QVBoxLayout()

        self.file_count_label = QLabel("拖拽 .lz4 文件到下方列表，或点击按钮选择")
        self.file_count_label.setObjectName("file_count_label")
        self.file_count_label.setAlignment(Qt.AlignCenter)
        file_layout.addWidget(self.file_count_label)

        self.file_list = DragDropListWidget()
        self.file_list.setMinimumHeight(100)
        self.file_list.setMaximumHeight(150)
        self.file_list.files_dropped.connect(self.add_files)
        file_layout.addWidget(self.file_list)

        btn_row = QHBoxLayout()
        btn_select = QPushButton("选择文件")
        btn_select.clicked.connect(self.select_files)
        btn_row.addWidget(btn_select)

        btn_add = QPushButton("追加文件")
        btn_add.clicked.connect(self.select_files)
        btn_row.addWidget(btn_add)

        btn_remove = QPushButton("移除选中")
        btn_remove.clicked.connect(self.remove_selected)
        btn_row.addWidget(btn_remove)

        btn_clear = QPushButton("清空列表")
        btn_clear.clicked.connect(self.clear_files)
        btn_row.addWidget(btn_clear)

        file_layout.addLayout(btn_row)
        file_group.setLayout(file_layout)
        top_layout.addWidget(file_group, 2)

        # 选项
        opt_group = QGroupBox("选项")
        opt_layout = QVBoxLayout()

        self.chk_delete_source = QCheckBox("删除源文件 (.lz4)")
        self.chk_delete_source.setToolTip("解压完成后删除原始 lz4 文件")
        self.chk_delete_intermediate = QCheckBox("删除过渡文件 (.xz)")
        self.chk_delete_intermediate.setChecked(True)
        self.chk_delete_intermediate.setToolTip("解压完成后删除中间 xz 文件")
        opt_layout.addWidget(self.chk_delete_source)
        opt_layout.addWidget(self.chk_delete_intermediate)

        opt_layout.addSpacing(10)

        thread_row = QHBoxLayout()
        thread_row.addWidget(QLabel("并行线程:"))
        self.spin_threads = QSpinBox()
        self.spin_threads.setRange(1, 16)
        self.spin_threads.setValue(min(4, os.cpu_count() or 4))
        self.spin_threads.setToolTip("多文件并行解压数量")
        thread_row.addWidget(self.spin_threads)
        thread_row.addStretch()
        opt_layout.addLayout(thread_row)

        opt_group.setLayout(opt_layout)
        top_layout.addWidget(opt_group, 1)

        main_layout.addLayout(top_layout)

        # 进度区域
        progress_layout = QHBoxLayout()
        self.progress_bar = QProgressBar()
        self.progress_bar.setRange(0, 100)
        self.progress_bar.setValue(0)
        progress_layout.addWidget(self.progress_bar, 1)

        self.progress_label = QLabel("0%")
        self.progress_label.setMinimumWidth(50)
        self.progress_label.setAlignment(Qt.AlignCenter)
        progress_layout.addWidget(self.progress_label)

        main_layout.addLayout(progress_layout)

        # 开始按钮
        self.btn_start = QPushButton("开始解压")
        self.btn_start.setObjectName("btn_start")
        self.btn_start.clicked.connect(self.start_decompress)
        self.btn_start.setEnabled(False)
        main_layout.addWidget(self.btn_start)

        # 日志区域
        log_group = QGroupBox("日志输出")
        log_layout = QVBoxLayout()
        self.log_text = QTextEdit()
        self.log_text.setReadOnly(True)
        self.log_text.setMinimumHeight(120)
        log_layout.addWidget(self.log_text)
        log_group.setLayout(log_layout)
        main_layout.addWidget(log_group, 1)

        # 状态栏
        self.status_label = QLabel("就绪")
        self.status_label.setObjectName("status_label")
        self.statusBar().addPermanentWidget(self.status_label)

        self.update_button_state()

    def format_size(self, size_bytes):
        for unit in ['B', 'KB', 'MB', 'GB']:
            if size_bytes < 1024:
                return f"{size_bytes:.1f} {unit}"
            size_bytes /= 1024
        return f"{size_bytes:.1f} TB"

    def add_files(self, paths):
        new_files = []
        existing = set(self.selected_files)
        for p in paths:
            if p not in existing:
                new_files.append(p)
                existing.add(p)
        self.selected_files.extend(new_files)
        self.refresh_file_list()

    def select_files(self):
        paths, _ = QFileDialog.getOpenFileNames(
            self, "选择lz4文件", "", "LZ4文件 (*.lz4);;所有文件 (*)"
        )
        if paths:
            self.add_files(paths)

    def remove_selected(self):
        selected_rows = set(idx.row() for idx in self.file_list.selectedIndexes())
        if not selected_rows:
            return
        self.selected_files = [
            f for i, f in enumerate(self.selected_files) if i not in selected_rows
        ]
        self.refresh_file_list()

    def clear_files(self):
        self.selected_files.clear()
        self.refresh_file_list()

    def refresh_file_list(self):
        self.file_list.setRowCount(0)
        self.file_list.setRowCount(len(self.selected_files))

        for i, path in enumerate(self.selected_files):
            p = Path(path)

            name_item = QTableWidgetItem(p.name)
            name_item.setToolTip(path)
            self.file_list.setItem(i, 0, name_item)

            try:
                size = p.stat().st_size
                size_item = QTableWidgetItem(self.format_size(size))
            except:
                size_item = QTableWidgetItem("未知")
            size_item.setTextAlignment(Qt.AlignRight | Qt.AlignVCenter)
            self.file_list.setItem(i, 1, size_item)

            status_item = QTableWidgetItem("待处理")
            self.file_list.setItem(i, 2, status_item)

        self.update_button_state()

    def update_button_state(self):
        count = len(self.selected_files)
        if count == 0:
            self.file_count_label.setText("拖拽 .lz4 文件到下方列表，或点击按钮选择")
            self.btn_start.setEnabled(False)
        elif count == 1:
            self.file_count_label.setText(f"已选择 1 个文件")
            self.btn_start.setEnabled(True)
        else:
            self.file_count_label.setText(f"已选择 {count} 个文件")
            self.btn_start.setEnabled(True)

    def log(self, msg):
        self.log_text.append(msg)

    def update_progress(self, value):
        self.progress_bar.setValue(value)
        self.progress_label.setText(f"{value}%")

    def start_decompress(self):
        if not self.selected_files:
            return

        reply = QMessageBox.question(
            self, "确认开始",
            f"确定要解压 {len(self.selected_files)} 个文件？",
            QMessageBox.Yes | QMessageBox.No,
            QMessageBox.Yes
        )
        if reply != QMessageBox.Yes:
            return

        self.btn_start.setEnabled(False)
        self.progress_bar.setValue(0)
        self.progress_label.setText("0%")
        self.log_text.clear()
        self.status_label.setText("解压中...")
        self.log("=" * 50)
        self.log(f"准备处理 {len(self.selected_files)} 个文件")

        self.worker = DecompressWorker(
            self.selected_files.copy(),
            self.chk_delete_source.isChecked(),
            self.chk_delete_intermediate.isChecked(),
            max_workers=self.spin_threads.value()
        )
        self.worker.log_signal.connect(self.log)
        self.worker.progress_signal.connect(self.update_progress)
        self.worker.finished_signal.connect(self.on_finished)
        self.worker.start()

    def on_finished(self, success, message):
        self.btn_start.setEnabled(True)
        self.progress_label.setText("完成" if success else "失败")
        self.status_label.setText(message)

        if success:
            self.log_text.append("")
            self.log(f"✓ {message}")
            QMessageBox.information(self, "完成", message)
        else:
            self.log_text.append("")
            self.log(f"✗ {message}")
            QMessageBox.warning(self, "部分失败", message)


def main():
    app = QApplication(sys.argv)
    app.setStyleSheet(STYLE_SHEET)
    window = MainWindow()
    window.show()
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
