#!/bin/sh
# Bootstraps the dev sshd and execs it. The `dev` user and host keys are
# already created in the image; this only re-asserts ownership of the files
# sshd cares about (in case the home dir was recreated by a fresh mount) and
# starts the daemon.
set -eu

mkdir -p /run/sshd

[ -f /etc/ssh/ssh_host_ed25519_key ] || \
    ssh-keygen -q -t ed25519 -N '' -f /etc/ssh/ssh_host_ed25519_key

# Non-recursive: do not chown the mounted repo, only the .ssh dir/files.
chown 1000:1000 /home/dev /home/dev/.ssh 2>/dev/null || true
[ -f /home/dev/.ssh/environment ] && \
    chown 1000:1000 /home/dev/.ssh/environment 2>/dev/null || true

# Positron Remote SSH unpacks its server here; the volume can be seeded as
# root, but the client logs in as dev and must write it. chown is metadata-only.
mkdir -p /home/dev/.positron-server
chown -R 1000:1000 /home/dev/.positron-server 2>/dev/null || true

exec /usr/sbin/sshd -D -e -f /etc/ssh/sshd_config
