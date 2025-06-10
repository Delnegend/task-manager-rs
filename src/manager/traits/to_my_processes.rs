use procfs::{WithCurrentSystemInfo, process::ProcessesIter};
use tracing::warn;

use crate::manager::{
    MyProcess,
    traits::{
        command_string::CommandString, cpu_percent::CpuPercent, get_using_files::GetUsingFiles,
        memory_bytes::MemoryBytes, process_name::ProcessName, username::Username,
    },
};

pub trait ToMyProcesses {
    fn to_my_processes(self) -> Vec<MyProcess>;
}

impl ToMyProcesses for ProcessesIter {
    fn to_my_processes(self) -> Vec<MyProcess> {
        self.into_iter()
            .filter_map(|process| {
                let Ok(process) = process else {
                    warn!("Failed to get process: {:?}", process.err());
                    return None;
                };

                let Ok(ref stat) = process.stat() else {
                    warn!(
                        "Failed to get process stat for PID {}: {:?}",
                        process.pid(),
                        process.stat().err()
                    );
                    return None;
                };
                Some(MyProcess {
                    name: process.process_name(),
                    id: process.pid(),
                    parent_id: stat.ppid,
                    cpu_percent: stat.cpu_percent().unwrap_or_default(),
                    memory_bytes: process.memory_bytes(),
                    state: stat.state().into(),
                    start_time: stat.starttime().get().ok(),
                    user: process.username(),
                    command: process.command(),
                    files_using: process.using_files(),
                })
            })
            .collect()
    }
}
