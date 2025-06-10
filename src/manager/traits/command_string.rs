use procfs::process::Process;

pub trait CommandString {
    fn command(&self) -> String;
}

impl CommandString for Process {
    fn command(&self) -> String {
        self.cmdline()
            .map_or_else(|_| "unknown".to_string(), |c| c.join(" "))
    }
}
