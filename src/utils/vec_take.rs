pub trait VecTake<T> {
    fn take(&mut self, index: usize) -> Option<T>;
}

impl<T> VecTake<T> for Vec<T> {
    fn take(&mut self, index: usize) -> Option<T> {
        if index < self.len() {
            Some(self.remove(index))
        } else {
            None
        }
    }
}
