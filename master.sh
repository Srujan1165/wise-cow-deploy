#!/bin/bash
set -e

### Master Config ###
POD_CIDR="192.168.0.0/16"

echo "[1] Update & Install Base Packages"
sudo apt update -y
sudo apt install -y ca-certificates curl gnupg lsb-release apt-transport-https

echo "[2] Setup Docker Repo"
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "[3] Install Docker & containerd"
sudo apt update -y
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "[4] Setup Kubernetes Repo"
sudo mkdir -p /etc/apt/keyrings
sudo curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | \
  sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /" | \
  sudo tee /etc/apt/sources.list.d/kubernetes.list > /dev/null

echo "[5] Install kubeadm, kubelet, kubectl"
sudo apt update -y
sudo apt install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

echo "[6] Disable Swap"
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

echo "[7] Enable Kernel Modules & Sysctl"
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
br_netfilter
overlay
EOF
sudo modprobe overlay
sudo modprobe br_netfilter
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
sudo sysctl --system

echo "[8] Configure containerd"
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd

echo "[9] Reset kubeadm (clean start)"
sudo kubeadm reset -f || true
sudo rm -rf /etc/kubernetes/pki

echo "[10] Initialize Control Plane"
sudo kubeadm init --pod-network-cidr=$POD_CIDR

echo "[11] Setup kubeconfig for current user"
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

echo "[12] Install Calico CNI"
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/calico.yaml

echo " Master setup complete!"
echo "Run 'kubectl get nodes' to verify"
echo " Save this command for worker nodes to join:"
kubeadm token create --print-join-command

