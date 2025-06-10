use procfs::process::{FDTarget, Process};
use std::path::PathBuf;

pub trait GetUsingFiles {
    fn using_files(&self) -> Vec<PathBuf>;
}

impl GetUsingFiles for Process {
    fn using_files(&self) -> Vec<PathBuf> {
        let mut files_using = vec![];

        if let Ok(fds) = self.fd() {
            for fd in fds.flatten() {
                if let FDTarget::Path(fd_path) = &fd.target {
                    if let Ok(canonical_fd_path) = fd_path.canonicalize() {
                        files_using.push(canonical_fd_path);
                    } else {
                        tracing::warn!(
                            "Failed to canonicalize fd path: {:?} for process: {}",
                            fd_path,
                            self.pid
                        );
                    }
                };
            }
        }

        files_using
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    // Helper function to find a specific process by PID and check its used files
    fn check_process_uses_file(pid: u32, file_path: &std::path::Path) -> bool {
        if let Ok(proc) = Process::new(pid as i32) {
            let canonical_file_path = file_path.canonicalize().unwrap();
            return proc.using_files().iter().any(|p| *p == canonical_file_path);
        }
        false
    }

    // Open for writing with exec (FD 3)
    #[test]
    fn test_process_uses_file_fd3() {
        let temp_file = tempfile::NamedTempFile::new().unwrap();
        let temp_file_path = temp_file.path().to_path_buf();
        let temp_file_path_str = temp_file_path.to_str().unwrap().to_string();

        let mut child = std::process::Command::new("sh")
            .arg("-c")
            .arg(format!(
                "exec 3> {}; echo 'This line is written to {} via FD 3.' >&3; sleep 10; exec 3>&-",
                &temp_file_path_str, &temp_file_path_str,
            ))
            .spawn()
            .expect("Failed to spawn process");

        std::thread::sleep(std::time::Duration::from_millis(200)); // Give time for process to open fd

        assert!(
            check_process_uses_file(child.id(), &temp_file_path),
            "Process {} should be using file {}",
            child.id(),
            temp_file_path.display()
        );

        let _ = child.kill();
        let _ = child.wait();
    }

    // Open for reading with exec (FD 4)
    #[test]
    fn test_process_uses_file_fd4() {
        let temp_file = tempfile::NamedTempFile::new().unwrap();
        let temp_file_path = temp_file.path().to_path_buf();
        let temp_file_path_str = temp_file_path.to_str().unwrap().to_string();

        // Ensure file has content for reading
        std::fs::write(&temp_file_path, "Some content for reading.").unwrap();

        let mut child = std::process::Command::new("sh")
            .arg("-c")
            .arg(format!(
                "exec 4< {}; sleep 10; exec 4>&-", // Removed cat, just hold fd open
                &temp_file_path_str
            ))
            .spawn()
            .expect("Failed to spawn process");

        std::thread::sleep(std::time::Duration::from_millis(200));

        assert!(
            check_process_uses_file(child.id(), &temp_file_path),
            "Process {} should be using file {}",
            child.id(),
            temp_file_path.display()
        );

        let _ = child.kill();
        let _ = child.wait();
    }

    // Open for reading and writing with exec (FD 5)
    #[test]
    fn test_process_uses_file_fd5() {
        let temp_file = tempfile::NamedTempFile::new().unwrap();
        let temp_file_path = temp_file.path().to_path_buf();
        let temp_file_path_str = temp_file_path.to_str().unwrap().to_string();

        let mut child = std::process::Command::new("sh")
            .arg("-c")
            .arg(format!(
                "exec 5<> {}; sleep 10; exec 5>&-",
                &temp_file_path_str
            ))
            .spawn()
            .expect("Failed to spawn process");

        std::thread::sleep(std::time::Duration::from_millis(200));

        assert!(
            check_process_uses_file(child.id(), &temp_file_path),
            "Process {} should be using file {}",
            child.id(),
            temp_file_path.display()
        );

        let _ = child.kill();
        let _ = child.wait();
    }
}
