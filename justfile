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

    # Ensure the target font directory exists
    echo "Ensuring font directory $target_font_dir exists..."
    sudo mkdir -p "$target_font_dir"

    # Check if there are any .ttf files to install
    # We use -print -quit to find the first match and exit find quickly.
    # grep -q . checks if find produced any output (i.e., found at least one file).
    if ! find "$source_dir" -type f -name "*.ttf" -print -quit | grep -q .; then
        echo "No .ttf font files found in '$source_dir'."
        exit 0
    fi

    echo "Installing .ttf fonts from '$source_dir' to '$target_font_dir'..."
    # Use find to locate all .ttf files and execute cp for them.
    # 'sudo cp' is used as font directories are typically system-wide and require root privileges.
    # -v option for cp provides verbose output (prints names of copied files).
    # -t option for cp specifies the target directory.
    # {} + syntax passes multiple found files as arguments to a single cp command, which is more efficient.
    find "$source_dir" -type f -name "*.ttf" -exec sudo cp -v -t "$target_font_dir/" {} +

    echo "Updating font cache..."
    # -f forces re-generation of caches, -v provides verbose output.
    sudo fc-cache -f -v

    echo "Font installation complete."

dev:
    cargo run

test:
    cargo test