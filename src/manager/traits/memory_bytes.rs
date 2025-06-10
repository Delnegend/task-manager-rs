use procfs::process::Process;

pub trait MemoryBytes {
    fn memory_bytes(&self) -> u64;
}

impl MemoryBytes for Process {
    fn memory_bytes(&self) -> u64 {
        self.statm()
            .map(|s| s.resident * 4096) // Convert pages to bytes
            .unwrap_or(0)
    }
}
