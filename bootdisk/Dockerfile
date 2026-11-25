FROM debian:13-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
      syslinux syslinux-common mtools dosfstools fdisk binutils cpio gzip ca-certificates \
    && rm -rf /var/lib/apt/lists/*
