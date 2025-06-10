#[derive(Debug)]
pub struct Search<'a> {
    pub column: &'a str,
    pub value: &'a str,
}

pub fn parse_search_query(query: &str) -> Vec<Search> {
    if query.is_empty() {
        return Vec::new();
    }

    query
        .split(',')
        .filter_map(|part| {
            let parts = part
                .trim()
                .splitn(2, ' ')
                .map(|s| s.trim())
                .collect::<Vec<&str>>();
            if parts.len() != 2 {
                return None;
            }
            let column = parts[0].trim_start_matches('@');
            let value = parts[1];
            if !value.is_empty() {
                Some(Search { column, value })
            } else {
                None
            }
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_search_query() {
        let query = "   @name  foo, @command, @command bar, @pid 123";
        let searches = parse_search_query(query);
        println!("{:?}", searches);
        assert_eq!(searches.len(), 3);
        assert_eq!(searches[0].column, "name");
        assert_eq!(searches[0].value, "foo");
        assert_eq!(searches[1].column, "command");
        assert_eq!(searches[1].value, "bar");
        assert_eq!(searches[2].column, "pid");
        assert_eq!(searches[2].value, "123");
    }
}
