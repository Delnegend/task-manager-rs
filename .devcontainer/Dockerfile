FROM debian:12

RUN apt-get update && apt-get install -y \
    meson ninja-build nasm clang \
    pkg-config libssl-dev \
    curl git zsh sudo fontconfig qt6-wayland && apt-get clean

RUN groupadd -g 1000 tmrs && \
    useradd -m -u 1000 -g tmrs tmrs && \
    echo "tmrs ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/tmrs && \
    mkdir -p /usr/local/cargo && chown -R tmrs /usr/local/cargo && \
    mkdir -p /home/tmrs/.pnpm-store && chown -R tmrs /home/tmrs/.pnpm-store && \
    mkdir -p /tmp && chown -R tmrs /tmp && \
    chmod 0700 /tmp

USER tmrs

ENV CARGO_HOME=/usr/local/cargo