use std::{env, path::Path};

fn main() {
    println!("cargo:rerun-if-changed=ui/app.slint");
    slint_build::compile("ui/app.slint").unwrap();

    let re = regex::Regex::new(r#"\{ title: "([^"]+)" \}"#).unwrap();
    let contents = std::fs::read_to_string("ui/app.slint").unwrap();
    let column_names: Vec<&str> = re
        .captures_iter(&contents)
        .filter_map(|cap| cap.get(1).map(|m| m.as_str()))
        .collect();

    {
        let content_file = Path::new(&env::var("OUT_DIR").unwrap()).join("columns_order.rs");
        let new_content = format!(
            "pub const COLUMN_TITLES: [Column; {}] = [{}];",
            column_names.len(),
            column_names
                .iter()
                .map(|title| format!("Column::{}", title.replace(" ", "")))
                .collect::<Vec<_>>()
                .join(", ")
        );
        let old_content = std::fs::read_to_string(&content_file).unwrap_or_default();
        if new_content != old_content {
            std::fs::write(&content_file, new_content).unwrap();
        }
    }

    {
        let content_file = Path::new(&env::var("OUT_DIR").unwrap()).join("column_enum.rs");
        let new_content = format!(
            "#[allow(clippy::upper_case_acronyms)]
#[derive(Debug, Default, Clone)]
pub enum Column {{
    #[default]
{}
}}",
            column_names
                .iter()
                .map(|title| format!("    {},", title.replace(" ", "")))
                .collect::<Vec<_>>()
                .join("\n")
        );
        let old_content = std::fs::read_to_string(&content_file).unwrap_or_default();
        if new_content != old_content {
            std::fs::write(&content_file, new_content).unwrap();
        }
    }
}
