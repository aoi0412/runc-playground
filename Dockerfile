FROM ubuntu:26.04

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        runc busybox-static vim containerd ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /root/runc-hands-on

# Avoid nested overlayfs mounts inside Docker Desktop.
ENV CONTAINERD_SNAPSHOTTER=native

# Static BusyBox supplies a minimal rootfs without Docker inside this image.
RUN mkdir -p rootfs/bin \
    && cp /bin/busybox rootfs/bin/busybox \
    && for cmd in sh ls ps sleep hostname id; do \
        ln -s busybox "rootfs/bin/$cmd"; \
    done \
    && runc spec \
    && cp config.json config.interactive.json \
    && sed \
        -e 's/"terminal": true/"terminal": false/' \
        -e 's/"sh"/"sleep", "300"/' \
        config.json > config.sleep.json

COPY start-containerd.sh /usr/local/bin/start-containerd
RUN chmod +x /usr/local/bin/start-containerd

ENTRYPOINT ["/usr/local/bin/start-containerd"]
CMD ["bash"]
