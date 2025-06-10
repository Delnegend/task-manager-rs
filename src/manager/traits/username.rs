use procfs::process::Process;

pub trait Username {
    fn username(&self) -> String;
}

impl Username for Process {
    fn username(&self) -> String {
        self.uid()
            .map(|uid| {
                uzers::get_user_by_uid(uid).map_or("unknown".to_string(), |u| {
                    u.name().to_string_lossy().to_string()
                })
            })
            .unwrap_or("unknown".to_string())
    }
}
