use std::collections::HashMap;

use procfs::ProcResult;

use super::proc_stat::ProcStat;

pub struct Manager {
    pub parents: Vec<ProcStat>,
    pub children: HashMap<i32, Vec<ProcStat>>,
}

impl Manager {
    pub fn refresh(&mut self) -> ProcResult<()> {
        let processes = procfs::process::all_processes()?
            .filter_map(|prc| {
                let process = prc.ok()?;
                let stat = process.stat().ok()?;
                Some(ProcStat { process, stat })
            })
            .collect::<Vec<_>>();

        self.parents.clear();
        self.children.clear();

        for ps in processes {
            if ps.stat.ppid == 0 {
                self.parents.push(ps);
            } else {
                self.children
                    .entry(ps.stat.ppid)
                    .or_insert_with(Vec::new)
                    .push(ps);
            }
        }

        Ok(())
    }

    pub fn new() -> ProcResult<Self> {
        let processes = procfs::process::all_processes()?
            .filter_map(|prc| {
                let process = prc.ok()?;
                let stat = process.stat().ok()?;
                Some(ProcStat { process, stat })
            })
            .collect::<Vec<_>>();

        let mut manager = Manager {
            parents: Vec::new(),
            children: HashMap::new(),
        };

        for ps in processes {
            if ps.stat.ppid == 0 {
                manager.parents.push(ps);
            } else {
                manager
                    .children
                    .entry(ps.stat.ppid)
                    .or_insert_with(Vec::new)
                    .push(ps);
            }
        }

        Ok(manager)
    }
}
