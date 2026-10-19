#!/bin/bash
set -e

# Ensure script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (use sudo)" 
   exit 1
fi

# ==========================================
# STEP 1: Declare Variables
# ==========================================
CONT_NAME="your-cont-name"
CONT_PATH="/var/lib/machines/$CONT_NAME"
HOST_DIR="your-host-dir-path"

echo "[*] Initializing setup for container: $CONT_NAME"
mkdir -p "$CONT_PATH"

# ==========================================
# STEP 5 (Moved Up): Host Modprobe Service
# ==========================================
echo "[*] Creating host kernel module persistence file (Commented out)..."
mkdir -p /etc/modules-load.d

cat > /etc/modules-load.d/docker-nspawn.conf <<EOF
# Uncomment the modules below to automatically load them on host boot.
overlay
br_netfilter
nf_tables
iptable_nat
xt_conntrack
ip_tables
iptable_filter
iptable_mangle
EOF

# Reload systemd to recognize the config, and restart the service
systemctl daemon-reload
systemctl restart systemd-modules-load.service

# Manually load them for the current session so Step 7 succeeds immediately
# echo "[*] Actively loading kernel modules for current session..."
# modprobe overlay br_netfilter nf_tables iptable_nat xt_conntrack ip_tables iptable_filter iptable_mangle || true

# ==========================================
# STEP 2: OS Detection & Container Bootstrap
# ==========================================
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    echo "Cannot detect OS. Exiting."
    exit 1
fi

echo "[*] Detected Host OS: $OS"

if [[ "$OS" == "fedora" ]]; then
    echo "[*] Bootstrapping Fedora systemd-nspawn container..."
    # Included fedora-release and forced the -y auto-accept flag
    dnf --releasever="$VERSION_ID" --installroot="$CONT_PATH" --setopt=reposdir=/etc/yum.repos.d install fedora-release systemd iproute moby-engine docker-cli dnf tailscale -y

elif [[ "$OS" == "arch" || "$OS" == "cachyos" ]]; then
    echo "[*] Bootstrapping Arch/CachyOS systemd-nspawn container..."
    # Auto-install arch-install-scripts on the host if missing
    if ! command -v pacstrap &> /dev/null; then
        echo "[*] Installing arch-install-scripts on host..."
        pacman -Sy --noconfirm arch-install-scripts
    fi
    # pacstrap is non-interactive by default. 'base' acts as the arch-equivalent to fedora-release
    pacstrap -c "$CONT_PATH" base systemd iproute2 docker tailscale
else
    echo "Unsupported OS for this automated script: $OS"
    exit 1
fi

# ==========================================
# STEP 3: Create Dynamic systemd-nspawn File
# ==========================================
echo "[*] Creating systemd-nspawn configuration..."
mkdir -p /etc/systemd/nspawn

cat > "/etc/systemd/nspawn/$CONT_NAME.nspawn" <<EOF
[Exec]
# Allow Docker's required system calls
SystemCallFilter=@keyring bpf @module add-key keyctl

# Tailscale requires network admin rights to create the tailscale0 interface
Capability=CAP_NET_ADMIN

[Files]
# Read only mount for docker to start
BindReadOnly=/proc:/run/proc
BindReadOnly=/sys:/run/sys

# ID-mapped code directory
Bind=${HOST_DIR}:${HOST_DIR}:idmap

# GPU deivce access
Bind=/dev/dri

# Tailscale requires access to the host's virtual network tunnel device
Bind=/dev/net/tun

[Network]
# Enable isolated networking
VirtualEthernet=yes

# Securely forward the container's Docker TCP port ONLY to the host's localhost (127.0.0.1)
Port=tcp:127.0.0.1:2375:2375
EOF

# ==========================================
# STEP 4: Create Docker and NSpawn Override Conf (Port 2375)
# ==========================================
echo "[*] Configuring Docker daemon to listen on TCP 2375..."
# This drop-in directory path is identical across Fedora and Arch
DOCKER_DROPIN_DIR="$CONT_PATH/etc/systemd/system/docker.service.d"
mkdir -p "$DOCKER_DROPIN_DIR"

cat > "$DOCKER_DROPIN_DIR/override.conf" <<EOF
[Service]
ExecStart=
# Docker requires 0.0.0.0 inside the container to receive the forwarded nspawn traffic.
# The TLS warning in the logs is expected and safe because nspawn strictly limits access to the host.
ExecStart=/usr/bin/dockerd -H fd:// -H tcp://0.0.0.0:2375 --tls=false --containerd=/run/containerd/containerd.sock
EOF

echo "[*] Configuring systemd-nspawn to access host devices..."
# This drop-in directory path is identical across Fedora and Arch
NSPAWN_DROPIN_DIR="/etc/systemd/system/systemd-nspawn@$CONT_NAME.service.d"
mkdir -p "$NSPAWN_DROPIN_DIR"

cat > "$NSPAWN_DROPIN_DIR/override.conf" <<EOF
[Service]
DeviceAllow=char-drm rw
EOF

# ==========================================
# STEP 6: Handle SELinux and Firewall (Fedora Only)
# ==========================================
if [[ "$OS" == "fedora" ]]; then
	# firewall-cmd --permanent --add-masquerade
	firewall-cmd --permanent --zone=trusted --add-interface=ve-+
	firewall-cmd --permanent --zone=trusted --add-forward 
	firewall-cmd --reload
	
    if command -v getenforce &> /dev/null && [[ "$(getenforce)" == "Enforcing" ]]; then
        echo "[*] Host SELinux is Enforcing. Setting docker_t to permissive..."
        # semanage writes directly to the SELinux policy DB, so it auto-persists across reboots.
		semanage fcontext -a -t container_file_t "/var/lib/machines/$CONT_NAME(/.*)?"
		restorecon -Rv /var/lib/machines/$CONT_NAME
        # semanage permissive -a docker_t
    else
        echo "[*] SELinux is not Enforcing. Skipping semanage."
    fi
else
    echo "[*] Arch/CachyOS detected. Skipping SELinux modifications."
	# Enable ip_forward in /etc/ufw/sysctl.conf (uncomment the line)
	sed -i 's|^#*net/ipv4/ip_forward=.*|net/ipv4/ip_forward=1|' /etc/ufw/sysctl.conf   
	ufw default allow routed
	ufw allow in on ve-$CONT_NAME to any port 67 proto udp
	ufw allow in on ve-$CONT_NAME to any port 53 
    ufw reload
fi


# ==========================================
# STEP 7: Configure Network Access
# ==========================================
systemctl enable --now systemd-networkd

echo "[*] Creating persistent Docker FORWARD rules service..."
cat > /etc/systemd/system/nspawn-docker-forward.service <<EOF
[Unit]
Description=Allow systemd-nspawn traffic through host Docker
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
# Add rules to explicitly allow the virtual ethernet interfaces
ExecStart=/usr/sbin/iptables -I DOCKER-USER -i ve-+ -j ACCEPT
ExecStart=/usr/sbin/iptables -I DOCKER-USER -o ve-+ -j ACCEPT
# Clean up rules if the service is stopped
ExecStop=/usr/sbin/iptables -D DOCKER-USER -i ve-+ -j ACCEPT
ExecStop=/usr/sbin/iptables -D DOCKER-USER -o ve-+ -j ACCEPT
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

if [[ "$OS" == "fedora" ]]; then
	echo "[*] Enabling nspawn-docker-forward service..."
	systemctl daemon-reload
	systemctl enable --now nspawn-docker-forward.service
else
	echo "[*] Creating persistent Docker FORWARD rules service..."
fi
# ==========================================
# STEP 8: Start Container and Internal Services
# ==========================================
echo "[*] Starting systemd-nspawn container..."
systemctl enable --now machines.target
machinectl enable "$CONT_NAME"
machinectl start "$CONT_NAME"

echo "[*] Waiting for container to boot..."
sleep 5

echo "[*] Starting internal container services..."
# Enable and start the network and docker daemons inside the container
machinectl shell "$CONT_NAME" /bin/sh -c "systemctl enable --now systemd-networkd && systemctl enable --now systemd-resolved"
machinectl shell "$CONT_NAME" /bin/sh -c "ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf"
machinectl shell "$CONT_NAME" /bin/sh -c "systemctl enable --now docker"
machinectl shell "$CONT_NAME" /bin/sh -c "docker run --rm hello-world"
machinectl shell "$CONT_NAME" /bin/sh -c "systemctl enable --now tailscaled"
# machinectl shell "$CONT_NAME" /bin/sh -c "tailscale up"

echo ""
echo "=========================================="
echo "Setup Complete!"
echo "Your container is running. Docker is securely accessible on your host."
echo "Verify connection: docker -H tcp://127.0.0.1:2375 info"
echo "=========================================="
