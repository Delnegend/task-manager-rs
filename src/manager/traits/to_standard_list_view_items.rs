use slint::{ModelRc, SharedString, StandardListViewItem, VecModel};

use crate::{manager::MyProcess, utils::human_readable_byte::human_readable_byte};

pub trait ToStandardListViewItems {
    fn to_standard_list_view_items(&self) -> ModelRc<ModelRc<StandardListViewItem>>;
}

impl ToStandardListViewItems for Vec<(MyProcess, usize)> {
    fn to_standard_list_view_items(&self) -> ModelRc<ModelRc<StandardListViewItem>> {
        ModelRc::new(VecModel::from(
            self.iter()
                .map(|(process, indent)| {
                    ModelRc::new(VecModel::from(
                        vec![
                            format!("{}{}", "  ".repeat(indent * 2), process.name),
                            format!("{}", process.id),
                            format!("{:.1}%", process.cpu_percent),
                            format!("{}", human_readable_byte(process.memory_bytes)),
                            format!("{}", process.parent_id),
                            format!("{:?}", process.state),
                            // format!("{} seconds", process.start_time),
                            process
                                .start_time
                                .map(|time| time.format("%Y-%m-%d %H:%M:%S").to_string())
                                .unwrap_or_else(|| "N/A".to_string()),
                            format!("{}", process.user),
                            process.command.clone(),
                        ]
                        .into_iter()
                        .map(SharedString::from)
                        .map(StandardListViewItem::from)
                        .collect::<Vec<_>>(),
                    ))
                })
                .collect::<Vec<_>>(),
        ))
    }
}
