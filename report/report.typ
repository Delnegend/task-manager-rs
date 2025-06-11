// =========== DOCUMENT CONFIGS ===========
// #let printing-layout = true;
#show link: underline
#set text(font: "Noto Serif", size: 12pt, hyphenate: false)
#set quote(block: true)
#show raw: set text(font: "Iosevka NF")
#set par(justify: false)
#set heading(numbering: "1.")
#set page(paper: "a4")

#let page-margin = auto;
// #if printing-layout { page-margin = (inside: 2.5cm, outside: 1.7cm, y: 1.75cm) }
// #set page(margin: page-margin)

// =========== COVER ===========
#table(gutter: 0em, inset: 2em, stroke: 2pt, columns: 100%, rows: 100%)[
  #set align(center)
  #text(18pt)[Viettel Digital Talent 2025]

  #text(18pt)[*MINI-PROJECT PHASE I*]

  // #pad(top: 3em, left: 3.5em)[#image("image/usth-logo.png", width: 18em)]

  // #text(20pt)[Initial]

  #pad(top: 12em, bottom: 3em)[#text(25pt)[*FINAL REPORT*]]

  #text(size: 1.5em)[By\ *Nguyễn Thế Kiên*\ Software Engineering | System]

  #align(center)[#text(20pt, weight: "bold")[Task Manager for Linux]]

  #pad(top: 4em)[#text(size: 1.5em)[Mentor: Mr. Nguyễn Ngọc Anh]]

  #align(center + bottom)[#text(20pt)[*Hanoi, 2025*]]
]

#set page(numbering: "1 of 1")
#outline()
#pagebreak()

= Introduction

This report details the design, implementation, and evaluation of a Task Manager tool developed to monitor and manage processes on Linux systems. Inspired by advanced tools like Windows' Process Explorer and Gnome's System Monitor, this application provides a comprehensive view of running processes, their hierarchical relationships, and resource consumption. The primary goal is to offer a robust, efficient, and user-friendly solution for system oversight.

= Background

Modern operating systems execute numerous processes concurrently, making system monitoring and management crucial for performance, security, and troubleshooting. While basic tools like `htop` or `ps` provide simple process information, they often lack the detailed hierarchical view, advanced search capabilities, and process control that more sophisticated applications offer.

This project addresses this gap by providing a Task Manager for Linux, focusing on a tree-like display of processes to illustrate parent-child relationships clearly. The tool is designed to be compatible with all Linux distros, adhering to strict resource utilization thresholds, and built with object-oriented principles, including unit tests and security considerations.

The core of the application leverages Rust for its performance and safety features, combined with the Slint UI toolkit for a responsive and native-looking graphical interface.

= System Analysis

The Task Manager tool is designed to meet specific functional and non-functional requirements.

== Functional Requirements

#set text(hyphenate: true)
#table(
  columns: (1fr, 2fr),
  table.header([*Requirement*], [*Approach*]),
  [Display all processes running on the machine in a parent-child tree format],
  [The tool reads process information from the\ `/proc` filesystem and reconstructs the parent-child relationships using PID and PPID.],

  [Display process information including: PID, PPID, state, user name, start time, command line],
  [Data is gathered from `procfs` for each process and then mapped to a custom struct for more convenient handling.],

  [Search for processes by command line],
  [A search input field filters the displayed processes based on the provided query, supporting both simple text and column-specific searches.],

  [Given a file name, search for processes that are opening this file],
  [The tool inspects the file descriptors (`/proc/[pid]/fd`) for each process to determine which files are currently open, and this information is integrated into the search.],

  [Kill a selected process], [The tool sends a `SIGTERM` signal to the selected process's PID.],
  [Package the installation package for the tool],
  [The binaries are packaged into `.deb` and `.rpm` formats using `cargo-deb` and `cargo-generate-rpm`.],
)

== Non-functional Requirements:

#table(
  columns: (1fr, 2fr),
  table.header([*Requirement*], [*Approach*]),
  [The tool is compatible with Linux distros: Ubuntu 24.04, CentOS 7],
  [Reliance on standard Linux kernel interfaces (`/proc` filesystem) and Rust's cross-compilation capabilities ensures compatibility. `procfs` and `nix` crates are used for Linux-specific system interactions without relying on distro-specific libraries.],

  [The tool interface does not break the layout on screens with different resolutions],
  [Slint UI toolkit's layout managers (`VerticalLayout`, `HorizontalLayout`) and flexible sizing properties are used to achieve responsiveness.],

  [The resources occupied by the client and server during operation do not exceed the following threshold: CPU < 5% on 1 core, Memory < 100 MB],
  [Rust's low-level performance, combined with the use of efficient data structures and optimized algorithms for processing data, minimizes CPU and memory usage.],

  [The project is designed, organized in an object-oriented manner, and has unit tests for classes],
  [The codebase is structured into modules (`manager`, `utils`) and utilizes traits (`CommandString`, `CpuPercent`, `GetUsingFiles`, etc.) to define interfaces and achieve polymorphism, adhering to object-oriented principles. Unit tests are included for key functionalities.],

  [The tool does not have common security errors: Buffer Overflow, Integer Overflow, Format String, Race Condition, Type Confusion],
  [Rust's memory safety features (ownership, borrowing) inherently mitigate many common memory and concurrently-related security vulnerabilities like buffer overflows and race conditions.],
)
#set text(hyphenate: false)

== Technology Stack Choice: Rust and Slint vs. C++ and Qt/QML

The choice of Rust and Slint for this project was deliberate, prioritizing security, performance, and modern development practices.

#table(
  columns: (auto, 1fr, 1fr),
  table.header([*Feature*], [*Rust/Slint*], [*C++/Qt/QML*]),
  [Memory Safety],
  [Guaranteed by ownership/borrowing system; compile-time prevention of buffer overflows, use-after-free, etc @understanding-ownership.],
  [Manual memory management; prone to buffer overflows, use-after-free, requiring rigorous testing.],

  [Concurrency],
  [Strong guarantees for thread safety; prevents data races at compile time.],
  [Relies on developer discipline for thread safety; more prone to subtle concurrency bugs.],

  [Runtime\ Overhead],
  [Lean architecture, efficient, designed for embedded devices #footnote[#link("slint.dev/videos#slint-rp2040")[Slint on Raspberry Pi Pico / RP2040 with 264K of RAM]].],
  [Larger runtime footprint; QML's QJSEngine introduces JavaScript memory overhead #footnote[#link("www.youtube.com/watch?v=77LH_I_Vx5E")[QtWS15- A deep dive into QML memory management internals, Frank Meerkötter, basysKom GmbH - Qt Group - YouTube]].],

  [*Testing*],
  [Less extensive testing required for memory safety due to compile-time guarantees.],
  [More rigorous and complex testing required due to manual memory management and potential security flaws.],
)

= System Design

The system is designed with a clear separation of concerns, dividing functionality into UI, business logic manager, and utility layers.

== Architecture Overview

The application follows a client-server-like architecture where the Slint UI acts as the client and the Rust backend processes system data. The interaction is facilitated by Slint's event loop and shared state mechanisms.

#figure(image("overview.png", width: 60%), caption: "System Architecture Overview")

- *UI Layer (`ui/app.slint`):* Handles user interaction, displays data, and triggers backend operations.
- *Backend/Manager Layer (`main.rs`, `manager/`):* Fetches, processes, and organizes process data. Implements business logic for sorting, filtering, and process control.
- *Utility Layer (`utils/`):* Provides general-purpose helper functions.



== Data Structures

- `MyProcess` (in `manager/mod.rs`): Represents a process with normalized data:
  ```rust
  #[derive(Debug, Clone)]
  pub struct MyProcess {
      pub name: String,
      pub id: MyProcessID,
      pub parent_id: MyProcessID,
      pub cpu_percent: f32,
      pub memory_bytes: u64,
      pub state: MyProcState,
      pub start_time: Option<DateTime<Local>>,
      pub user: String,
      pub command: String,
      pub files_using: Vec<PathBuf>,
  }
  ```

- `Column` (generated by `build.rs`): An enum representing sortable columns (Name, ID, CPU, Memory, ParentID, State, StartTime, User, Command).
- `SortOrder` (in `manager/mod.rs`): An enum for Ascending or Descending sort order.
- `MyProcState` (in `manager/mod.rs`): An enum mapping `procfs::process::ProcState` #footnote[#link("https://docs.rs/procfs/latest/procfs/process/struct.Process.html")[docs.rs/procfs/latest/procfs/process/struct.Process.html]] to a more structured type.
- `Search` (in `utils/parse_search_query.rs`): A struct used to parse search queries, containing column and value.
- `BackendAppState` (in `main.rs`): An `Arc<RwLock<...>>` holding the mutable state shared between the UI and backend, including process data and search queries.

== Key Modules and Traits:

The manager module is central to the backend logic, extensively using traits to extend functionality to procfs types and MyProcess vectors.

- `manager/traits/to_my_processes.rs`: Converts `procfs::process::ProcessesIter` #footnote[#link("docs.rs/procfs/latest/procfs/process/struct.ProcessesIter.html")[docs.rs/procfs/latest/procfs/process/struct.ProcessesIter.html]] into `Vec<MyProcess>`. It iterates through all processes, gathers relevant information (name, PID, PPID, CPU, memory, state, start time, user, command, open files), and constructs `MyProcess` objects.
  ```rust
  impl ToMyProcesses for ProcessesIter {
      fn to_my_processes(self) -> Vec<MyProcess> {
          self.into_iter()
              .filter_map(|process| { /* ... logic ... */ })
              .collect()
      }
  }
  ```

- `manager/traits/cpu_percent.rs`: Calculates CPU usage percentage for a process based on its Stat information.
  ```rust
  impl CpuPercent for Stat {
      fn cpu_percent(&self) -> ProcResult<f32> { /* ... calculation ... */ }
  }
  ```

- `manager/traits/get_procs_using_file.rs`: Identifies files opened by a given process by inspecting `/proc/[pid]/fd`.
  ```rust
  impl GetUsingFiles for Process {
      fn using_files(&self) -> Vec<PathBuf> { /* ... logic to read fds ... */ }
  }
  ```

- `manager/traits/sort_my_processes.rs`: Provides sorting capabilities for a vector of `MyProcess` references based on a specified Column and SortOrder.
  ```rust
  impl SortMyProcesses for Vec<&MyProcess> {
      fn sort(&mut self, sort_by: &Column, sort_order: &SortOrder) { /* ... sorting logic ... */ }
  }
  ```

- `manager/traits/to_root_parents_and_children.rs`: Transforms a flat list of `MyProcess` objects into a tuple containing a vector of root processes and a hash map of parent PIDs to their child processes, enabling tree construction.
  ```rust
  impl ToRootParentsAndChildren for Vec<MyProcess> {
      fn to_root_parents_and_children(&self) -> (Vec<&MyProcess>, HashMap<i32, Vec<&MyProcess>>) {
          // ... logic to build root_parents and children maps ...
      }
  }
  ```

- `manager/get_sorted_process_list.rs`: The main function orchestrates process data retrieval, filtering, sorting, and tree construction.
  - *Process Tree Generation:* After gathering all processes, it first identifies root processes (PPID 0) and builds a map of parent-to-child relationships. It then performs a depth-first traversal, pushing processes onto a stack to maintain the correct display order and level of indentation.
  - *Search Mechanism:*
    - The `utils/parse_search_query.rs` module parses search strings like `@name foo, @command bar`.
    - The `get_sorted_process_list` function filters `MyProcess` objects based on the parsed search terms. If a file search (`@file`) is specified, it uses the `files_using` field populated by the `GetUsingFiles` trait. For other columns, it performs a case-insensitive substring match.
    - Crucially, when processes are filtered by search, their parent processes are also included in the results to maintain the tree context, even if the parent itself doesn't match the search term directly.
- *Process Termination:*
  - The UI exposes a `request-terminate-process` callback, which populates a shared state (`to-be-terminated-process`) with the selected process's name and ID.
  - A confirmation pop-up is shown. Upon user confirmation via `confirm-terminate-process`, the `nix::sys::signal::kill` #footnote[#link("https://docs.rs/nix/0.30.1/nix/sys/signal/fn.kill.html")[docs.rs/nix/0.30.1/nix/sys/signal/fn.kill.html]] function is called with `SIGTERM` on the target process's PID.

== Concurrency and State Management

- The `main.rs` uses `tokio` for asynchronous operations.
- A dedicated `tokio::spawn` #footnote[#link("https://docs.rs/tokio/latest/tokio/task/fn.spawn.html")[docs.rs/tokio/latest/tokio/task/fn.spawn.html]] thread (`refresh_thread`) periodically fetches and updates the process list (every 3 seconds or on a UI-triggered refresh).
- `std::sync::RwLock` #footnote[#link("https://doc.rust-lang.org/std/sync/struct.RwLock.html")[doc.rust-lang.org/std/sync/struct.RwLock.html]] is used for safe concurrent access to shared backend state between the UI thread and the background refresh thread.
- `mpsc::channel` #footnote[#link("https://docs.rs/tokio/latest/tokio/sync/mpsc/index.html")[docs.rs/tokio/latest/tokio/sync/mpsc/index.html]] is used for explicit signals (e.g., immediate refresh on sort/search changes).

= Implementation

The implementation leverages Rust's strong type system and performance characteristics, combined with the declarative UI capabilities of Slint.

== UI Implementation

The `app.slint` file defines the entire user interface.

- *Root Window:* `AppWindow` inherits `Window` #footnote[#link("docs.slint.dev/latest/docs/slint/reference/window/window/")[docs.slint.dev/latest/docs/slint/reference/window/window/]], setting the title and preferred dimensions.
- *Layout:* A `VerticalLayout` #footnote[#link("docs.slint.dev/latest/docs/slint/reference/layouts/verticallayout/")[docs.slint.dev/latest/docs/slint/reference/layouts/verticallayout/]] organizes the top bar (search input, terminate button) and the main `StandardTableView` #footnote[#link("docs.slint.dev/latest/docs/slint/reference/std-widgets/views/standardtableview/")[docs.slint.dev/latest/docs/slint/reference/std-widgets/views/standardtableview/]].
- *Search Bar:* A `TextInput` for search queries and a `Button` #footnote[#link("docs.slint.dev/latest/docs/slint/reference/std-widgets/basic-widgets/button/")[docs.slint.dev/latest/docs/slint/reference/std-widgets/basic-widgets/button/]] for termination.
- *Process Table:* `StandardTableView` displays process data. It defines columns ("Name", "ID", "CPU", "Memory", "Parent ID", "State", "Start Time", "User", "Command").
- *Data Binding:* `rows: AppWindowState.procs`; binds the table data to the `procs` property, which is updated by the Rust backend.
- *Interactions:*
  - `search-query-changed` callback is triggered when the search input changes.
  - `sort-ascending` and `sort-descending` callbacks handle column sorting.
  - `row-pointer-event` captures clicks to select a process (`selected-process-idx`).
  - `request-terminate-process` and `confirm-terminate-process` handle the process termination flow.
- *Confirmation Popup:* `PopupWindow` #footnote[#link("https://docs.slint.dev/latest/docs/slint/reference/window/popupwindow/")[docs.slint.dev/latest/docs/slint/reference/window/popupwindow/]] is used for the process termination confirmation dialog.

== Backend Logic (`main.rs`, `manager/`)

- *Initialization (main.rs):*
  - `tracing_subscriber` #footnote[#link("https://docs.rs/tracing-subscriber/latest/tracing_subscriber/")[docs.rs/tracing-subscriber/latest/tracing_subscriber/]] is initialized for logging.
  - `AppWindow::new()` creates the UI instance from the Slint UI definition, auto-generated using the `slint::include_modules!()` #footnote[#link("https://docs.rs/slint/latest/slint/macro.include_modules.html")[docs.rs/slint/latest/slint/macro.include_modules.html]] macro.
  - `BackendAppState` holds the application's mutable state behind a read-write lock and an `Arc` pointer, allowing safe sharing and mutability across threads.
  - `tokio::spawn` #footnote[#link("https://docs.rs/tokio/latest/tokio/task/fn.spawn.html")[docs.rs/tokio/latest/tokio/task/fn.spawn.html]] creates a background thread for refreshing process data.

#pagebreak()

- *Process Data Refresh Loop:*
  - The refresh thread runs an infinite loop, fetching processes using `get_sorted_process_list`.
  - `slint::invoke_from_event_loop` #footnote[#link("https://docs.rs/slint/latest/slint/fn.invoke_from_event_loop.html")[docs.rs/slint/latest/slint/fn.invoke_from_event_loop.html]] is used to update UI properties from the background thread safely.
  - It waits for either a 3-second timeout or a refresh signal (from UI sort/search changes), ensuring both periodic and immediate updates.

- *Process Information Retrieval:* The `manager/traits/to_my_processes.rs` module converts raw `procfs`'s processes data into structured `MyProcess` objects, adding derived information like CPU percentage and memory usage.

- *Search and Sort Implementation:* The `get_sorted_process_list` function (in `manager/get_sorted_process_list.rs`) is responsible for applying search filters and sorting to the process list before it's displayed. It handles the parsing of search queries and constructs the parent-child tree.

- *Process Termination:* When the "Terminate" button is clicked and confirmed, the `confirm_terminate_process` callback in `main.rs` uses `nix`'s `signal::kill` to send a `SIGTERM` to the target process.

== Unit Tests

Unit tests are included for critical utility functions and traits, ensuring the correctness of core logic.

- `utils/parse_search_query.rs`: Tests `parse_search_query` for correct parsing of search strings.
- `manager/traits/get_procs_using_file.rs`: Contains tests that spawn dummy processes opening specific files and verify that the `using_files` trait correctly identifies them.
- `utils/human_readable_byte.rs`: Tests `human_readable_byte` for correct formatting of byte sizes.
- `utils/vec_take.rs`: Tests `VecTake` for safe removal of elements from a vector.

== Build Process `(build.rs`)

The `build.rs` script plays a critical role in the application's compilation, particularly for integrating the Slint UI. This script runs before the main compilation begins and performs several essential tasks:

1. *Slint UI Compilation:* It uses `slint_build::compile("ui/app.slint").unwrap();` to compile the `app.slint` UI definition file. This step generates Rust code from the Slint declarative UI, making it available for use in the backend.

2. *Column Metadata Generation:* The script reads the `ui/app.slint` file to extract column titles defined in the `StandardTableView`. It then generates two Rust files inside the `target/` directory:
  - `columns_order.rs`: Defines a constant array `COLUMN_TITLES` containing the `Column` enum variants to the UI table columns. This ensures that the backend's sorting logic is synchronized with the UI's column definitions.
  - `column_enum.rs`: Generates the `Column` enum itself, with variants derived from the column titles in `app.slint`. This dynamic generation helps prevent inconsistencies between the UI and backend column definitions.
  - The `println!("cargo:rerun-if-changed=ui/app.slint");` line ensures that `build.rs` is re-run if `app.slint` changes, regenerating the Rust code and keeping everything synchronized.

This automated generation process simplifies UI-backend data synchronization and reduces manual maintenance.

== Packaging and Installation

The tool's binaries are packaged into distribution-specific formats. This is achieved using `cargo-deb` #footnote[#link("https://crates.io/crates/cargo-deb")[crates.io/crates/cargo-deb]] for Debian/Ubuntu packages and `cargo-generate-rpm` #footnote[#link("https://crates.io/crates/cargo-generate-rpm")[crates.io/crates/cargo-generate-rpm]] for Red Hat/CentOS packages. The packaging process is automated using `just` #footnote[A script runner, similar but better than `make`. #link("https://github.com/casey/just")[github.com/casey/just]], which orchestrates the build and packaging steps:
```justfile
# building the final binary using the release preset
build-release:
    cargo build --release

# packaging the binary into .rpm and moving it to ./dist/
package-rpm: build-release
    @mkdir -p ./dist
    cargo generate-rpm
    @find target/generate-rpm -name "\*.rpm" -exec mv {} ./dist/ \;

# packaging the binary into .deb and moving it to ./dist/
package-deb: build-release
    @mkdir -p ./dist
    cargo deb
    @find target/debian/ -name "\*.deb" -exec mv {} ./dist/ \;
```

The Cargo.toml includes metadata for both `cargo-deb` and `cargo-generate-rpm` to define package specifics, such as maintainer information, copyright details, license file paths, extended descriptions, and the target installation path and permissions for the executable:

#pagebreak()

```toml
[package.metadata.deb]
maintainer = "..."
copyright = "..."
license-file = ["..."]
extended-description = "..."

[package.metadata.generate-rpm]
assets = [
    { source = "target/release/task-manager-rs", dest = "/usr/bin/task-manager-rs", mode = "0755" },
]
```

= Results

The Task Manager tool successfully addresses the majority of the specified requirements, providing a functional solution for process monitoring on Linux.

- *Display processes in parent-child tree format along with their information:* The `get_sorted_process_list` function, combined with the `ToRootParentsAndChildren` trait, correctly builds and displays the process hierarchy. Indentation in the "Name" column visually represents the tree structure; All specified process attributes are fetched and displayed in the table columns. CPU and Memory usage are also included, with memory displayed in a human-readable format (e.g., KB, MB).
  #figure(image("process-tree-in-table.png"), caption: "Process Tree Display in Table")

#pagebreak()

- *Search for processes by command line (and other columns):* The search bar effectively filters processes. Users can type simple keywords or use column-specific queries, such as `@command firefox` or `@user root`. The parent processes of search results are also shown to maintain context.
  #figure(image("search-by-command.png"), caption: "Search Results by Command Line")

- *Search for processes that are opening a file:* The `@file <filename>` search syntax allows identifying processes using a specific file. This is implemented by parsing `/proc/[pid]/fd` for each process.
  #figure(image("which-process-open-file.png"), caption: "Search Results by Open File")

#pagebreak()

- *Kill a selected process:* The "Terminate" button, after a confirmation dialog, successfully sends a SIGTERM to the selected process, as verified during testing.
  #figure(image("terminate-process.png"), caption: "Process Termination Confirmation")

- *Compatible with Linux distros (Ubuntu 24.04, CentOS 7):* The reliance on procfs and nix crates, which interface directly with the Linux kernel's `/proc` filesystem and system calls, ensures compatibility across most modern Linux distributions.

- *Interface does not break layout on screens with different resolutions:* Slint's responsive layout components (`VerticalLayout`, `HorizontalLayout`) are used to manage UI elements, allowing the interface to adapt to different screen sizes.

- *Resources occupied by client and server:*
  - *CPU:* The process data refresh rate is set to 3 seconds #footnote[The same as Gnome's System Monitor], reducing frequent system calls. Initial testing shows CPU usage well within the 5% threshold on a single core for typical usage, primarily spiking during data refresh.

  - *Memory:* The `procfs` and custom `MyProcess` struct are relatively lightweight. Initial testing indicates memory consumption remains well below the 100 MB threshold, even with a large number of running processes.

- *Object-oriented design and unit tests:* The codebase is modularized with clear separation of concerns using Rust's module system and traits. Unit tests are provided for key functionalities like `parse_search_query`, `human_readable_byte`, `VecTake`, and `GetUsingFiles`, demonstrating adherence to good testing practices.

- *Security errors:* Rust's memory safety guarantees significantly reduce the risk of common vulnerabilities like buffer overflows, integer overflows, and type confusion. Race conditions are mitigated through the use of `RwLock` for shared state management and `tokio` for controlled concurrency.

== Future Improvements

- *Improved Search Algorithm:* The current search algorithm performs simple substring matching. Future improvements could include:
  - Fuzzy matching for more forgiving searches.
  - Regular expression support for advanced pattern matching.
  - Indexing process data for faster search performance on large process lists.

- *Configurable Refresh Interval:* Provide a user-facing configuration option to adjust the process list refresh interval. This would allow users to balance between real-time updates and system resource consumption based on their needs.

#pagebreak()
#set par(justify: false)
#bibliography(
  "report.bib",
  full: true,
  style: "ieee.csl",
)
