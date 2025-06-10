use crate::manager::{Column, MyProcess, SortOrder};

pub trait SortMyProcesses {
    fn sort(&mut self, sort_by: &Column, sort_order: &SortOrder);
}

impl SortMyProcesses for Vec<&MyProcess> {
    fn sort(&mut self, sort_by: &Column, sort_order: &SortOrder) {
        match sort_by {
            Column::Name => {
                self.sort_by(|a, b| {
                    a.name
                        .to_lowercase()
                        .partial_cmp(&b.name.to_lowercase())
                        .unwrap_or(std::cmp::Ordering::Equal)
                });
            }
            Column::ID => {
                self.sort_by_key(|p| p.id);
            }
            Column::CPU => {
                self.sort_by_key(|p| (p.cpu_percent * 100.0) as i32);
            }
            Column::Memory => {
                self.sort_by_key(|p| p.memory_bytes);
            }
            Column::ParentID => {
                self.sort_by_key(|p| p.parent_id);
            }
            Column::State => {
                self.sort_by_key(|p| p.state);
            }
            Column::StartTime => {
                self.sort_by_key(|p| p.start_time);
            }
            Column::User => {
                self.sort_by(|a, b| {
                    a.user
                        .to_lowercase()
                        .partial_cmp(&b.user.to_lowercase())
                        .unwrap_or(std::cmp::Ordering::Equal)
                });
            }
            Column::Command => {
                self.sort_by(|a, b| {
                    a.command
                        .to_lowercase()
                        .partial_cmp(&b.command.to_lowercase())
                        .unwrap_or(std::cmp::Ordering::Equal)
                });
            }
        }

        if sort_order == &SortOrder::Descending {
            self.reverse();
        }
    }
}
