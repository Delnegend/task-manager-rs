use std::collections::HashMap;

use crate::manager::MyProcess;

pub trait ToRootParentsAndChildren {
    fn to_root_parents_and_children(&self) -> (Vec<&MyProcess>, HashMap<i32, Vec<&MyProcess>>);
}

impl ToRootParentsAndChildren for Vec<MyProcess> {
    fn to_root_parents_and_children(&self) -> (Vec<&MyProcess>, HashMap<i32, Vec<&MyProcess>>) {
        let mut root_parents = Vec::new();
        let mut children = HashMap::new();

        for process in self {
            if process.parent_id == 0 {
                root_parents.push(process);
            } else {
                children
                    .entry(process.parent_id)
                    .or_insert_with(Vec::new)
                    .push(process);
            }
        }

        (root_parents, children)
    }
}
