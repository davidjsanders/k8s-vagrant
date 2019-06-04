#!/bin/bash
IP_ADDR=`ifconfig enp0s8 | grep Mask | awk '{print $2}'| cut -f2 -d:`
HOSTS="traefik-ui nginx-frontend"
yaml_files=$(ls -1 /vagrant/traefik/*.yaml)

echo "Remove taint from master"
kubectl taint node myk8s-master node-role.kubernetes.io/master-
echo

echo "Process Traefik YAML files"
for yaml_file in $yaml_files
do
    echo "Processing: ${yaml_file}"
    kubectl apply -f $yaml_file
done
echo

echo "Process HOSTS entries"
for host in $HOSTS
do
    echo "Adding ${host} to /etc/hosts"
    echo "${IP_ADDR}    ${host}" | sudo tee -a /etc/hosts
    echo
done
echo

echo "Done"