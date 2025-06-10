pub fn human_readable_byte(bytes: u64) -> String {
    if bytes < 1024 {
        return format!("{bytes} B");
    }
    let units = ["B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"];
    let mut value = bytes as f64;
    let mut unit_index = 0;

    while value >= 1024.0 && unit_index < units.len() - 1 {
        value /= 1024.0;
        unit_index += 1;
    }

    format!("{:.2} {}", value, units[unit_index])
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn test_human_readable_byte() {
        assert_eq!(human_readable_byte(500), "500 B");
        assert_eq!(human_readable_byte(1024), "1.00 KB");
        assert_eq!(human_readable_byte(2048), "2.00 KB");
        assert_eq!(human_readable_byte(1048576), "1.00 MB");
        assert_eq!(human_readable_byte(1073741824), "1.00 GB");
        assert_eq!(human_readable_byte(1099511627776), "1.00 TB");
        assert_eq!(human_readable_byte(1152921504606846976), "1.00 EB");
    }
}
