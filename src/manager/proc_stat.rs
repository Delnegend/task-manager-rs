use std::path::Path;

use procfs::{
    ProcResult,
    process::{FDTarget, Process, Stat},
};
use tokio::time::Duration;

#[derive(Debug)]
pub struct ProcStat {
    pub process: Process,
    pub stat: Stat,
}

pub trait ProcStatUtils {
    fn uname(&self) -> ProcResult<String>;
    fn using_file(&self, filepath: &Path) -> ProcResult<bool>;
    fn uptime(&self) -> Duration;
}

impl ProcStatUtils for ProcStat {
    fn uname(&self) -> ProcResult<String> {
        Ok(
            uzers::get_user_by_uid(self.process.uid()?).map_or("unknown".to_string(), |u| {
                u.name().to_string_lossy().to_string()
            }),
        )
    }

    fn using_file(&self, filepath: &Path) -> ProcResult<bool> {
        for fd_info in self.process.fd()? {
            if let Ok(fd_info) = fd_info {
                if let FDTarget::Path(path) = fd_info.target {
                    if path == filepath {
                        return Ok(true);
                    }
                }
            }
        }
        Ok(false)
    }

    fn uptime(&self) -> Duration {
        let tps = procfs::ticks_per_second();
        Duration::from_secs((self.stat.utime + self.stat.stime) as u64 / tps)
    }
}
