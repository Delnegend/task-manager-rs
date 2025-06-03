mod manager;
use std::sync::Arc;

use manager::proc_stat::ProcStatUtils;
use procfs::ProcResult;
use slint::{ComponentHandle, ModelRc, VecModel};
use tokio::{sync::RwLock, time::Duration};

slint::include_modules!();

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let manager = Arc::new(RwLock::new(
        manager::Manager::new().expect("Failed to create manager"),
    ));

    let ui = AppWindow::new().expect("Failed to create UI");
    let ui_handle = ui.as_weak();

    let manager_clone = manager.clone();
    let refresh_thread = tokio::spawn(async move {
        loop {
            if let ProcResult::Err(e) = manager_clone.write().await.refresh() {
                eprintln!("Error refreshing process list: {}", e);
            };

            let processes_vec = manager_clone
                .read()
                .await
                .parents
                .iter()
                .map(|pc| ProcessProps {
                    name: pc
                        .process
                        .exe()
                        .map(|p| p.to_string_lossy().to_string())
                        .map(|s| s.replace('\n', " ").chars().take(50).collect::<String>())
                        .map(|s| s.into())
                        .unwrap_or("unknown".into()),
                    command: pc
                        .process
                        .cmdline()
                        .map(|c| c.join("/").into())
                        .unwrap_or("unknown".into()),
                    pid: pc.stat.pid,
                    ppid: pc.stat.ppid,
                    start_time: format!("{} seconds", pc.uptime().as_secs()).into(),
                    state: pc
                        .stat
                        .state()
                        .map(|s| format!("{s:?}").into())
                        .unwrap_or("unknown".into()),
                    user: pc.uname().map(|n| n.into()).unwrap_or("unknown".into()),
                    user_id: (pc.process.uid().unwrap_or(0) as i32).into(),
                })
                .collect::<Vec<_>>();

            let ui_handle = ui_handle.clone();
            let _ = slint::invoke_from_event_loop(move || {
                // Create ModelRc inside the event loop thread
                let processes = ModelRc::new(VecModel::from(processes_vec));

                if let Some(app) = ui_handle.upgrade() {
                    let ui_app_state = AppWindowState::get(&app);
                    ui_app_state.set_procs(processes);
                }
            });

            tokio::time::sleep(Duration::from_secs(5)).await;
        }
    });

    ui.run().expect("There was an error running the UI");
    refresh_thread.abort();

    Ok(())
}
