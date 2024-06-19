# This script installs k3s, creates a configuration file and sets that as the default config

curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644

mkdir ~/.kube
sudo KUBECONFIG=~/.kube/config:/etc/rancher/k3s/k3s.yaml kubectl config view --flatten > ~/.kube/merged
mv ~/.kube/merged ~/.kube/config
chmod 0600 ~/.kube/config
echo "export KUBECONFIG=~/.kube/config" >> ~/.bashrc
export KUBECONFIG=~/.kube/config
#switch to k3s context
kubectl config use-context default
