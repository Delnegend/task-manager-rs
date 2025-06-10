use std::collections::{HashMap, HashSet};

use procfs::ProcResult;

use crate::{
    manager::{
        Column, MyProcess, MyProcessID, SortOrder,
        traits::{
            sort_my_processes::SortMyProcesses, to_my_processes::ToMyProcesses,
            to_root_parents_and_children::ToRootParentsAndChildren,
        },
    },
    utils::{parse_search_query::parse_search_query, vec_take::VecTake},
};

struct MyProcessSortItem {
    pub id: MyProcessID,
    pub level: usize,
}

pub fn get_sorted_process_list(
    sort_by: &Column,
    sort_order: &SortOrder,
    search_term: &str,
) -> ProcResult<Vec<(MyProcess, usize)>> {
    let searches = parse_search_query(search_term);

    // reverse the sort order so we don't have to re-reverse when building the tree
    let sort_order = match sort_order {
        SortOrder::Ascending => &SortOrder::Descending,
        SortOrder::Descending => &SortOrder::Ascending,
    };

    let mut my_processes = procfs::process::all_processes()?.to_my_processes();
    let (mut root_parents, mut flatten_children) = my_processes.to_root_parents_and_children();

    if !searches.is_empty() {
        for search in searches {
            let mut retain_proc_ids = my_processes
                .iter()
                .filter_map(|proc| {
                    let search_col = search.column.to_lowercase();
                    if search_col == "file" {
                        if proc.files_using.iter().any(|file| {
                            file.to_string_lossy()
                                .to_lowercase()
                                .contains(&search.value.to_lowercase())
                        }) {
                            return Some(proc.id);
                        } else {
                            return None;
                        };
                    }

                    let a = match search_col.as_str() {
                        "id" => proc.id.to_string(),
                        "cpu" => proc.cpu_percent.to_string(),
                        "memory" => proc.memory_bytes.to_string(),
                        "parentid" => proc.parent_id.to_string(),
                        "state" => format!("{:?}", proc.state),
                        "starttime" => proc
                            .start_time
                            .map(|time| time.format("%Y-%m-%d %H:%M:%S").to_string())
                            .unwrap_or_else(|| "N/A".to_string()),
                        "user" => proc.user.clone(),
                        "command" => proc.command.clone(),
                        _ => proc.name.clone(),
                    };

                    let b = search.value;

                    if a.to_lowercase().contains(&b.to_lowercase())
                        || b.to_lowercase().contains(&a.to_lowercase())
                    {
                        Some(proc.id)
                    } else {
                        None
                    }
                })
                .collect::<HashSet<_>>();

            retain_proc_ids.extend({
                let proc_id_to_proc = my_processes
                    .iter()
                    .map(|proc| (proc.id, proc))
                    .collect::<HashMap<MyProcessID, &MyProcess>>();

                retain_proc_ids
                    .iter()
                    .fold(HashSet::new(), |mut acc, &proc_id| {
                        let Some(proc) = proc_id_to_proc.get(&proc_id) else {
                            unreachable!("Process ID {proc_id} not found in my_processes");
                        };
                        let mut parent_id = proc.parent_id;
                        while parent_id != 0 {
                            acc.insert(parent_id);
                            let Some(parent_proc) = proc_id_to_proc.get(&parent_id) else {
                                unreachable!("Process ID {parent_id} not found in my_processes");
                            };
                            parent_id = parent_proc.parent_id;
                        }
                        acc
                    })
            });

            root_parents.retain(|proc| retain_proc_ids.contains(&proc.id));
            flatten_children.retain(|_, children| {
                children.retain(|child| retain_proc_ids.contains(&child.id));
                !children.is_empty()
            });
        }
    }

    root_parents.sort(sort_by, sort_order);
    for fc in flatten_children.values_mut() {
        fc.sort(sort_by, sort_order);
    }

    let mut process_tree = vec![];
    let mut stacks = vec![];

    for root in root_parents.into_iter() {
        stacks.push(MyProcessSortItem {
            id: root.id,
            level: 0,
        });
    }

    while let Some(node) = stacks.pop() {
        let level = node.level;
        let id = node.id;
        process_tree.push(node);

        if let Some(child_processes) = flatten_children.get(&id) {
            for child in child_processes.iter() {
                stacks.push(MyProcessSortItem {
                    id: child.id,
                    level: level + 1,
                });
            }
        }
    }

    Ok(process_tree
        .iter()
        .filter_map(|item| {
            my_processes
                .iter()
                .position(|p| p.id == item.id)
                .and_then(|index| my_processes.take(index))
                .map(|process| (process, item.level))
        })
        .collect::<Vec<_>>())
}
