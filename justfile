@default:
    just --choose

install-mold:
    #!/usr/bin/env bash
    ver="2.37.1"
    curl -L -o /tmp/mold.tar.gz https://github.com/rui314/mold/releases/download/v$ver/mold-$ver-x86_64-linux.tar.gz
    checksum=$(openssl dgst -sha3-512 /tmp/mold.tar.gz | awk '{print $2}' | tr -d '\n')
    expected="bab38238011b77430fae4509d62cb7f175845afe6a81e83a10be16570d149fad440d179f93e0d464405749af58ea3581a17e94f7650d88043b359235db1a5545"

    if [ ! "$checksum" = "$expected" ]; then
        rm -f /tmp/mold.tar.gz
        echo "mold tarball checksum failed\nexpected: $expected\ngot: $checksum"
        exit 1
    else
        sudo rm -rf /usr/local/cargo/mold-$ver-x86_64-linux
        sudo tar -xf /tmp/mold.tar.gz -C /usr/local/cargo
        rm -f /tmp/mold.tar.gz
    fi

    # configure cargo to use mold
    rm -f /usr/local/cargo/config.toml
    printf "[target.x86_64-unknown-linux-gnu]\nlinker = \"clang\"\nrustflags = [\"-C\", \"link-arg=-fuse-ld=/usr/local/cargo/mold-$ver-x86_64-linux/bin/mold\"]" > /usr/local/cargo/config.toml
    echo "cargo config: \n$(cat /usr/local/cargo/config.toml)"

install-font:
    #!/usr/bin/env bash
    source_dir="./report/fonts"
    target_font_dir="/usr/local/share/fonts"

    # Check if source directory exists
    if [ ! -d "$source_dir" ]; then
        echo "Error: Source directory '$source_dir' not found." >&2
        exit 1
    fi

    echo "Ensuring font directory $target_font_dir exists..."
    sudo mkdir -p "$target_font_dir"


    if ! find "$source_dir" -type f -name "*.ttf" -print -quit | grep -q .; then
        echo "No .ttf font files found in '$source_dir'."
        exit 0
    fi

    echo "Installing .ttf fonts from '$source_dir' to '$target_font_dir'..."

    find "$source_dir" -type f -name "*.ttf" -exec sudo cp -v -t "$target_font_dir/" {} +

    echo "Updating font cache..."
    sudo fc-cache -f -v

    echo "Font installation complete."

dev:
    cargo run

test:
    cargo test

lint:
    cargo fmt && cargo clippy

build-release:
    cargo build --release

package-rpm: build-release
    @mkdir -p ./dist
    cargo generate-rpm
    @find target/generate-rpm -name "*.rpm" -exec mv {} ./dist/ \;
    @echo "RPM package moved to ./dist/"

package-deb: build-release
    @mkdir -p ./dist
    cargo deb
    @find target/debian/ -name "*.deb" -exec mv {} ./dist/ \;
    @echo "DEB package moved to ./dist/"

test-keep-file:
    #!/usr/bin/env bash

    if [ ! -f /tmp/example.txt ]; then
        echo "Creating /tmp/example.txt"
        echo "This is a test file." > /tmp/example.txt
    fi
    TARGET_FILE="/tmp/example.txt"

    # --- Method 1: Redirecting output to a file descriptor ---
    # This opens the file for writing and assigns it to file descriptor 3.
    # The 'exec' command is used to permanently redirect the descriptor for the current shell.
    echo "--- Method 1: Opening for writing with exec (FD 3) ---"
    exec 3> "$TARGET_FILE"
    echo "This line is written to $TARGET_FILE via FD 3." >&3
    echo "File '$TARGET_FILE' is now open for writing on FD 3."
    echo "You can check with 'lsof -p $$' in another terminal."
    sleep 10
    exec 3>&- # Close file descriptor 3

    echo ""

    # --- Method 2: Opening for reading with exec ---
    # This opens the file for reading and assigns it to file descriptor 4.
    echo "--- Method 2: Opening for reading with exec (FD 4) ---"
    echo "Some content for reading." > "$TARGET_FILE" # Ensure file has content
    exec 4< "$TARGET_FILE"
    echo "File '$TARGET_FILE' is now open for reading on FD 4."
    echo "You can check with 'lsof -p $$' in another terminal."
    sleep 10
    exec 4>&- # Close file descriptor 4

    echo ""

    # --- Method 3: Opening for both reading and writing (FD 5) ---
    # This opens the file for both reading and writing and assigns it to FD 5.
    echo "--- Method 3: Opening for reading and writing with exec (FD 5) ---"
    exec 5<> "$TARGET_FILE"
    echo "File '$TARGET_FILE' is now open for reading and writing on FD 5."
    echo "You can check with 'lsof -p $$' in another terminal."
    sleep 10
    exec 5>&- # Close file descriptor 5

    echo ""

    # Clean up the temporary file
    rm -f "$TARGET_FILE"
    echo "Cleaned up $TARGET_FILE."

    #!/usr/bin/env bash
    output_file="src_snapshot.md"
    src_dir="./src"

    # Clear the output file or create it if it doesn't exist
    > "$output_file"

