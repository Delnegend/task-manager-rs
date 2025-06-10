use procfs::{Current, ProcResult, Uptime, process::Stat, ticks_per_second};

pub trait CpuPercent {
    fn cpu_percent(&self) -> ProcResult<f32>;
}

impl CpuPercent for Stat {
    fn cpu_percent(&self) -> ProcResult<f32> {
        let total_time_ticks = self.utime + self.stime;

        let clk_tck = ticks_per_second() as f32;
        if clk_tck <= 0.0 {
            return Ok(0.0);
        }

        let system_uptime_seconds = Uptime::current()?.uptime as f32;

        let process_starttime_seconds = self.starttime as f32 / clk_tck;

        let process_duration_seconds = system_uptime_seconds - process_starttime_seconds;
        if process_duration_seconds <= 0.0 {
            return Ok(0.0);
        }

        let process_cpu_time_seconds = total_time_ticks as f32 / clk_tck;

        let cpu_usage = (process_cpu_time_seconds / process_duration_seconds) * 10.0;

        Ok(cpu_usage)
    }
}
