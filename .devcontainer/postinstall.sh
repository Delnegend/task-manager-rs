# zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
echo 'export PATH="/usr/local/cargo/bin:$PATH"' >> ~/.zshrc

# just
ver="1.40.0"
curl -L -o /tmp/just.tar.gz https://github.com/casey/just/releases/download/$ver/just-$ver-x86_64-unknown-linux-musl.tar.gz
checksum=$(openssl dgst -sha3-512 /tmp/just.tar.gz | awk '{print $2}')
expected="27f317b6ca704395dbad34c078f57d140d6d3e1f147a29b5c7563489885525a203bb289b02ec05e52282d25dfe446a60e11554a58addc682ad17f94b6b100cb9"

if [ ! "$checksum" = "$expected" ]; then
    echo "just tarball checksum failed\nexpected: $expected\ngot: $checksum"
else
    sudo rm -rf /usr/local/bin/just
    sudo tar -xf /tmp/just.tar.gz -C /usr/local/bin just
fi
rm -f /tmp/just.tar.gz

# fzf
ver="0.61.3"
curl -L -o /tmp/fzf.tar.gz https://github.com/junegunn/fzf/releases/download/v$ver/fzf-$ver-linux_amd64.tar.gz
checksum=$(openssl dgst -sha3-512 /tmp/fzf.tar.gz | awk '{print $2}')
expected="1710205b6f924c78ebfc6b43e1697e4cf4ba168d7970196f23effb4f125e956a76a07ae8a26dfcd1a4a5b26435b2670bb840b7d1c4ea92befef09789d17068b0"

if [ ! "$checksum" = "$expected" ]; then
    echo "fzf tarball checksum failed\nexpected: $expected\ngot: $checksum"
else
    sudo rm -rf /usr/local/bin/fzf
    sudo tar -xf /tmp/fzf.tar.gz -C /usr/local/bin fzf
fi
rm -f /tmp/fzf.tar.gz

echo 'alias j=just' >> ~/.zshrc

curl -L --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/cargo-bins/cargo-binstall/main/install-from-binstall-release.sh | bash
yes | cargo binstall cargo-deb cargo-generate-rpm

just install-mold
just install-font

sudo chown 1000:1000 /tmp
sudo chmod 0700 /tmp