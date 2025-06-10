mod manager;
mod utils;

use std::sync::{Arc, RwLock};

use nix::{sys::signal, unistd::Pid};
use slint::{ComponentHandle, SharedString};
use tokio::{select, sync::mpsc, time::Duration};
use tracing::error;

use crate::manager::{
    Column, MyProcess, SortOrder, ToStandardListViewItems,
    get_sorted_process_list::get_sorted_process_list,
};

include!(concat!(env!("OUT_DIR"), "/columns_order.rs"));
slint::include_modules!();

#[derive(Debug, Default)]
struct BackendAppState {
    search_term: RwLock<String>,
    sort_order: RwLock<SortOrder>,
    sort_by: RwLock<Column>,
    curr_proc_list: RwLock<Vec<(MyProcess, usize)>>,
    request_terminate_proc: RwLock<Option<(String, i32)>>,
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .init();
    let ui = AppWindow::new().expect("Failed to create UI");

    let backend_state = Arc::new(BackendAppState::default());
    let (f5_req_send, mut f5_req_recv) = mpsc::channel::<()>(1);

    let backend_state_clone = backend_state.clone();
    let f5_req_send_clone = f5_req_send.clone();
    ui.on_sort_ascending(move |sort_by| {
        let Some(sort_by_column) = COLUMN_TITLES.get(sort_by as usize) else {
            error!("Invalid sort column index: {sort_by}");
            return;
        };
        {
            let Ok(mut sort_order) = backend_state_clone.sort_order.write() else {
                error!("Failed to get write lock on sort order");
                return;
            };
            let Ok(mut sort_by) = backend_state_clone.sort_by.write() else {
                error!("Failed to get write lock on sort by");
                return;
            };
            sort_order.clone_from(&SortOrder::Ascending);
            sort_by.clone_from(sort_by_column);
        }
        if let Err(e) = f5_req_send_clone.try_send(()) {
            error!("Failed to send F5 request: {e}");
        }
    });

    let f5_req_send_clone = f5_req_send.clone();
    let backend_state_clone = backend_state.clone();
    ui.on_sort_descending(move |sort_by| {
        #[allow(clippy::cast_sign_loss)]
        let Some(sort_by_column) = COLUMN_TITLES.get(sort_by as usize) else {
            error!("Invalid sort column index: {sort_by}");
            return;
        };
        {
            let Ok(mut sort_order) = backend_state_clone.sort_order.write() else {
                error!("Failed to get write lock on sort order");
                return;
            };
            let Ok(mut sort_by) = backend_state_clone.sort_by.write() else {
                error!("Failed to get write lock on sort by");
                return;
            };
            sort_order.clone_from(&SortOrder::Descending);
            sort_by.clone_from(sort_by_column);
        }
        if let Err(e) = f5_req_send_clone.try_send(()) {
            error!("Failed to send F5 request: {e}");
        }
    });

    let f5_req_send_clone = f5_req_send.clone();
    let backend_state_clone = backend_state.clone();
    ui.on_search_query_changed(move |search_query| {
        let search_query = search_query.trim().to_string();
        'scoped: {
            let Ok(mut search_term) = backend_state_clone.search_term.write() else {
                error!("Failed to get write lock on search term");
                break 'scoped;
            };
            if search_query.is_empty() {
                search_term.clear();
                break 'scoped;
            }
            if let Some(search_query) = search_query.strip_prefix('@') {
                let search_query = search_query.trim().to_string();
                let mut split_result = search_query.splitn(2, ' ');
                let (Some(col), Some(val)) = (split_result.next(), split_result.next()) else {
                    search_term.clear();
                    break 'scoped;
                };
                search_term.clear();
                search_term.push_str(&format!("{} {}", col, val));
            } else {
                search_term.clear();
                search_term.push_str(&search_query);
            }
        }
        if let Err(e) = f5_req_send_clone.try_send(()) {
            error!("Failed to send F5 request: {e}");
        }
    });

    let ui_handle = ui.as_weak();
    let backend_state_clone = backend_state.clone();
    ui.on_request_terminate_process(move |proc_idx| {
        let Some(app_window) = ui_handle.upgrade() else {
            error!("Failed to upgrade UI handle");
            return;
        };

        let target_proc = {
            let Ok(proc_list) = backend_state_clone.curr_proc_list.read() else {
                error!("Failed to get read lock on current process list");
                return;
            };
            proc_list
                .get(proc_idx as usize)
                .map(|(proc, _)| (proc.name.clone(), proc.id))
        };

        {
            let Ok(mut request_terminate_proc) = backend_state_clone.request_terminate_proc.write()
            else {
                error!("Failed to get write lock on request terminate process");
                return;
            };
            *request_terminate_proc = target_proc.clone();
        }

        AppWindowState::get(&app_window).set_to_be_terminated_process(SharedString::from(format!(
            "{} ({})",
            target_proc.as_ref().map_or("Unknown", |(name, _)| name),
            target_proc.as_ref().map_or(-1, |(_, id)| *id)
        )));
    });

    let backend_state_clone = backend_state.clone();
    let ui_handle = ui.as_weak();
    ui.on_confirm_terminate_process(move || {
        let Some(app_window) = ui_handle.upgrade() else {
            error!("Failed to upgrade UI handle");
            return;
        };

        if let Err(e) = signal::kill(
            Pid::from_raw(
                backend_state_clone
                    .request_terminate_proc
                    .read()
                    .expect("Failed to get read lock on request terminate process")
                    .as_ref()
                    .map_or(-1, |(_, id)| *id),
            ),
            signal::Signal::SIGTERM,
        ) {
            error!("Failed to terminate process: {e}");
        } else {
            AppWindowState::get(&app_window).set_to_be_terminated_process(SharedString::from(""));
        }
    });

    let ui_handle = ui.as_weak();
    let backend_state_clone = backend_state.clone();
    let refresh_thread = tokio::spawn(async move {
        loop {
            let backend_state_clone = backend_state_clone.clone();
            let ui_handle = ui_handle.clone();

            let _ = slint::invoke_from_event_loop(move || {
                let Ok(sort_order) = backend_state_clone.sort_order.read() else {
                    error!("Failed to get read lock on sort order");
                    return;
                };
                let Ok(sort_by) = backend_state_clone.sort_by.read() else {
                    error!("Failed to get read lock on sort by");
                    return;
                };
                let Ok(search_term) = backend_state_clone.search_term.read() else {
                    error!("Failed to get read lock on search term");
                    return;
                };
                let Some(app_window) = ui_handle.upgrade() else {
                    error!("Failed to upgrade UI handle");
                    return;
                };

                let Ok(processes) = get_sorted_process_list(&sort_by, &sort_order, &search_term)
                else {
                    error!("Failed to get sorted process list");
                    return;
                };
                let Ok(mut curr_proc_list) = backend_state_clone.curr_proc_list.write() else {
                    error!("Failed to get write lock on current process list");
                    return;
                };
                *curr_proc_list = processes;

                AppWindowState::get(&app_window)
                    .set_procs(curr_proc_list.to_standard_list_view_items());
            });

            select! {
                _ = tokio::time::sleep(Duration::from_secs(3)) => (),
                _ = f5_req_recv.recv() => (),
            }
        }
    });

    ui.run().expect("There was an error running the UI");
    refresh_thread.abort();

    Ok(())
}
