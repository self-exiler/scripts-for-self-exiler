//! B站Yuki_114514资源解压工具 v3.0 — Rust + WinUI 3 (windows-reactor)
//!
//! 解压流程: lz4 -> xz -> mp4

#![windows_subsystem = "windows"]

mod worker;

use std::path::PathBuf;
use std::sync::atomic::Ordering;
use std::sync::Arc;
use std::time::{Duration, Instant};

use windows_pickers::OpenFilePicker;
use windows_reactor::*;
use worker::{FileStatus, JobOptions, SharedJob};

// 文件选择对话框在 UI 线程（STA）内联弹出，属主窗口即当前活动窗口
type HWND = *mut core::ffi::c_void;
windows_core::link!("user32.dll" "system" fn GetActiveWindow() -> HWND);
windows_core::link!("user32.dll" "system" fn GetForegroundWindow() -> HWND);

fn owner_hwnd() -> HWND {
    let hwnd = unsafe { GetActiveWindow() };
    if hwnd.is_null() {
        unsafe { GetForegroundWindow() }
    } else {
        hwnd
    }
}

const TICK_INTERVAL: Duration = Duration::from_millis(300);

// Segoe Fluent Icons 图标
const GLYPH_OPEN_FILE: &str = "\u{E8E5}";
const GLYPH_DELETE: &str = "\u{E74D}";
const GLYPH_PLAY: &str = "\u{E768}";
const GLYPH_CANCEL: &str = "\u{E711}";

#[derive(Clone)]
enum Message {
    PickFiles,
    FilesDropped(DroppedData),
    Remove(String),
    ClearList,
    SetDeleteSource(bool),
    SetDeleteIntermediate(bool),
    SetThreads(f64),
    Start,
    ResultClosed,
    Scheme(ColorScheme),
    Tick,
}

struct App {
    files: Vec<PathBuf>,
    delete_source: bool,
    delete_intermediate: bool,
    threads: f64,
    busy: bool,
    confirm_pending: bool,
    job: Option<Arc<SharedJob>>,
    log_cursor: usize,
    log_text: String,
    progress: f64,
    status_text: String,
    started_at: Option<Instant>,
    result: Option<(bool, String)>,
    scheme: ColorScheme,
}

impl App {
    fn add_files(&mut self, paths: Vec<PathBuf>) {
        let mut added = 0;
        for p in paths {
            if !self.files.iter().any(|f| f == &p) {
                self.files.push(p);
                added += 1;
            }
        }
        self.confirm_pending = false;
        self.status_text = if added > 0 {
            format!("已添加 {added} 个文件，共 {} 个", self.files.len())
        } else {
            "未新增文件（可能已重复或不是 .lz4）".into()
        };
    }

    fn begin(&mut self, context: &ComponentContext<Self>) {
        self.busy = true;
        self.confirm_pending = false;
        self.result = None;
        self.progress = 0.0;
        self.log_text.clear();
        self.log_cursor = 0;
        self.status_text = "解压中...".into();
        self.started_at = Some(Instant::now());
        self.job = Some(worker::start_job(
            self.files.clone(),
            JobOptions {
                delete_source: self.delete_source,
                delete_intermediate: self.delete_intermediate,
                threads: self.threads.round().clamp(1.0, 16.0) as usize,
            },
        ));
        context.spawn_background(|_| {
            std::thread::sleep(TICK_INTERVAL);
            Message::Tick
        });
    }

    fn tick(&mut self, context: &ComponentContext<Self>) {
        let Some(job) = &self.job else { return };

        {
            let log = job.log.lock().unwrap();
            for line in log.iter().skip(self.log_cursor) {
                self.log_text.push_str(line);
                self.log_text.push('\n');
            }
            self.log_cursor = log.len();
        }

        let mut total_done = 0u64;
        let mut total_size = 0u64;
        for fp in &job.files {
            total_done += fp.done.load(Ordering::Relaxed);
            total_size += fp.lz4_size.max(1);
        }
        self.progress = if total_size > 0 {
            (total_done as f64 / total_size as f64 * 100.0).min(100.0)
        } else {
            0.0
        };

        if job.finished.load(Ordering::Relaxed) >= job.files.len() {
            let elapsed = self.started_at.map(|t| t.elapsed().as_secs_f64()).unwrap_or(0.0);
            let ok = job
                .files
                .iter()
                .filter(|fp| {
                    matches!(
                        &*fp.status.lock().unwrap(),
                        FileStatus::Done { .. } | FileStatus::Duplicate
                    )
                })
                .count();
            let failed = job.files.len() - ok;
            let total = job.files.len();
            self.busy = false;
            self.progress = 100.0;
            self.log_text.push('\n');
            self.log_text
                .push_str(&format!("处理完成: 成功 {ok}, 失败 {failed} (耗时 {elapsed:.1}s)"));
            let message = format!("成功 {ok}/{total}，耗时 {elapsed:.1}s");
            if failed == 0 {
                self.status_text = format!("完成 {ok}/{total} ✓");
                self.result = Some((true, message));
            } else {
                self.status_text = format!("完成 {ok}/{total}，失败 {failed}");
                self.result = Some((false, format!("{message}，详情见日志")));
            };
            self.job = None;
        } else {
            context.spawn_background(|_| {
                std::thread::sleep(TICK_INTERVAL);
                Message::Tick
            });
        }
    }
}

impl Component for App {
    type Input = ();
    type Message = Message;

    fn create(_input: &(), _context: &ComponentContext<Self>) -> Self {
        Self {
            files: Vec::new(),
            delete_source: false,
            delete_intermediate: true,
            threads: 4.0,
            busy: false,
            confirm_pending: false,
            job: None,
            log_cursor: 0,
            log_text: String::new(),
            progress: 0.0,
            status_text: "就绪".into(),
            started_at: None,
            result: None,
            scheme: ColorScheme::Light,
        }
    }

    fn update(&mut self, message: Message, context: &ComponentContext<Self>) {
        match message {
            Message::PickFiles => {
                let result = OpenFilePicker::new()
                    .title("选择 lz4 文件")
                    .filter_extensions("LZ4 文件", ["lz4"])
                    .filter_all()
                    .show_multiple_for_hwnd(owner_hwnd());
                match result {
                    Ok(paths) if paths.is_empty() => {}
                    Ok(paths) => self.add_files(paths),
                    Err(e) => self.status_text = format!("选择文件失败: {e}"),
                }
            }
            Message::FilesDropped(data) => {
                let paths = match data {
                    DroppedData::StorageItems(items) => items
                        .into_iter()
                        .map(|i| PathBuf::from(i.path))
                        .filter(|p| {
                            p.extension()
                                .map(|e| e.eq_ignore_ascii_case("lz4"))
                                .unwrap_or(false)
                        })
                        .collect::<Vec<_>>(),
                    _ => Vec::new(),
                };
                if paths.is_empty() {
                    self.status_text = "请拖入 .lz4 文件".into();
                } else {
                    self.add_files(paths);
                }
            }
            Message::Remove(path) if !self.busy => {
                self.files.retain(|p| p.to_string_lossy() != path);
                self.confirm_pending = false;
            }
            Message::ClearList if !self.busy => {
                self.files.clear();
                self.confirm_pending = false;
            }
            Message::SetDeleteSource(v) => self.delete_source = v,
            Message::SetDeleteIntermediate(v) => self.delete_intermediate = v,
            Message::SetThreads(v) => self.threads = v.clamp(1.0, 16.0),
            Message::Start if !self.busy && !self.files.is_empty() => {
                // 两段式确认：第一次点击提示，第二次点击开始
                if self.confirm_pending {
                    self.begin(context);
                } else {
                    self.confirm_pending = true;
                }
            }
            Message::ResultClosed => self.result = None,
            Message::Scheme(scheme) => self.scheme = scheme,
            Message::Tick => self.tick(context),
            _ => {}
        }
    }

    fn view(&self, _input: &(), context: &mut ViewContext<Self>) -> View {
        context.window_title("B站Yuki_114514资源解压工具 v3.0");
        context.window_visuals(
            WindowVisuals::new()
                .client_size(800.0, 700.0)
                .backdrop(WindowBackdrop::Mica),
        );
        // 订阅明暗主题（订阅时即回报当前值）
        context.on_color_scheme(context.callback(Message::Scheme));

        let secondary = secondary_text(self.scheme);

        // ── 标题 ──
        let header = StackPanel::new()
            .orientation(Orientation::Horizontal)
            .spacing(10.0)
            .grid_row(0)
            .children((
                TextBlock::new()
                    .text("B站Yuki_114514资源解压工具")
                    .font_size(20.0)
                    .font_weight(FontWeight::SEMI_BOLD),
                TextBlock::new()
                    .text(".lz4 → .xz → .mp4")
                    .font_size(13.0)
                    .foreground(secondary)
                    .vertical_alignment(VerticalAlignment::Bottom)
                    .margin(Thickness::new(0.0, 0.0, 0.0, 3.0)),
            ));

        // ── 文件列表卡片 ──
        let rows: Vec<KeyedView> = self
            .job
            .as_ref()
            .map(|job| {
                job.files
                    .iter()
                    .enumerate()
                    .map(|(i, fp)| {
                        KeyedView::new(
                            i,
                            ListViewItem::new().tag(fp.file_name()).content(job_row(
                                fp,
                                !self.busy,
                                context,
                            )),
                        )
                    })
                    .collect()
            })
            .unwrap_or_else(|| {
                self.files
                    .iter()
                    .enumerate()
                    .map(|(i, p)| {
                        KeyedView::new(
                            i,
                            ListViewItem::new()
                                .tag(p.to_string_lossy())
                                .content(pending_row(p, context)),
                        )
                    })
                    .collect()
            });

        let list_header = Grid::new()
            .columns([GridLength::STAR, GridLength::Auto])
            .children((
                TextBlock::new()
                    .text(format!("文件列表（{}）", self.files.len()))
                    .font_weight(FontWeight::SEMI_BOLD)
                    .grid_column(0),
                TextBlock::new()
                    .text("拖入或点击下方按钮添加 .lz4 文件")
                    .font_size(12.0)
                    .foreground(secondary)
                    .horizontal_alignment(HorizontalAlignment::Right)
                    .grid_column(1),
            ));

        let list_card = Border::new()
            .background(Brush::Theme(ThemeBrush::CardBackground))
            .border_brush(Brush::Theme(ThemeBrush::CardStroke))
            .border_thickness(Thickness::uniform(1.0))
            .corner_radius(CornerRadius::uniform(8.0))
            .padding(Thickness::uniform(10.0))
            .grid_row(1)
            .content(
                StackPanel::new()
                    .spacing(6.0)
                    .children((
                        list_header,
                        Border::new()
                            .corner_radius(CornerRadius::uniform(4.0))
                            .drop_policy(DragDropPolicy::new().storage_items(
                                DragDropAction::new(DragDropOperation::Copy)
                                    .caption("放下以添加 .lz4 文件"),
                            ))
                            .on_drop(context.callback(Message::FilesDropped))
                            .height(170.0)
                            .content(
                                ListView::new()
                                    .selection_mode(ListViewSelectionMode::None)
                                    .collection_slot(ListViewSlot::Items, rows),
                            ),
                    )),
            );

        // ── 操作按钮 ──
        let buttons = StackPanel::new()
            .orientation(Orientation::Horizontal)
            .spacing(8.0)
            .grid_row(2)
            .children((
                Button::new()
                    .is_enabled(!self.busy)
                    .on_click(context.message(Message::PickFiles))
                    .content(icon_button(GLYPH_OPEN_FILE, "选择文件")),
                Button::new()
                    .is_enabled(!self.busy && !self.files.is_empty())
                    .on_click(context.message(Message::ClearList))
                    .content(icon_button(GLYPH_DELETE, "清空列表")),
            ));

        // ── 选项卡片 ──
        let options_card = Border::new()
            .background(Brush::Theme(ThemeBrush::CardBackground))
            .border_brush(Brush::Theme(ThemeBrush::CardStroke))
            .border_thickness(Thickness::uniform(1.0))
            .corner_radius(CornerRadius::uniform(8.0))
            .padding(Thickness::new(12.0, 8.0, 12.0, 8.0))
            .grid_row(3)
            .content(
                StackPanel::new()
                    .orientation(Orientation::Horizontal)
                    .spacing(20.0)
                    .children((
                        CheckBox::new()
                            .is_checked(self.delete_source)
                            .is_enabled(!self.busy)
                            .on_is_checked_changed(context.callback(Message::SetDeleteSource))
                            .content("删除源文件 (.lz4)"),
                        CheckBox::new()
                            .is_checked(self.delete_intermediate)
                            .is_enabled(!self.busy)
                            .on_is_checked_changed(context.callback(Message::SetDeleteIntermediate))
                            .content("删除过渡文件 (.xz)"),
                        StackPanel::new()
                            .orientation(Orientation::Horizontal)
                            .spacing(8.0)
                            .vertical_alignment(VerticalAlignment::Center)
                            .children((
                                TextBlock::new().text("并行线程:"),
                                NumberBox::new()
                                    .minimum(1.0)
                                    .maximum(16.0)
                                    .value(self.threads)
                                    .is_enabled(!self.busy)
                                    .on_value_changed(context.callback(|v: Option<f64>| {
                                        Message::SetThreads(v.unwrap_or(4.0))
                                    }))
                                    .width(96.0),
                            )),
                    )),
            );

        // ── 进度行：忙时转圈 + 进度条 + 百分比/完成数 ──
        let done_count = self
            .job
            .as_ref()
            .map(|job| job.finished.load(std::sync::atomic::Ordering::Relaxed));
        let progress_summary = match done_count {
            Some(done) => format!("{:.0}% · {}/{}", self.progress, done, self.files.len()),
            None => format!("{:.0}%", self.progress),
        };
        let progress_row = Grid::new()
            .columns([GridLength::Auto, GridLength::STAR, GridLength::Auto])
            .grid_row(4)
            .children((
                ProgressRing::new()
                    .is_indeterminate(true)
                    .is_active(self.busy)
                    .width(20.0)
                    .height(20.0)
                    .margin(Thickness::new(0.0, 0.0, 10.0, 0.0))
                    .vertical_alignment(VerticalAlignment::Center)
                    .grid_column(0),
                ProgressBar::new()
                    .value(self.progress)
                    .vertical_alignment(VerticalAlignment::Center)
                    .grid_column(1),
                TextBlock::new()
                    .text(progress_summary)
                    .font_size(12.0)
                    .foreground(secondary)
                    .margin(Thickness::new(10.0, 0.0, 0.0, 0.0))
                    .vertical_alignment(VerticalAlignment::Center)
                    .grid_column(2),
            ));

        // ── 开始按钮（强调色）──
        let start_text = if self.busy {
            "解压中...".to_string()
        } else if self.confirm_pending {
            format!("确认解压 {} 个文件？再次点击开始", self.files.len())
        } else {
            "开始解压".to_string()
        };
        let start_icon = if self.busy || self.confirm_pending {
            GLYPH_CANCEL
        } else {
            GLYPH_PLAY
        };
        let start_button = Button::new()
            .style(ButtonStyle::Accent)
            .is_enabled(!self.busy && !self.files.is_empty())
            .on_click(context.message(Message::Start))
            .height(40.0)
            .grid_row(5)
            .content(icon_button(start_icon, &start_text));

        // ── 结果横幅 ──
        let result_banner = match &self.result {
            Some((ok, message)) => InfoBar::new()
                .is_open(true)
                .is_closable(true)
                .severity(if *ok {
                    InfoBarSeverity::Success
                } else {
                    InfoBarSeverity::Error
                })
                .title(if *ok { "处理完成" } else { "部分文件失败" })
                .message(message.clone())
                .grid_row(6)
                .on_closed(context.message(Message::ResultClosed)),
            None => InfoBar::new()
                .is_open(false)
                .grid_row(6)
                .on_closed(context.message(Message::ResultClosed)),
        };

        // ── 日志卡片 ──
        let log_card = Border::new()
            .background(Brush::Theme(ThemeBrush::CardBackground))
            .border_brush(Brush::Theme(ThemeBrush::CardStroke))
            .border_thickness(Thickness::uniform(1.0))
            .corner_radius(CornerRadius::uniform(8.0))
            .padding(Thickness::uniform(10.0))
            .grid_row(7)
            .content(
                StackPanel::new()
                    .spacing(6.0)
                    .children((
                        TextBlock::new()
                            .text("日志")
                            .font_weight(FontWeight::SEMI_BOLD),
                        ScrollViewer::new()
                            .vertical_scroll_bar_visibility(ScrollBarVisibility::Auto)
                            .content(
                                TextBlock::new()
                                    .text(self.log_text.clone())
                                    .font_size(12.0)
                                    .text_wrapping(TextWrapping::Wrap),
                            ),
                    )),
            );

        // ── 状态栏 ──
        let status = TextBlock::new()
            .text(self.status_text.clone())
            .text_trimming(TextTrimming::CharacterEllipsis)
            .font_size(12.0)
            .foreground(secondary)
            .grid_row(8);

        Border::new()
            .padding(Thickness::uniform(16.0))
            .content(
                Grid::new()
                    .row_spacing(10.0)
                    .rows([
                        GridLength::Auto, // 0 标题
                        GridLength::Auto, // 1 文件列表卡片
                        GridLength::Auto, // 2 按钮行
                        GridLength::Auto, // 3 选项卡片
                        GridLength::Auto, // 4 进度行
                        GridLength::Auto, // 5 开始按钮
                        GridLength::Auto, // 6 结果横幅
                        GridLength::STAR, // 7 日志卡片
                        GridLength::Auto, // 8 状态栏
                    ])
                    .children((
                        header,
                        list_card,
                        buttons,
                        options_card,
                        progress_row,
                        start_button,
                        result_banner,
                        log_card,
                        status,
                    )),
            )
    }
}

/// 带图标的按钮内容
fn icon_button(glyph: &str, label: &str) -> View {
    StackPanel::new()
        .orientation(Orientation::Horizontal)
        .spacing(6.0)
        .children((FontIcon::new().glyph(glyph), TextBlock::new().text(label)))
        .into()
}

/// 次要文字颜色（跟随明暗主题）
fn secondary_text(scheme: ColorScheme) -> Brush {
    match scheme {
        ColorScheme::Light => Brush::Solid(Color::rgb(96, 96, 96)),
        ColorScheme::Dark => Brush::Solid(Color::rgb(160, 160, 160)),
    }
}

fn status_text_of(fp: &worker::FileProgress) -> String {
    match &*fp.status.lock().unwrap() {
        FileStatus::Pending => "待处理".into(),
        FileStatus::Running => format!("解压中 {:.0}%", fp.progress() * 100.0),
        FileStatus::Done { speed, .. } => format!("完成 ({speed:.1}MB/s)"),
        FileStatus::Duplicate => "已存在，跳过".into(),
        FileStatus::Failed(e) => format!("失败: {e}"),
    }
}

/// 文件行状态文字颜色
fn status_brush(fp: &worker::FileProgress) -> Option<Brush> {
    match &*fp.status.lock().unwrap() {
        FileStatus::Running => Some(Brush::Theme(ThemeBrush::Accent)),
        FileStatus::Done { .. } | FileStatus::Duplicate | FileStatus::Pending => None,
        FileStatus::Failed(_) => Some(Brush::Theme(ThemeBrush::SystemCritical)),
    }
}

fn size_str(bytes: u64) -> String {
    let mut size = bytes as f64;
    for unit in ["B", "KB", "MB", "GB", "TB"] {
        if size < 1024.0 {
            return format!("{size:.1} {unit}");
        }
        size /= 1024.0;
    }
    format!("{size:.1} PB")
}

/// 运行中的任务行（来自共享状态）
fn job_row(fp: &Arc<worker::FileProgress>, removable: bool, context: &ViewContext<App>) -> View {
    row_grid(
        fp.file_name(),
        size_str(fp.lz4_size),
        status_text_of(fp),
        status_brush(fp),
        Some((fp.path.to_string_lossy().into_owned(), removable)),
        context,
    )
}

/// 待处理文件行（本地列表）
fn pending_row(path: &PathBuf, context: &ViewContext<App>) -> View {
    let name = path
        .file_name()
        .map(|n| n.to_string_lossy().into_owned())
        .unwrap_or_default();
    let size = std::fs::metadata(path).map(|m| m.len()).ok();
    row_grid(
        name,
        size.map(size_str).unwrap_or_else(|| "未知".into()),
        "待处理".into(),
        None,
        Some((path.to_string_lossy().into_owned(), true)),
        context,
    )
}

fn row_grid(
    name: String,
    size: String,
    status: String,
    status_color: Option<Brush>,
    remove: Option<(String, bool)>,
    context: &ViewContext<App>,
) -> View {
    let (path, removable) = remove.unwrap_or_default();
    let mut status_block = TextBlock::new().text(status);
    if let Some(color) = status_color {
        status_block = status_block.foreground(color);
    }
    Grid::new()
        .columns([
            GridLength::STAR,
            GridLength::Pixel(90.0),
            GridLength::Pixel(170.0),
            GridLength::Pixel(36.0),
        ])
        .children((
            TextBlock::new()
                .text(name)
                .text_trimming(TextTrimming::CharacterEllipsis)
                .vertical_alignment(VerticalAlignment::Center)
                .grid_column(0),
            TextBlock::new()
                .text(size)
                .horizontal_alignment(HorizontalAlignment::Right)
                .vertical_alignment(VerticalAlignment::Center)
                .grid_column(1),
            status_block
                .vertical_alignment(VerticalAlignment::Center)
                .grid_column(2),
            Button::new()
                .is_enabled(removable)
                .on_click(context.callback(move |()| Message::Remove(path.clone())))
                .min_width(0.0)
                .margin(Thickness::uniform(2.0))
                .grid_column(3)
                .content(GLYPH_DELETE),
        ))
}

fn main() {
    // 结构体名 App 遮蔽了 glob 导入的 windows_reactor::App，这里用全路径
    windows_reactor::App::run_component::<App>(()).unwrap();
}
