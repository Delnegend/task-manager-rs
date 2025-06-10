use procfs::process::Process;

pub trait MemoryBytes {
    fn memory_bytes(&self) -> u64;
}

impl MemoryBytes for Process {
    fn memory_bytes(&self) -> u64 {
        self.statm()
            .map(|s| {
                s.resident
                    .saturating_sub(s.shared)
                    .saturating_mul(procfs::page_size())
            }) // Convert pages to bytes
            .unwrap_or(0)
    }
}
