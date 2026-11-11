# =============================================================================
# dev-conda-env — private dev container (SSH + one conda environment).
# Runtime image: miniforge3 base + a single conda env created from the yml
# passed via ENV_FILE. sshd runs as root; SSH sessions log in as `dev`
# (uid 1000 = your `id -u`), so files written in the mounted repo keep the
# host's owner.
#
#   ./build.sh envs/<chapter>.yml    # build the image
#   ./setup.sh envs/<chapter>.yml    # start the stack + install your SSH key
#   ssh <Host>                       # repo mounted at /home/dev/<project>
#
# The environment is created from a yml (name/channels/dependencies) via
# conda env create; no ad-hoc `pip install` is meant to happen inside.
# =============================================================================

ARG MINIFORGE_IMAGE=condaforge/miniforge3:24.11.3-0

FROM ${MINIFORGE_IMAGE}

USER root

# sshd + the few system tools the container needs. ca-certificates for git
# over https; procps for `ps` (editors/servers use it); curl/unzip/tar for
# the Positron Remote SSH server bootstrap.
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        openssh-server \
        procps \
        git \
        ca-certificates \
        curl \
        unzip \
        tar \
    && rm -rf /var/lib/apt/lists/*

# The conda environment, created from the yml passed at build time.
# A stable `/opt/conda/envs/current` symlink makes the rest of the image
# (PATH, the ssh environment, etc.) independent of the environment's name.
ARG ENV_FILE
COPY ${ENV_FILE} /tmp/env.yml
RUN name="$(grep -E '^name:' /tmp/env.yml | awk '{print $2}')" && \
    conda env create -f /tmp/env.yml && \
    ln -sfn "/opt/conda/envs/${name}" /opt/conda/envs/current && \
    rm -f /tmp/env.yml && \
    conda clean -afy

# Image-level env so `docker compose exec dev <cmd>` also sees the env.
ENV PATH="/opt/conda/envs/current/bin:/opt/conda/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
    CONDA_DEFAULT_ENV="current"

# The `dev` login user (uid 1000 = host user). Host keys are already generated
# by the openssh-server post-install script (baked into the image), so
# restarting the container does not churn the host's known_hosts.
# `-p '*'` sets the shadow field to '*' (vs useradd's default '!'): sshd treats
# '!' as a locked account and refuses even pubkey logins, while '*' disables
# password login but allows the key.
RUN useradd -u 1000 -m -s /bin/bash -p '*' dev && \
    mkdir -p /home/dev/.ssh /run/sshd && \
    chown -R 1000:1000 /home/dev && \
    chmod 700 /home/dev/.ssh && \
    sed -i 's|conda activate base|export PATH="/opt/conda/envs/current/bin:/opt/conda/bin:$PATH"|' /home/dev/.bashrc

# sshd gives sessions its own PATH, not the image ENV, so the env vars that
# matter are injected via ~/.ssh/environment (PermitUserEnvironment yes).
RUN printf '%s\n' \
    'PATH=/opt/conda/envs/current/bin:/opt/conda/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin' \
    'CONDA_DEFAULT_ENV=current' \
    > /home/dev/.ssh/environment && \
    chown 1000:1000 /home/dev/.ssh/environment && \
    chmod 600 /home/dev/.ssh/environment

RUN printf '%s\n' \
    'Port 22' \
    'PermitRootLogin no' \
    'PubkeyAuthentication yes' \
    'PasswordAuthentication no' \
    'KbdInteractiveAuthentication no' \
    'ChallengeResponseAuthentication no' \
    'AuthorizedKeysFile .ssh/authorized_keys' \
    'PermitUserEnvironment yes' \
    'UsePAM no' \
    'PrintMotd no' \
    'PidFile /run/sshd.pid' \
    > /etc/ssh/sshd_config

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 22
WORKDIR /home/dev/project
CMD ["/entrypoint.sh"]
