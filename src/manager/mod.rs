use std::path::PathBuf;

use chrono::{DateTime, Local};
use procfs::{ProcResult, process::ProcState};

pub mod get_sorted_process_list;
mod traits;
pub use traits::to_standard_list_view_items::ToStandardListViewItems;

include!(concat!(env!("OUT_DIR"), "/column_enum.rs"));

type MyProcessID = i32;

#[derive(Debug, Clone)]
pub struct MyProcess {
    pub name: String,
    pub id: MyProcessID,
    pub parent_id: MyProcessID,
    pub cpu_percent: f32,
    pub memory_bytes: u64,
    pub state: MyProcState,
    pub start_time: Option<DateTime<Local>>,
    pub user: String,
    pub command: String,

    pub files_using: Vec<PathBuf>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum SortOrder {
    #[default]
    Ascending,
    Descending,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub enum MyProcState {
    Running,
    Sleeping,
    Waiting,
    Zombie,
    Stopped,
    Tracing,
    Dead,
    Wakekill,
    Waking,
    Parked,
    Idle,
    Unknown,
}

impl From<ProcResult<ProcState>> for MyProcState {
    fn from(state: ProcResult<ProcState>) -> Self {
        match state {
            Ok(ProcState::Running) => Self::Running,
            Ok(ProcState::Sleeping) => Self::Sleeping,
            Ok(ProcState::Waiting) => Self::Waiting,
            Ok(ProcState::Zombie) => Self::Zombie,
            Ok(ProcState::Stopped) => Self::Stopped,
            Ok(ProcState::Tracing) => Self::Tracing,
            Ok(ProcState::Dead) => Self::Dead,
            Ok(ProcState::Wakekill) => Self::Wakekill,
            Ok(ProcState::Waking) => Self::Waking,
            Ok(ProcState::Parked) => Self::Parked,
            Ok(ProcState::Idle) => Self::Idle,
            Err(_) => Self::Unknown,
        }
    }
}
