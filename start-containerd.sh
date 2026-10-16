#!/bin/sh
set -eu

# No systemd inside the playground. Keep daemon output out of the terminal.
if ! ctr --timeout 1s version >/dev/null 2>&1; then
    # Keep the parent cgroup empty so nested runtimes can use domain controllers.
    if [ -f /sys/fs/cgroup/cgroup.controllers ]; then
        if [ "$(cat /sys/fs/cgroup/cgroup.type)" = 'domain threaded' ]; then
            for controller in $(cat /sys/fs/cgroup/cgroup.subtree_control); do
                echo "-$controller" >/sys/fs/cgroup/cgroup.subtree_control
            done
        fi
        mkdir -p /sys/fs/cgroup/playground-init
        # Snapshot first: migrating processes changes cgroup.procs while reading.
        for pid in $(cat /sys/fs/cgroup/cgroup.procs); do
            echo "$pid" >/sys/fs/cgroup/playground-init/cgroup.procs 2>/dev/null || true
        done
        for controller in $(cat /sys/fs/cgroup/cgroup.controllers); do
            echo "+$controller" >/sys/fs/cgroup/cgroup.subtree_control
        done
    fi
    mkdir -p /var/log
    nohup containerd >>/var/log/containerd.log 2>&1 </dev/null &
    daemon_pid=$!
    ready=false
    for attempt in $(seq 1 50); do
        if ctr --timeout 1s version >/dev/null 2>&1; then
            ready=true
            break
        fi
        if ! kill -0 "$daemon_pid" 2>/dev/null; then
            break
        fi
        sleep 0.1
    done
    if [ "$ready" != true ]; then
        echo 'containerd failed to start; see /var/log/containerd.log' >&2
        tail -n 30 /var/log/containerd.log >&2
        exit 1
    fi
fi

if [ "$#" -gt 0 ]; then
    exec "$@"
fi
