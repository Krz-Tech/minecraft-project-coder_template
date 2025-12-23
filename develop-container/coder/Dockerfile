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
    # Setup user
    && userdel -r ubuntu \
    && useradd coder --create-home --shell=/bin/bash --groups=docker --uid=1000 --user-group \
    && echo "coder ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/nopasswd \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN curl -L https://coder.com/install.sh | sh
# Minecraft server port
EXPOSE 25566

ENV LANG=ja_JP.UTF-8
ENV JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64

USER coder