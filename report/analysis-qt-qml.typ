// =========== DOCUMENT CONFIGS ===========
// #let printing-layout = true;
#show link: underline
#set text(font: "Noto Serif", size: 13pt, hyphenate: false)
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

  #pad(top: 12em, bottom: 3em)[#text(25pt)[*INITIAL RESEARCH*]]

  #text(size: 1.5em)[By\ *Nguyễn Thế Kiên*\ Software Engineering | System]

  #align(center)[#text(20pt, weight: "bold")[Linux Task Manager with Qt and Rust]]

  // #pad(top: 4em)[#text(size: 1.5em)[Supervisor: Mr. ]]

  #align(center + bottom)[#text(20pt)[*Hanoi, 2025*]]
]

#set page(numbering: "1 of 1")
#outline()
#pagebreak()

= Project Overview

To build a task manager app runs on Linux similar to Windows' Task Manager, providing detailed process info, search function, file handle inspection, and process termination, while adhering to strict performance and security requirements.

*Key Technologies:*

- *Backend:* Rust
  - `procfs` crate: For reading process information from the `/proc` filesystem.
  - `cxx-qt` crate: For inter-op between Rust and Qt/QML.
  - `nix` crate: For system calls like sending signals to processes (e.g., killing).
  - `users` crate: For resolving user IDs to usernames.
- *Frontend:* Qt/QML
  - QML for declarative UI definition.
  - Qt Quick Controls for standard UI components.
- *Build System:* Cargo (Rust's package manager and build tool) integrated with Qt's build system via `cxx-qt`.

#pagebreak()

= Architectural Design

The app will follow a client-server frontend-backend architecture, where Rust handles all the system-level interactions and data processing, and QML provides the graphical user interface.

#image("overview.png")

*Module Breakdown:*

- *src/backend/:* Contains all Rust logic.
  - `process_data.rs`: Handles raw data fetching and parsing from `/proc`.
  - `process_tree.rs`: Builds and manages the parent-child process tree.
  - `process_manager.rs`: Provides functions for killing processes.
  - `file_inspector.rs`: Logic for finding processes opening specific files.
  - `qml_model.rs`: Defines the Rust structs and `cxx-qt` bridges that expose data and functions to QML.
  - `main.rs`: App entry point, initializes Qt and loads QML.
- *qml/:* Contains all QML UI files.
  - `main.qml`: Main app window and layout.
  - `ProcessView.qml`: Displays the process tree.
  - `SearchBar.qml`: Implements the search feature.
  - `ProcessDetails.qml`: Displays detailed information for a selected process.
  - `MessageBox.qml`: Custom UI for alerts/confirmations.

= Core Component Design & Implementation Strategy

== Process Data Acquisition (Backend - `process_data.rs`)

Utilize the #link("https://crates.io/crates/procfs")[`procfs` crate] to read information from `/proc`.

- *PID, PPID, State, Command Line, Start Time:* The #link("https://docs.rs/procfs/0.17.0/procfs/process/struct.Process.html")[`process::Process`] struct provides direct access to `pid`, `ppid`, `starttime` (through #link("https://docs.rs/procfs/0.17.0/procfs/process/struct.Status.html")[`process::Status`] struct), and `cmdline()`.
- *User Name:*
  1. Get the UID from #link("https://docs.rs/procfs/0.17.0/procfs/process/struct.FDsIter.html?search=st_uid")[`process::Status::suid`].
  2. Use the `users` crate #link("https://docs.rs/users/0.11.0/users/fn.get_user_by_uid.html")[`users::get_user_by_uid`] to resolve the UID to a `User` struct, from which the username can be extracted.
- *Data Refresh:* Implement a periodic timer (e.g., every 1-2 seconds) to refresh process data to keep the UI updated.

== Process Tree Construction (Backend - `process_tree.rs`)

Build an in-memory tree structure from the flat list of processes.

1. Fetch all active processes.
2. Create a `HashMap<u32, ProcessInfo>` where `ProcessInfo` is a custom struct holding relevant process data (PID, PPID, name, etc.).
3. Iterate through the `HashMap` to create parent-child relationships: for each process, find its parent using `ppid`. If a parent isn't found (e.g., init process or orphaned processes), treat it as a root.
4. The `ProcessInfo` struct will contain a `Option<Vec<ProcessInfo>>` for children.
5. This tree structure will then be exposed to QML via `cxx-qt` as a `QAbstractItemModel` for display in a `TreeView`.

== Process Search (Backend - `process_data.rs` / `process_tree.rs`)

Filter the process list based on the command line.

1. The QML frontend will send the search query (string) to the Rust backend.
2. The backend will iterate through the current list of processes (or the constructed tree).
3. For each process, compare its `cmdline()` (converted to a string) against the search query (case-insensitive substring match).
4. Return a filtered list or a new tree containing only matching processes and their ancestors/descendants if desired for context.

== File Handle Search (Backend - `file_inspector.rs`)

Iterate through process file descriptors and resolve their paths.

1. #link("https://docs.rs/procfs/0.17.0/procfs/process/struct.Process.html#method.fd")[*`procfs::process::Process::fd()`:*] This method returns a #link("https://docs.rs/procfs/0.17.0/procfs/process/struct.FDsIter.html")[`FDsIter`] iterator over file descriptors for a given process.
2. For each #link("https://docs.rs/procfs/0.17.0/procfs/process/struct.FDInfo.html")[`FDInfo`], its `target` field (which is a `FDTarget::Path(PathBuf)`) can be used to get the actual file path.
3. The QML frontend will send the target filename (e.g., `my_log.txt`) to the Rust backend.
4. The backend will iterate through *all* running processes. For each process, it will try to get its file descriptors and check if any of the resolved paths match the target filename.
5. *Challenge:* Accessing `/proc/{pid}/fd` for processes owned by other users might require root privileges. The app will need to handle permission denied errors gracefully or prompt for elevated privileges.
6. *Refinement:* For robustness, consider also parsing `/proc/{pid}/maps` which lists memory-mapped files, as `fd()` might not cover all cases. However, `procfs` primarily focuses on `fd()`. Start with `fd()` and see if it handles our use cases.

== Process Management (Backend - `process_manager.rs`)

Use the `nix` crate to send signals.

1. The QML frontend will send the PID of the selected process to the Rust backend.
2. The backend will use #link("https://docs.rs/nix/0.30.1/nix/sys/signal/fn.kill.html")[`nix::sys::signal::kill(Pid::from_raw(pid), Signal::SIGTERM)`] for a graceful termination attempt.
3. If `SIGTERM` fails after a short timeout, #link("https://docs.rs/nix/0.30.1/nix/sys/signal/fn.kill.html")[`nix::sys::signal::kill(Pid::from_raw(pid), Signal::SIGKILL)`] can be used for a forceful termination.
4. *Privileges:* Killing processes owned by other users or critical system processes will require root privileges. The app should inform the user if it lacks permissions and potentially guide them to run it with `sudo` or use `pkexec`.

== UI/UX Design (Frontend - QML)

Leverage Qt Quick Controls and QML's declarative nature for a responsive and intuitive interface.

- *Process Display:* Use a `TreeView` (or `TableView` with custom delegates if a tree structure proves too complex for initial implementation) to display processes. QML's `AbstractItemModel` will be implemented in Rust via `cxx-qt` to provide data to the `TreeView`.
- *Columns:* PID, PPID, State, User Name, Start Time, Command Line.
- *Search Bar:* A `TextField` for input and a `Button` or `Image` for triggering the search.
- *Kill Button:* A `Button` that sends the selected process's PID to the Rust backend.
- *File Search Input:* Another `TextField` and `Button` for the file search functionality.
- *Layout:* Use `ColumnLayout`, `RowLayout`, `GridLayout`, and `Anchors` for responsive layout that adapts to different screen resolutions.

== Rust-QML Integration (`cxx-qt`)

Define #link("https://docs.rs/cxx-qt/latest/cxx_qt/attr.bridge.html")[`#[cxx_qt::bridge]`] modules in Rust to expose Rust types and functions to QML.

- Create a main Rust object (e.g., `TaskManagerBackend`) that holds the state and implements the core logic.
- This object will have #link("https://docs.rs/cxx-qt/latest/cxx_qt/attr.qobject.html")[`#[qobject]`] and #[qml_element] attributes.
- Expose `#[qproperty]` for data that QML can bind to (e.g., `processList: QList<ProcessInfo>`).
- Expose `#[qinvokable]` functions for actions QML can call (e.g., `killProcess(pid: u32)`, `searchProcesses(query: String)`, `findProcessesOpeningFile(filename: String)`).
- Use `#[qsignal]` to emit signals from Rust to QML (e.g., `processListUpdated()`, `errorMessage(msg: String)`).
- The `QAbstractItemModel` for the process tree will be a key part of this integration, allowing QML's `TreeView` to display hierarchical data.

#pagebreak()
= Development Workflow

1. *Environment Setup:*
  - Devcontainer with all dependencies (Rust, Cargo, Qt,...) pre-installed and pre-configured for easy maintenance.
2. *Build Process:*
  - `cargo build` will handle the Rust compilation.
  - `cxx-qt` integrates with Cargo to generate the necessary C++ glue code and link against Qt libraries.
  - The `qml` directory will be copied to the build output.

= Testing Strategy

- *Unit Tests:*
  - *Rust Backend:* Use Rust's built-in `#[test]` attribute.
  - Test `process_data.rs`: Parsing of `/proc` entries, correct extraction of PID, PPID, state, etc. (mock `/proc` data for isolated testing).
  - Test `process_tree.rs`: Correct construction of parent-child relationships, handling of orphaned processes.
  - Test `process_manager.rs`: (Carefully) test signal sending logic (mock `nix::sys::signal::kill` to avoid actual process termination during tests).
  - Test `file_inspector.rs`: Correctly identifying open files (mock `/proc/{pid}/fd` entries).
  - *QML:* QML doesn't have a direct unit testing framework like Rust. Manual testing and visual inspection will be primary.
- *Integration Tests:*
  - Test the `cxx-qt` bridge: Ensure Rust functions are correctly invoked from QML and data flows correctly.
  - Test end-to-end functionality (e.g., search works, kill button terminates a test process).
- *Performance Tests:*
  - Monitor CPU and Memory usage during operation using tools like `top`, `htop`, or `perf`.
  - Profile the Rust backend to identify bottlenecks in data fetching and processing.

= Packaging
Using flatpak to package the whole app and all of its dependencies.
- Create a `flatpak` manifest file that specifies the app's runtime, build dependencies, and permissions (ensure it has the necessary ones to access `/proc` and send signals to processes.).
- Use `flatpak-builder` to build the app in a clean environment, ensuring all dependencies are included.

= Non-Functional Requirements Integration

== Linux Compatibility (Ubuntu 24.04, CentOS 7)

Since we will be using flatpak, all the necessary dependencies will be included in the final package.

== UI Responsiveness (Layout on different resolutions)

Utilize QML's flexible layout managers and responsive design principles.

- Use `Anchors`, `ColumnLayout`, `RowLayout`, `GridLayout`, and `Anchors` for dynamic positioning and sizing of UI elements.
- Avoid fixed pixel sizes where possible; prefer relative sizing or `Layout.fillWidth`/`Layout.fillHeight`.
- Test on virtual machines or actual hardware with varying screen resolutions and aspect ratios.

== Resource Usage (CPU < 5% on 1 core, Memory < 100 MB)

Optimize data processing, minimize UI updates, and profile aggressively.

- *CPU:*
  - *Efficient `procfs` usage:* Only read necessary data. `procfs` is generally efficient as it directly reads kernel data.
  - *Optimized Tree Construction:* Ensure the tree building algorithm is efficient (e.g., O(N) or O(NlogN) where N is the number of processes).
  - *Throttled Updates:* Limit the refresh rate of process data (e.g., 1-2 seconds) to avoid constant CPU churn. Only update the QML model when data significantly changes.
  - *Profiling:* Use `perf` or `valgrind --tool=callgrind` to identify CPU hotspots in the Rust code.
- *Memory:*
  - *Data Structures:* Choose memory-efficient data structures in Rust (e.g., `Vec`, `HashMap`, `String` where appropriate). Avoid unnecessary cloning.
  - *QML Model:* Ensure the `QAbstractItemModel` implementation efficiently provides data without excessive copying.
  - *Memory Profiling:* Use tools like `valgrind --tool=massif` or `jemalloc` with Rust for memory profiling.
  - *Qt Overhead:* Be aware that Qt itself has a baseline memory footprint. The 100MB threshold includes Qt's overhead.

== Object-Oriented Design & Unit Tests

Utilize Rust's strong type system, traits, and modules to achieve an object-oriented-like structure.

- *Modules:* Organize code into logical modules (e.g., `process_data`, `process_tree`, `process_manager`) corresponding to the architectural breakdown.
- *Structs & Enums:* Define clear data structures for processes (`ProcessInfo`), states, etc.
- *Traits:* Use traits for defining interfaces and shared behavior (e.g., a `ProcessSource` trait if we wanted to abstract away `/proc` for testing or other sources).
- *Encapsulation:* Use Rust's visibility rules (`pub`, `pub(crate)`) to control access to data and functions within modules.
- *Unit Tests:* As detailed in Section 5, write comprehensive unit tests for each module and public function.

== Security Bugs (Buffer Overflow, Integer Overflow, Format String, Race Condition, Type Confusion)

Leverage Rust's safety guarantees and follow secure coding practices.

- *Buffer Overflow/Use-After-Free/Dangling Pointers:* Rust's ownership and borrowing system, enforced by the compiler, largely eliminates these common C/C++ memory safety bugs.
- *Integer Overflow:*
  - Rust's debug builds panic on integer overflow by default. Release builds wrap.
  - For arithmetic where overflow is a concern (e.g., calculations involving PIDs or memory sizes), use checked arithmetic methods like `checked_add()`, `checked_sub()`, `checked_mul()`, `checked_div()` which return `Option<T>`, forcing explicit error handling.
- *Format String Vulnerabilities:* Rust's `format!` macros are type-safe and do not suffer from the same vulnerabilities as C's `printf`. Avoid constructing format strings from untrusted user input.
- *Race Conditions:*
  - Rust's type system prevents data races at compile time (e.g., `std::sync::Mutex`, `std::sync::RwLock` for shared mutable state).
  - Use `Arc` for shared ownership across threads and `Mutex`/`RwLock` for safe mutable access.
  - Use channels (`std::sync::mpsc`, `tokio::sync::mpsc`) for message passing between threads/tasks.
- *Type Confusion:* Rust's strong, static typing prevents type confusion at compile time.
- *`unsafe` blocks:* Minimize the use of `unsafe` Rust. When `unsafe` code is necessary (e.g., for FFI with `cxx-qt`), rigorously review and document its safety invariants.
- *Privilege Handling:* Any actions requiring elevated privileges (e.g., killing processes, accessing other user's `/proc` data) must be handled carefully. The app should run with the least privileges necessary and only elevate for specific, user-initiated actions, ideally through `pkexec` or `sudo` prompts rather than running the entire app as root.

#pagebreak()
= References
- #link("https://crates.io/crates/procfs")[`procfs` crate documentation]
- #link("https://docs.rs/cxx-qt/")[`cxx-qt` crate documentation]
- #link("https://kdab.github.io/cxx-qt/book/index.html")[`cxx-qt` book]
- #link("https://docs.rs/nix/")[`nix` crate documentation]
- #link("https://doc.qt.io/qt-6/qtqml-index.html")[`Qt Qml Documentation`]
- #link("https://doc.rust-lang.org/stable/std/?search=check_")[Rust Standard Library checked arithmetic documentation]
- #link("https://doc.rust-lang.org/std/sync/index.html")[Rust Standard Library concurrency primitives documentation]
- #link("https://docs.kernel.org/filesystems/proc.html")[Linux kernel documentation on `/proc` filesystem]
