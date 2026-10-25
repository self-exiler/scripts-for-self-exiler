//! 解压核心：lz4 -> xz -> mp4，多线程并行处理。

use std::fs::{self, File};
use std::io::{BufReader, BufWriter, Read, Write};
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicU64, AtomicUsize, Ordering};
use std::sync::mpsc;
use std::sync::{Arc, Mutex};
use std::time::Instant;

use lz4_flex::frame::FrameDecoder;
use lzma_rust2::XzReader;

const READ_BUFFER_SIZE: usize = 8 * 1024 * 1024;
const WRITE_BUFFER_SIZE: usize = 2 * 1024 * 1024;

#[derive(Clone, PartialEq)]
pub enum FileStatus {
    Pending,
    Running,
    Done { size: u64, speed: f64 },
    Duplicate,
    Failed(String),
}

pub struct FileProgress {
    pub path: PathBuf,
    pub index: usize,
    pub total_files: usize,
    pub lz4_size: u64,
    /// 当前整体进度折算成的字节数（0..=lz4_size），两级解压各占 50%。
    pub done: AtomicU64,
    pub status: Mutex<FileStatus>,
}

impl FileProgress {
    /// 整体进度 0.0..=1.0
    pub fn progress(&self) -> f64 {
        (self.done.load(Ordering::Relaxed) as f64 / self.lz4_size.max(1) as f64).min(1.0)
    }

    pub fn file_name(&self) -> String {
        self.path
            .file_name()
            .map(|n| n.to_string_lossy().into_owned())
            .unwrap_or_default()
    }
}

pub struct SharedJob {
    pub files: Vec<Arc<FileProgress>>,
    pub log: Mutex<Vec<String>>,
    pub finished: AtomicUsize,
}

#[derive(Clone, Copy)]
pub struct JobOptions {
    pub delete_source: bool,
    pub delete_intermediate: bool,
    pub threads: usize,
}

/// 启动后台解压任务，立即返回共享状态句柄供 UI 轮询。
pub fn start_job(files: Vec<PathBuf>, opts: JobOptions) -> Arc<SharedJob> {
    let total = files.len();
    let files: Vec<Arc<FileProgress>> = files
        .into_iter()
        .enumerate()
        .map(|(i, path)| {
            let lz4_size = fs::metadata(&path).map(|m| m.len()).unwrap_or(0);
            Arc::new(FileProgress {
                path,
                index: i + 1,
                total_files: total,
                lz4_size,
                done: AtomicU64::new(0),
                status: Mutex::new(FileStatus::Pending),
            })
        })
        .collect();

    let shared = Arc::new(SharedJob {
        files,
        log: Mutex::new(Vec::new()),
        finished: AtomicUsize::new(0),
    });

    log(&shared, format!("开始处理 {total} 个文件 (并行线程: {})", opts.threads));
    log(&shared, "=".repeat(50));

    let (tx, rx) = mpsc::channel::<Arc<FileProgress>>();
    let rx = Arc::new(Mutex::new(rx));
    for _ in 0..opts.threads.max(1) {
        let shared = Arc::clone(&shared);
        let rx = Arc::clone(&rx);
        std::thread::spawn(move || loop {
            let task = rx.lock().unwrap().recv();
            let Ok(fp) = task else { break };
            process_file(&shared, &fp, &opts);
            shared.finished.fetch_add(1, Ordering::Relaxed);
        });
    }

    for fp in &shared.files {
        let _ = tx.send(Arc::clone(fp));
    }
    drop(tx);
    shared
}

pub fn log(shared: &SharedJob, line: String) {
    shared.log.lock().unwrap().push(line);
}

fn process_file(shared: &SharedJob, fp: &FileProgress, opts: &JobOptions) {
    let lz4_path = Path::new(&fp.path);
    let tag = format!("[{}/{}]", fp.index, fp.total_files);

    if !lz4_path.exists() {
        let msg = format!("文件不存在: {}", fp.file_name());
        log(shared, format!("{tag} {msg}"));
        *fp.status.lock().unwrap() = FileStatus::Failed(msg);
        return;
    }

    // a.b.lz4 -> a.b.xz / a.b.mp4
    let base = lz4_path.with_extension("");
    let xz_path = base.with_extension("xz");
    let mp4_path = base.with_extension("mp4");

    if mp4_path.exists() {
        log(shared, format!("{tag} 目标文件已存在，跳过: {}", fp.file_name()));
        *fp.status.lock().unwrap() = FileStatus::Duplicate;
        return;
    }

    *fp.status.lock().unwrap() = FileStatus::Running;
    let start = Instant::now();

    match run_pipeline(lz4_path, &xz_path, &mp4_path, fp) {
        Ok(mp4_size) => {
            let speed = mp4_size as f64 / 1048576.0 / start.elapsed().as_secs_f64().max(1e-9);
            if opts.delete_intermediate {
                let _ = fs::remove_file(&xz_path);
            }
            if opts.delete_source {
                let _ = fs::remove_file(lz4_path);
            }
            *fp.status.lock().unwrap() = FileStatus::Done {
                size: mp4_size,
                speed,
            };
            log(
                shared,
                format!(
                    "{tag} 完成: {} ({:.1}MB, {:.1}MB/s)",
                    mp4_path.file_name().map(|n| n.to_string_lossy()).unwrap_or_default(),
                    mp4_size as f64 / 1048576.0,
                    speed
                ),
            );
        }
        Err(e) => {
            // 清理失败残留，避免下次被当作已存在而跳过
            let _ = fs::remove_file(&mp4_path);
            *fp.status.lock().unwrap() = FileStatus::Failed(e.clone());
            log(shared, format!("{tag} 错误: {e}"));
        }
    }
}

fn run_pipeline(lz4_path: &Path, xz_path: &Path, mp4_path: &Path, fp: &FileProgress) -> Result<u64, String> {
    // 第一级：lz4 -> xz（贡献 0..50% 进度）
    let lz4_file = File::open(lz4_path).map_err(|e| format!("无法打开 lz4 文件: {e}"))?;
    let xz_out = File::create(xz_path).map_err(|e| format!("无法创建 xz 文件: {e}"))?;
    {
        let mut writer = BufWriter::with_capacity(WRITE_BUFFER_SIZE, xz_out);
        let counting = CountingReader::new(BufReader::with_capacity(READ_BUFFER_SIZE, lz4_file));
        let mut decoder = FrameDecoder::new(counting);
        copy_stream(&mut decoder, &mut writer, |n| {
            fp.done.store(n / 2, Ordering::Relaxed);
        })?;
        writer.flush().map_err(|e| format!("写入 xz 失败: {e}"))?;
    }

    let xz_size = fs::metadata(xz_path)
        .map_err(|e| format!("无法读取 xz 文件: {e}"))?
        .len();
    if xz_size == 0 {
        return Err("解压 lz4 生成的 xz 文件为空".into());
    }

    // 第二级：xz -> mp4（贡献 50%..100% 进度）
    let xz_in = File::open(xz_path).map_err(|e| format!("无法打开 xz 文件: {e}"))?;
    let mp4_out = File::create(mp4_path).map_err(|e| format!("无法创建 mp4 文件: {e}"))?;
    let counting = CountingReader::new(BufReader::with_capacity(READ_BUFFER_SIZE, xz_in));
    let mut reader = XzReader::new(counting, false);
    let mut writer = BufWriter::with_capacity(WRITE_BUFFER_SIZE, mp4_out);
    copy_stream(&mut reader, &mut writer, |n| {
        let frac = (n as f64 / xz_size as f64).min(1.0);
        let overall = fp.lz4_size as f64 * (0.5 + 0.5 * frac);
        fp.done.store(overall as u64, Ordering::Relaxed);
    })?;
    writer.flush().map_err(|e| format!("写入 mp4 失败: {e}"))?;

    fs::metadata(mp4_path)
        .map(|m| m.len())
        .map_err(|e| format!("无法读取 mp4 文件: {e}"))
}

fn copy_stream<R: Read, W: Write>(r: &mut R, w: &mut W, mut on_count: impl FnMut(u64)) -> Result<(), String> {
    let mut buf = vec![0u8; READ_BUFFER_SIZE];
    let mut total = 0u64;
    loop {
        let n = r.read(&mut buf).map_err(|e| format!("解压失败: {e}"))?;
        if n == 0 {
            break;
        }
        w.write_all(&buf[..n]).map_err(|e| format!("写入失败: {e}"))?;
        total += n as u64;
        on_count(total);
    }
    Ok(())
}

struct CountingReader<R> {
    inner: R,
    count: u64,
}

impl<R> CountingReader<R> {
    fn new(inner: R) -> Self {
        Self { inner, count: 0 }
    }
}

impl<R: Read> Read for CountingReader<R> {
    fn read(&mut self, buf: &mut [u8]) -> std::io::Result<usize> {
        let n = self.inner.read(buf)?;
        self.count += n as u64;
        Ok(n)
    }
}
