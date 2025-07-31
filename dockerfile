FROM ubuntu:24.04

# Build arguments for user configuration
ARG USERNAME=default-user
ARG USER_UID=1000
ARG USER_GID=$USER_UID

# Avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# FIRST: Remove default ubuntu user if it exists, then create our user
# Note: We'll add sudoers entry after sudo is installed
RUN (userdel -r ubuntu 2>/dev/null || true) \
    && groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m -s /bin/bash $USERNAME \
    && mkdir -p /home/$USERNAME/workspace \
    && chown -R $USERNAME:$USERNAME /home/$USERNAME

# Install systemd and basic utilities
RUN apt-get update && apt-get install -y \
    systemd \
    systemd-sysv \
    dbus \
    dbus-user-session \
    sudo \
    wget \
    curl \
    ca-certificates \
    gnupg \
    lsb-release \
    software-properties-common \
    unzip \
    rsync \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Add user to sudoers (with password required)
RUN echo "$USERNAME ALL=(ALL:ALL) ALL" >> /etc/sudoers

# Install SSH server
RUN apt-get update && apt-get install -y \
    openssh-server \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir /var/run/sshd \
    && ssh-keygen -A

# Install full Ubuntu desktop environment
RUN apt-get update && apt-get install -y \
    ubuntu-desktop \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install development tools
RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    vim \
    nano \
    htop \
    tmux \
    python3 \
    python3-pip \
    pipx \
    net-tools \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Google Chrome
RUN wget -q -O /tmp/google-chrome-stable_current_amd64.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
    && dpkg -i /tmp/google-chrome-stable_current_amd64.deb || apt-get install -f -y \
    && rm /tmp/google-chrome-stable_current_amd64.deb

# Note: Snap doesn't work well in Docker containers, so installing Firefox via apt
RUN apt-get update && apt-get install -y \
    firefox \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Remove conflicting Docker packages
RUN for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do apt-get remove -y $pkg || true; done

# Add Docker's official GPG key and repository
RUN install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc \
    && chmod a+r /etc/apt/keyrings/docker.asc \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
RUN apt-get update && apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && usermod -aG docker $USERNAME

# NoMachine setup - including dbus workaround for containers
RUN mkdir -p /var/lib/dbus && dbus-uuidgen > /var/lib/dbus/machine-id && mkdir -p /var/run/dbus

# Download and install NoMachine (always latest version)
RUN wget -O /tmp/nomachine_amd64.deb "https://www.nomachine.com/free/linux/64/deb" \
    && dpkg -i /tmp/nomachine_amd64.deb || apt-get install -f -y \
    && rm /tmp/nomachine_amd64.deb

# Set systemd to multi-user target (not graphical) for NoMachine
RUN systemctl set-default multi-user.target

# Configure SSH
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config \
    && sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config \
    && echo "AllowUsers $USERNAME" >> /etc/ssh/sshd_config \
    && systemctl enable ssh.service \
    && systemctl enable sshd.service || true

# Install NVM and Node.js as the user
USER $USERNAME
WORKDIR /home/$USERNAME

# Install NVM
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.0/install.sh | bash \
    && export NVM_DIR="$HOME/.nvm" \
    && [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" \
    && nvm install --lts \
    && nvm use --lts

# Install Claude Code CLI
RUN export NVM_DIR="$HOME/.nvm" \
    && [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" \
    && npm install -g @anthropic-ai/claude-code

# Configure pipx
RUN pipx ensurepath \
    && pipx install poetry

# Configure GNOME to hide Docker volumes and system mounts
RUN mkdir -p /etc/dconf/profile \
    && echo "user-db:user\nsystem-db:local" > /etc/dconf/profile/user \
    && mkdir -p /etc/dconf/db/local.d \
    && echo "[org/gnome/desktop/media-handling]\n\
automount=false\n\
automount-open=false\n\
\n\
[org/gtk/settings/file-chooser]\n\
show-hidden=false\n\
\n\
[org/gnome/nautilus/preferences]\n\
show-hidden-files=false" > /etc/dconf/db/local.d/00-media-handling \
    && mkdir -p /etc/udev/rules.d \
    && echo '# Hide Docker overlayfs from GNOME\n\
ENV{ID_FS_TYPE}=="overlay", ENV{UDISKS_IGNORE}="1"\n\
# Hide Docker volumes\n\
ENV{ID_PATH}=="*docker*", ENV{UDISKS_IGNORE}="1"\n\
# Hide snap volumes\n\
ENV{ID_PATH}=="*snap*", ENV{UDISKS_IGNORE}="1"' > /etc/udev/rules.d/99-hide-docker-mounts.rules \
    && dconf update || true

# Create gvfs config to hide mounts
RUN mkdir -p /usr/share/glib-2.0/schemas \
    && echo '<?xml version="1.0" encoding="UTF-8"?>\n\
<gschema-list>\n\
  <schema id="org.gtk.vfs.file-systems" path="/org/gtk/vfs/file-systems/">\n\
    <key name="blacklist" type="as">\n\
      <default>["overlay", "aufs", "tmpfs", "shm", "/var/lib/docker", "/sys", "/proc"]</default>\n\
    </key>\n\
  </schema>\n\
</gschema-list>' > /usr/share/glib-2.0/schemas/99-hide-docker-mounts.gschema.override \
    && glib-compile-schemas /usr/share/glib-2.0/schemas || true

# Switch back to root for system configuration
USER root

# Add Microsoft GPG key and VS Code repository
RUN wget -q https://packages.microsoft.com/keys/microsoft.asc -O- | gpg --dearmor | tee /etc/apt/trusted.gpg.d/microsoft.gpg \
    && echo "deb [arch=amd64] https://packages.microsoft.com/repos/code stable main" | tee /etc/apt/sources.list.d/vscode.list

# Install VS Code
RUN apt-get update && apt-get install -y \
    code \
    libatomic1 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Download VS Code server start script (optional web-based VS Code)
RUN wget -O /usr/local/bin/start-vscode-server.sh https://raw.githubusercontent.com/nerasse/my-code-server/refs/heads/main/start.sh \
    && chmod +x /usr/local/bin/start-vscode-server.sh \
    && chown root:root /usr/local/bin/start-vscode-server.sh

# Create systemd service for VS Code server (run as user)
RUN echo '[Unit]\n\
Description=VS Code Server\n\
After=network.target network-online.target\n\
Wants=network-online.target\n\
\n\
[Service]\n\
Type=simple\n\
User='$USERNAME'\n\
Group='$USERNAME'\n\
WorkingDirectory=/home/'$USERNAME'\n\
EnvironmentFile=-/etc/vscode-server.env\n\
ExecStart=/usr/local/bin/start-vscode-server.sh\n\
Restart=on-failure\n\
RestartSec=10\n\
StandardOutput=journal\n\
StandardError=journal\n\
\n\
[Install]\n\
WantedBy=multi-user.target' > /etc/systemd/system/vscode-server.service

# Enable services and set permissions
RUN systemctl enable ssh || true \
    && systemctl enable nxserver || true \
    && systemctl enable docker || true \
    && systemctl enable vscode-server || true \
    && chmod 644 /etc/systemd/system/vscode-server.service

# Create startup service to ensure critical services are running and remove nologin
RUN echo '[Unit]\n\
Description=Ensure critical services are started and remove nologin\n\
After=multi-user.target\n\
Before=systemd-user-sessions.service\n\
\n\
[Service]\n\
Type=oneshot\n\
ExecStartPre=/bin/bash -c "rm -f /run/nologin /etc/nologin /var/run/nologin"\n\
ExecStart=/bin/bash -c "systemctl start ssh.service || true; systemctl start vscode-server.service || true"\n\
ExecStartPost=/bin/bash -c "rm -f /run/nologin /etc/nologin /var/run/nologin"\n\
RemainAfterExit=true\n\
\n\
[Install]\n\
WantedBy=multi-user.target' > /etc/systemd/system/ensure-services.service \
    && systemctl enable ensure-services.service

# Also disable systemd-user-sessions.service which creates nologin
RUN systemctl mask systemd-user-sessions.service || true

# Clean up systemd files that don't work in containers
RUN rm -f /lib/systemd/system/multi-user.target.wants/* \
    /etc/systemd/system/*.wants/* \
    /lib/systemd/system/local-fs.target.wants/* \
    /lib/systemd/system/sockets.target.wants/*udev* \
    /lib/systemd/system/sockets.target.wants/*initctl* \
    /lib/systemd/system/basic.target.wants/* \
    /lib/systemd/system/anaconda.target.wants/*

# Create a skeleton directory for first-run initialization
RUN cp -r /home/$USERNAME /home/${USERNAME}.skel

# Create entrypoint script for password setting and environment variables
RUN echo '#!/bin/bash\n\
set -e\n\
\n\
# Set up logging\n\
LOGFILE="/var/log/container-init.log"\n\
exec > >(tee -a "$LOGFILE")\n\
exec 2>&1\n\
echo "Container initialization started at $(date)" >> "$LOGFILE"\n\
\n\
# Initialize home directory on first run\n\
if [ ! -f /home/'$USERNAME'/.initialized ]; then\n\
    echo "First run detected, initializing home directory..."\n\
    # Use rsync to properly copy all files including hidden ones\n\
    if command -v rsync >/dev/null 2>&1; then\n\
        rsync -av --ignore-existing /home/'$USERNAME'.skel/ /home/'$USERNAME'/\n\
    else\n\
        # Fallback to tar to properly handle hidden files\n\
        (cd /home/'$USERNAME'.skel && tar cf - .) | (cd /home/'$USERNAME' && tar xf - --skip-old-files)\n\
    fi\n\
    chown -R '$USERNAME':'$USERNAME' /home/'$USERNAME'\n\
    touch /home/'$USERNAME'/.initialized\n\
fi\n\
\n\
# Password setup - run every time since /etc/shadow is not persistent\n\
echo "Setting up password for user '$USERNAME'..."\n\
if [ -n "$USER_PASSWORD_HASH" ]; then\n\
    echo "Using provided password hash"\n\
    usermod -p "$USER_PASSWORD_HASH" '$USERNAME'\n\
    # Verify it was set\n\
    if grep -q "^'$USERNAME':[^!:*]" /etc/shadow; then\n\
        echo "Password hash successfully applied"\n\
    else\n\
        echo "WARNING: Password may not have been set correctly"\n\
        echo "Shadow entry: $(grep "^'$USERNAME':" /etc/shadow | cut -d: -f1-2)"\n\
    fi\n\
elif [ -n "$USER_PASSWORD" ]; then\n\
    echo "Using provided plaintext password"\n\
    echo "'$USERNAME':$USER_PASSWORD" | chpasswd\n\
    echo "Password set via chpasswd"\n\
else\n\
    echo "ERROR: Please set either USER_PASSWORD_HASH or USER_PASSWORD environment variable"\n\
    exit 1\n\
fi\n\
echo "Password setup complete"\n\
unset USER_PASSWORD USER_PASSWORD_HASH\n\
\n\
# Create environment file for VS Code server\n\
echo "PORT=${VSCODE_PORT:-8585}" > /etc/vscode-server.env\n\
echo "HOST=${VSCODE_HOST:-0.0.0.0}" >> /etc/vscode-server.env\n\
[ -n "$VSCODE_TOKEN" ] && echo "TOKEN=$VSCODE_TOKEN" >> /etc/vscode-server.env\n\
[ -n "$VSCODE_TOKEN_FILE" ] && echo "TOKEN_FILE=$VSCODE_TOKEN_FILE" >> /etc/vscode-server.env\n\
[ -n "$VSCODE_SERVER_DATA_DIR" ] && echo "SERVER_DATA_DIR=$VSCODE_SERVER_DATA_DIR" >> /etc/vscode-server.env\n\
[ -n "$VSCODE_SERVER_BASE_PATH" ] && echo "SERVER_BASE_PATH=$VSCODE_SERVER_BASE_PATH" >> /etc/vscode-server.env\n\
[ -n "$VSCODE_SOCKET_PATH" ] && echo "SOCKET_PATH=$VSCODE_SOCKET_PATH" >> /etc/vscode-server.env\n\
[ -n "$VSCODE_VERBOSE" ] && echo "VERBOSE=$VSCODE_VERBOSE" >> /etc/vscode-server.env\n\
[ -n "$VSCODE_LOG_LEVEL" ] && echo "LOG_LEVEL=$VSCODE_LOG_LEVEL" >> /etc/vscode-server.env\n\
[ -n "$VSCODE_CLI_DATA_DIR" ] && echo "CLI_DATA_DIR=$VSCODE_CLI_DATA_DIR" >> /etc/vscode-server.env\n\
\n\
# Reload systemd and ensure services are enabled\n\
systemctl daemon-reload || true\n\
systemctl enable ssh || true\n\
systemctl enable vscode-server || true\n\
systemctl enable ensure-services || true\n\
# Start the ensure-services immediately to remove nologin\n\
systemctl start ensure-services || true\n\
\n\
echo "Container initialization completed at $(date)" >> "$LOGFILE"\n\
echo "Starting systemd..." >> "$LOGFILE"\n\
\n\
exec /sbin/init' > /entrypoint.sh && chmod +x /entrypoint.sh

# Expose ports
EXPOSE 22 4000

# Mount point for persistent data
VOLUME ["/home/$USERNAME"]

# Use custom entrypoint
ENTRYPOINT ["/entrypoint.sh"]