FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    ca-certificates \
    curl \
    docker.io \
    git \
    jq \
    locales \
    nano \
    openjdk-21-jdk-headless \
    screen \
    sudo \
    unzip \
    wget \
    && locale-gen ja_JP.UTF-8 \
    # Install playit.gg (TCP tunnel for game servers)
    && curl -L https://github.com/playit-cloud/playit-agent/releases/download/v0.16.5/playit-linux-amd64 -o /usr/local/bin/playit \
    && chmod +x /usr/local/bin/playit \
    # Setup user
    && userdel -r ubuntu \
    && useradd coder --create-home --shell=/bin/bash --groups=docker --uid=1000 --user-group \
    && echo "coder ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/nopasswd \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Minecraft server port
EXPOSE 25565 25566

ENV LANG=ja_JP.UTF-8
ENV JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64

USER coder