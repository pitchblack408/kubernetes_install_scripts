#!/bin/bash

set -ex

MAC_ADDRESS=$1
if [[ ! -n $MAC_ADDRESS ]]; then
  echo "The MAC_ADDRESS is a required parameter."
    exit 1
fi

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root or with sudo."
  exit 1
fi

if [ "$(uname -m)" != "x86_64" ]; then
    echo "Error: This script requires x86_64 architecture."
    exit 1
fi

# Check if wget is not installed
if ! command -v wget >/dev/null 2>&1; then
    echo "The command wget is not installed."
    exit 1
fi

# Check if ip is not installed
if ! command -v ip >/dev/null 2>&1; then
    echo "The command ip is not installed."
    exit 1
fi

if ! command -v apt-get >/dev/null 2>&1; then
    echo "The command apt-get is not installed."
fi

CONTAINERD_VERSION="1.7.11"
RUNC_VERSION="1.1.10"
KUBERNETES_VERSION="1.30"

NODE_STATIC_IP=$(ip addr show eth1 | grep "inet " | awk '{print $2}' | cut -d/ -f1)
export NODE_STATIC_IP=$NODE_STATIC_IP

# Check if the IP address was retrieved successfully
if [[ -z "$NODE_STATIC_IP" ]]; then
    echo "Error: Unable to retrieve IP address for eth1."
    exit 1
fi

# Validate the IP address format
if ! [[ $NODE_STATIC_IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Error: Invalid IP address format: $NODE_STATIC_IP"
    exit 1
fi

echo "Creating netplan"
cat <<EOF | sudo tee /etc/netplan/10-custom.yaml
network:
    version: 2
    ethernets:
        extra0:
            dhcp4: no
            match:
                macaddress: "$NODE_STATIC_IP_MAC"
            addresses: [$NODE_STATIC_IP/24]
EOF
echo "Netplan configuration created successfully."


cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter
echo "Installed overlay and br_netfilter kernel modules successfully."

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system
echo "Applied the new network configuration successfully."

sudo swapoff -a
#Cron job to ensure swap is off after reboot
(crontab -l 2>/dev/null; echo "@reboot /sbin/swapoff -a") | crontab - || true
echo "Applied swapoff -a successfully."


wget https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VERSION}/containerd-${CONTAINERD_VERSION}-linux-amd64.tar.gz
sudo tar Cxzvf /usr/local containerd-${CONTAINERD_VERSION}-linux-amd64.tar.gz
sudo mkdir /etc/containerd
containerd config default > config.toml
sudo cp config.toml /etc/containerd
wget https://raw.githubusercontent.com/containerd/containerd/main/containerd.service
sudo cp containerd.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now containerd
echo "Installed containerd v$CONTAINERD_VERSION successfully"


wget https://github.com/opencontainers/runc/releases/download/v${RUNC_VERSION}/runc.amd64
sudo install -m 755 runc.amd64 /usr/local/sbin/runc
echo "Installed runc v$RUNC_VERSION successfully"


sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gpg jq
sudo mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v${KUBERNETES_VERSION}/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${KUBERNETES_VERSION}/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
echo "Installed runc v$KUBERNETES_VERSION successfully."

echo "KUBELET_EXTRA_ARGS=--node-ip=$NODE_STATIC_IP" | sudo tee /etc/default/kubelet > /dev/null
echo "The static ip $ was set in the kublet args in the /etc/default/kubelet file."
