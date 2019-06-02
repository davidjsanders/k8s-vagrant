servers = [
    {
        :name => "myk8s-master",
        :type => "master",
        :box => "ubuntu/xenial64",
        :box_version => "20190516.0.0 ",
        :eth1 => "192.168.250.10",
        :mem => "2048",
        :cpu => "2",
        :provision => "yes"
    },
    {
        :name => "myk8s-node-1",
        :type => "node",
        :box => "ubuntu/xenial64",
        :box_version => "20190516.0.0 ",
        :eth1 => "192.168.250.11",
        :mem => "2048",
        :cpu => "2",
        :provision => "yes"
    },
    {
        :name => "myk8s-node-2",
        :type => "node",
        :box => "ubuntu/xenial64",
        :box_version => "20190516.0.0 ",
        :eth1 => "192.168.250.12",
        :mem => "2048",
        :cpu => "2",
        :provision => "no"
    }
  ]

$generalConfig = <<-SCRIPT
    #
    # Set Timezone
    #
    unlink /etc/localtime
    ln -s /usr/share/zoneinfo/America/Toronto /etc/localtime

    #
    # Update apt
    #
    DEBIAN_FRONTEND=noninteractive \
      apt-get update

    #
    # Install required packages
    #
    DEBIAN_FRONTEND=noninteractive \
      apt-get -o Dpkg::Options::="--force-confold" \
      -q \
      install --yes \
        apt-transport-https \
        ca-certificates \
        curl \
        jq \
        software-properties-common \
        sshpass \
        x11-apps 

    #
    # Get the Docker apt key
    #
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -

    #
    # Add the Docker repository to apt sources
    #
    DEBIAN_FRONTEND=noninteractive \
      add-apt-repository \
        "deb https://download.docker.com/linux/$(. /etc/os-release; echo "$ID") $(lsb_release -cs) stable"

    #
    # Install Docker
    #
    DEBIAN_FRONTEND=noninteractive \
      apt-get update \
      && apt-get install -y \
        docker-ce=$(apt-cache madison docker-ce | grep 18.09 | head -1 | awk '{print $3}')

    #
    # Add vagrant to the Docker group
    #
    usermod -aG docker vagrant

    #
    # Get the Google apt key and add the sources
    #
    curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
    cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb http://apt.kubernetes.io/ kubernetes-xenial main
EOF

    #
    # Update
    #
    DEBIAN_FRONTEND=noninteractive \
      apt-get update

    #
    # Install the k8s packages
    #
    DEBIAN_FRONTEND=noninteractive \
      apt-get install -y \
        kubelet \
        kubeadm \
        kubectl

    #
    # Mark the k8s packages as hold so they can't be modified
    #
    apt-mark hold \
        kubelet \
        kubeadm \
        kubectl

    #
    # Turn swap off
    #
    swapoff -a

    #
    # Disable swap after reboot
    #
    sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

    #
    # Get the real IP
    #
    IP_ADDR=`ifconfig enp0s8 | grep Mask | awk '{print $2}'| cut -f2 -d:`

    #
    # Set the node-ip to the actual IP address
    #
    touch /etc/default/kubelet
    echo "KUBELET_EXTRA_ARGS=--node-ip=$IP_ADDR" | tee /etc/default/kubelet

    #
    # Update apt
    #
    DEBIAN_FRONTEND=noninteractive \
      apt-get update

    #
    # Restart k8s
    #
    systemctl restart kubelet
SCRIPT

$masterConfig = <<-SCRIPT
    #
    # ip of this box
    #
    IP_ADDR=`ifconfig enp0s8 | grep Mask | awk '{print $2}'| cut -f2 -d:`

    #
    # install k8s master
    #
    HOST_NAME=$(hostname -s)
    kubeadm init \
        --apiserver-advertise-address=$IP_ADDR \
        --apiserver-cert-extra-sans=$IP_ADDR  \
        --node-name $HOST_NAME \
        --pod-network-cidr=192.168.0.0/16

    #
    # Copy config
    #
    sudo --user=vagrant mkdir -p /home/vagrant/.kube
    cp -i /etc/kubernetes/admin.conf /home/vagrant/.kube/config
    chown $(id -u vagrant):$(id -g vagrant) /home/vagrant/.kube/config
    export KUBECONFIG=/etc/kubernetes/admin.conf

    #
    # Install Calico
    #
    kubectl apply \
        -f https://docs.projectcalico.org/v3.1/getting-started/kubernetes/installation/hosted/rbac-kdd.yaml
    kubectl apply \
        -f https://docs.projectcalico.org/v3.1/getting-started/kubernetes/installation/hosted/kubernetes-datastore/calico-networking/1.7/calico.yaml

    #
    # Create the join token
    #
    kubeadm token create --print-join-command >> /etc/kubeadm_join_cmd.sh
    chmod +x /etc/kubeadm_join_cmd.sh

    #
    # Setup inter-vm communication
    #
    sed -i "/^[^#]*PasswordAuthentication[[:space:]]no/c\PasswordAuthentication yes" /etc/ssh/sshd_config
    service sshd restart

    #
    # Add workers to /etc/hosts
    #
    echo "$K8SNODE1    k8s-node-1" | tee -a /etc/hosts
    echo "$K8SNODE2    k8s-node-2" | tee -a /etc/hosts

    #
    # Get Helm
    #
    current_dir=$(pwd)
    mkdir -p /tmp/helm
    cd /tmp/helm
    wget https://storage.googleapis.com/kubernetes-helm/helm-v2.14.0-linux-386.tar.gz
    tar -xvf helm-v2.14.0-linux-386.tar.gz
    mv linux-386/helm /usr/local/bin/
    mv linux-386/tiller /usr/local/bin/
    cd $(current_dir)

    #
    # Create service account script
    #
    cat <<-EOF >/home/vagrant/rbac-config.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: tiller
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: tiller
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: tiller
    namespace: kube-system
EOF
    chown vagrant /home/vagrant/rbac-config.yaml

    #
    # Create Helm initialization script
    #
    cat <<-EOF >/home/vagrant/helm-init.sh
#!/bin/bash
echo "Taint - remove taint from master node"
kubectl taint nodes --all node-role.kubernetes.io/master-
echo "Apply RBAC Configuration to k8s"
kubectl apply -f /home/vagrant/rbac-config.yaml
echo "Initialize Helm"
helm init --service-account tiller --history-max 200
EOF
    chmod +x /home/vagrant/helm-init.sh
    chown vagrant /home/vagrant/helm-init.sh

    #
    # Modify vagrant's login script
    #
    cat <<-EOF >/tmp/script
#
# BEGIN: Generated by vagrant provisioning script
#
echo ""
echo "For first time initialization (i.e. just after provisioning), "
echo "remember to run helm-init.sh AFTER the cluster is ready; e.g."
echo ""
echo "  ./helm-init.sh"
echo ""
echo "Current node status is:"
echo
kubectl get nodes -o wide
echo ""
#
# END:   Generated by vagrant provisioning script
#
EOF
    cat /tmp/script | tee -a /home/vagrant/.bashrc
SCRIPT

$workerConfig = <<-SCRIPT
    #
    # Update apt
    #
    apt-get update

    #
    # Install required packages
    #
    apt-get install -y \
        sshpass

    #
    # Get join command from master
    #
    sshpass -p "vagrant" scp -o StrictHostKeyChecking=no vagrant@$K8SMASTER:/etc/kubeadm_join_cmd.sh .

    #
    # Get public key from master and add to authorized hosts
    #
    sshpass -p "vagrant" scp -o StrictHostKeyChecking=no vagrant@$K8SMASTER:/home/vagrant/.ssh/id_rsa.pub master.pub
    mkdir -p /home/vagrant/.ssh
    touch /home/vagrant/.ssh/authorized_keys
    cat master.pub >> /home/vagrant/.ssh/authorized_keys
    chown -R vagrant /home/vagrant/.ssh
    rm master.pub

    #
    # Run join command
    #
    sh ./kubeadm_join_cmd.sh
SCRIPT

$vagrantConfig = <<-SCRIPT
    #
    # Create private/public key
    #
    ssh-keygen -b 4096 -t rsa -N "" -f /home/vagrant/.ssh/id_rsa

    #
    # Enable auto complete
    #
    echo 'source <(kubectl completion bash)' >>~/.bashrc
SCRIPT

Vagrant.configure("2") do |config|
  servers.each do |opts|
    if opts[:provision] == "yes"
      config.vm.define opts[:name] do |config|
        config.vm.box = opts[:box]
        config.vm.box_version = opts[:box_version]
        config.vm.hostname = opts[:name]
        config.vm.network :private_network, ip:  opts[:eth1]
        config.vm.synced_folder "data/", "/data"
        config.ssh.forward_x11 = true

        config.vm.provider "virtualbox" do |v|
            v.name = opts[:name]
            v.customize ["modifyvm", :id, "--memory", opts[:mem]]
            v.customize ["modifyvm", :id, "--cpus", opts[:cpu]]
        end

        config.vm.provision "shell", 
          inline: $generalConfig , 
          env: {
            LFDUser:ENV['LFDUser'], 
            LFDPassword:ENV['LFDPassword'], 
            LFDUrl:ENV['LFDUrl']
          }

        if opts[:type] == "master"
          config.vm.network "forwarded_port", guest: 80, host: 20080
          config.vm.network "forwarded_port", guest: 443, host: 20443
          config.vm.provision "shell", 
            inline: $masterConfig,
            env: {
                K8SNODE1:servers[1][:eth1],
                K8SNODE2:servers[1][:eth1]
            }
        else
          config.vm.provision "shell", 
            inline: $workerConfig,
            env: {
                K8SMASTER:servers[0][:eth1],
            }
        end
        config.vm.provision "shell", 
            inline: $vagrantConfig,
            privileged: false
      end
    end
  end
end
