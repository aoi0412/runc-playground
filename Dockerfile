FROM ubuntu:26.04

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        runc busybox-static vim \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /root/runc-hands-on

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

CMD ["bash"]
