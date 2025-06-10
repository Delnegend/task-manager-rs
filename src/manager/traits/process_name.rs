use procfs::process::Process;

pub trait ProcessName {
    fn process_name(&self) -> String;
}

impl ProcessName for Process {
    fn process_name(&self) -> String {
        self.exe()
            .map(|p| {
                p.file_name()
                    .unwrap_or_default()
                    .to_string_lossy()
                    .to_string()
            })
            .unwrap_or("unknown".to_string())
    }
}
