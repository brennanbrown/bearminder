// Learn more about Tauri commands at https://tauri.app/develop/calling-rust/
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::PathBuf;
use std::process::Command;
use tauri::Manager;
use tauri::menu::{MenuBuilder, MenuItemBuilder};
use tauri::tray::TrayIconBuilder;

#[tauri::command]
fn greet(name: &str) -> String {
    format!("Hello, {}! You've been greeted from Rust!", name)
}

#[tauri::command]
fn read_status() -> Result<String, String> {
    let src_tauri_dir = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
    let repo_root = src_tauri_dir
        .parent()
        .and_then(|p| p.parent())
        .ok_or_else(|| "Failed to resolve repository root".to_string())?
        .to_path_buf();
    let status_path = repo_root.join("data").join("status.json");
    match fs::read_to_string(&status_path) {
        Ok(s) => Ok(s),
        Err(e) => Err(format!(
            "Failed to read status.json at {}: {}",
            status_path.display(),
            e
        )),
    }
}

#[tauri::command]
fn open_url(url: String) -> Result<(), String> {
    // macOS: use `open` to launch default browser
    Command::new("open")
        .arg(url)
        .spawn()
        .map(|_| ())
        .map_err(|e| format!("Failed to open url: {}", e))
}

#[tauri::command]
fn open_path(path: String) -> Result<(), String> {
    Command::new("open")
        .arg(path)
        .spawn()
        .map(|_| ())
        .map_err(|e| format!("Failed to open path: {}", e))
}

fn try_find_bear_db() -> Option<String> {
    // 1) Environment variable takes precedence
    if let Ok(p) = std::env::var("BEAR_DB_PATH") {
        let expanded = shellexpand::tilde(&p).to_string();
        if std::path::Path::new(&expanded).exists() {
            return Some(expanded);
        }
    }
    // 2) Common locations for Bear 2/1
    let candidates = [
        "~/Library/Group Containers/9K33E3U3T4.net.shinyfrog.bear/Application Data/database.sqlite",
        "~/Library/Group Containers/2ELUDT6HF6.com.shinyfrog.bear/Application Data/database.sqlite",
        "~/Library/Containers/net.shinyfrog.bear/Data/Documents/Application Data/database.sqlite",
    ];
    for c in candidates {
        let expanded = shellexpand::tilde(c).to_string();
        if std::path::Path::new(&expanded).exists() {
            return Some(expanded);
        }
    }
    None
}

#[tauri::command]
fn detect_bear_db() -> Result<Option<String>, String> {
    Ok(try_find_bear_db())
}

#[tauri::command]
fn open_bear_db_folder() -> Result<(), String> {
    if let Some(p) = try_find_bear_db() {
        let parent = std::path::Path::new(&p)
            .parent()
            .ok_or_else(|| "Failed to get parent folder".to_string())?;
        return Command::new("open")
            .arg(parent)
            .spawn()
            .map(|_| ())
            .map_err(|e| format!("Failed to open folder: {}", e));
    }
    Err("Bear database not found".to_string())
}

#[derive(Serialize, Deserialize, Default)]
struct EnvSettings {
    beeminder_username: Option<String>,
    beeminder_goal: Option<String>,
    beeminder_token: Option<String>,
}

fn repo_root() -> Result<PathBuf, String> {
    let src_tauri_dir = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
    Ok(src_tauri_dir
        .parent()
        .and_then(|p| p.parent())
        .ok_or_else(|| "Failed to resolve repository root".to_string())?
        .to_path_buf())
}

#[tauri::command]
fn get_env() -> Result<EnvSettings, String> {
    let root = repo_root()?;
    let env_path = root.join(".env");
    let mut settings = EnvSettings::default();
    if let Ok(content) = fs::read_to_string(&env_path) {
        for line in content.lines() {
            if let Some((k, v)) = line.split_once('=') {
                let key = k.trim();
                let val = v.trim().trim_matches('"');
                match key {
                    "BEEMINDER_USERNAME" => settings.beeminder_username = Some(val.to_string()),
                    "BEEMINDER_GOAL" => settings.beeminder_goal = Some(val.to_string()),
                    "BEEMINDER_TOKEN" => settings.beeminder_token = Some(val.to_string()),
                    _ => {}
                }
            }
        }
    }
    Ok(settings)
}

#[tauri::command]
fn set_env(settings: EnvSettings) -> Result<(), String> {
    let root = repo_root()?;
    let env_path = root.join(".env");
    // Read existing lines (if any) preserving unrelated keys
    let mut lines: Vec<String> = if let Ok(content) = fs::read_to_string(&env_path) {
        content.lines().map(|s| s.to_string()).collect()
    } else {
        vec![]
    };

    let mut set_line = |key: &str, val_opt: &Option<String>| {
        if let Some(val) = val_opt {
            let line = format!("{}={}", key, val);
            let mut found = false;
            for l in lines.iter_mut() {
                if l.starts_with(&format!("{}=", key)) {
                    *l = line.clone();
                    found = true;
                    break;
                }
            }
            if !found {
                lines.push(line);
            }
        }
    };

    set_line("BEEMINDER_USERNAME", &settings.beeminder_username);
    set_line("BEEMINDER_GOAL", &settings.beeminder_goal);
    set_line("BEEMINDER_TOKEN", &settings.beeminder_token);

    let output = if lines.is_empty() {
        String::new()
    } else {
        let mut s = lines.join("\n");
        s.push('\n');
        s
    };
    fs::write(&env_path, output).map_err(|e| format!("Failed to write .env: {}", e))
}

#[derive(Serialize)]
struct Paths {
    repo_root: String,
    config_path: String,
    data_dir: String,
}

#[tauri::command]
fn get_paths() -> Result<Paths, String> {
    let src_tauri_dir = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
    let repo_root = src_tauri_dir
        .parent()
        .and_then(|p| p.parent())
        .ok_or_else(|| "Failed to resolve repository root".to_string())?
        .to_path_buf();
    let config_path = repo_root.join("config.yaml");
    let data_dir = repo_root.join("data");
    Ok(Paths {
        repo_root: repo_root.display().to_string(),
        config_path: config_path.display().to_string(),
        data_dir: data_dir.display().to_string(),
    })
}

#[derive(Deserialize)]
struct SyncArgs {
    since_hours: u32,
    ignore_last_sync: bool,
    dry_run: bool,
}

#[tauri::command]
fn run_sync(args: SyncArgs) -> Result<String, String> {
    // Compute repository root based on compile-time location of this file: gui/src-tauri
    let src_tauri_dir = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
    let repo_root = src_tauri_dir
        .parent() // gui/
        .and_then(|p| p.parent()) // repo root
        .ok_or_else(|| "Failed to resolve repository root".to_string())?
        .to_path_buf();

    // Python interpreter resolution: prefer repo .venv, then python3, then python
    let py_venv = repo_root.join(".venv").join("bin").join("python");
    let python = if py_venv.exists() {
        py_venv
    } else if which::which("python3").is_ok() {
        PathBuf::from("python3")
    } else {
        PathBuf::from("python")
    };

    let mut cmd = Command::new(python);
    cmd.current_dir(&repo_root)
        .arg("-m")
        .arg("bearminder.main")
        .arg("sync-once")
        .arg("--since-hours")
        .arg(args.since_hours.to_string());

    if args.ignore_last_sync {
        cmd.arg("--ignore-last-sync");
    }

    // Control dry-run via environment variable used by our CLI
    if args.dry_run {
        cmd.env("BEAR_MINDER_DRY_RUN", "true");
    } else {
        cmd.env("BEAR_MINDER_DRY_RUN", "false");
    }

    let output = cmd.output().map_err(|e| format!("Failed to start CLI: {}", e))?;
    let mut combined = String::new();
    combined.push_str(&String::from_utf8_lossy(&output.stdout));
    if !output.status.success() {
        combined.push_str(&String::from_utf8_lossy(&output.stderr));
        return Err(combined);
    }
    Ok(combined)
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .invoke_handler(tauri::generate_handler![
            greet,
            run_sync,
            get_paths,
            read_status,
            open_url,
            open_path,
            detect_bear_db,
            open_bear_db_folder,
            get_env,
            set_env
        ])
        .setup(|app| {
            // Build tray menu
            let menu = MenuBuilder::new(app)
                .item(&MenuItemBuilder::new("Open BearMinder").id("open").build(app).unwrap())
                .item(&MenuItemBuilder::new("Sync now").id("sync_now").build(app).unwrap())
                .separator()
                .item(&MenuItemBuilder::new("Open config.yaml").id("open_config").build(app).unwrap())
                .item(&MenuItemBuilder::new("Open data folder").id("open_data").build(app).unwrap())
                .separator()
                .item(&MenuItemBuilder::new("Quit").id("quit").build(app).unwrap())
                .build()
                .unwrap();

            TrayIconBuilder::new()
                .menu(&menu)
                .on_menu_event(|app, event| {
                    match event.id.0.as_str() {
                        "open" => {
                            if let Some(w) = app.get_webview_window("main") {
                                let _ = w.show();
                                let _ = w.set_focus();
                            }
                        }
                        "sync_now" => {
                            // Fire a quick sync with defaults: last hour, respect dry-run from env default false
                            let _ = std::thread::spawn({
                                let handle = app.app_handle().clone();
                                move || {
                                    // Run with since_hours=1, ignore_last_sync=false, dry_run=false
                                    let _ = run_sync(SyncArgs { since_hours: 1, ignore_last_sync: false, dry_run: false });
                                    // Optionally emit an event to frontend in future
                                    let _ = handle.emit_all("sync-finished", ());
                                }
                            });
                        }
                        "open_config" => {
                            if let Ok(root) = repo_root() {
                                let _ = Command::new("open").arg(root.join("config.yaml")).spawn();
                            }
                        }
                        "open_data" => {
                            if let Ok(root) = repo_root() {
                                let _ = Command::new("open").arg(root.join("data")).spawn();
                            }
                        }
                        "quit" => {
                            app.exit(0);
                        }
                        _ => {}
                    }
                })
                .build(app)?;

            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
