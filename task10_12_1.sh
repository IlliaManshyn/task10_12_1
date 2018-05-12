#!bin/bash

export dir="$(cd "$(dirname "$0")" && pwd)"
export MAC=52:54:00:`(date; cat /proc/interrupts) | md5sum | sed -r 's/^(.{6}).*$/\1/; s/([0-9a-f]{2})/\1:/g; s/:$//;'`

#Exporting variables from config
export $(grep -v '#' $dir/templates/config)
envsubst < $dir/templates/config > $dir/config
export $(grep -v '#' $dir/config)
#Creating directories

mkdir -p $(echo $SSH_PUB_KEY | rev | cut -c12- | rev)
mkdir /var/lib/libvirt/vm1
mkdir /var/lib/libvirt/vm2
mkdir $dir/networks
mkdir -p $dir/config-drives/vm1-config
mkdir -p $dir/config-drives/vm2-config

#Generating ssh key
yes "y" | ssh-keygen -f $(echo $SSH_PUB_KEY | rev | cut -c5- | rev) -N ""
export key="$(cat $SSH_PUB_KEY | cut -d ' ' -f2)"

#Preparation of file before using
envsubst < $dir/templates/vm1.xml > $dir/vm1.xml
envsubst < $dir/templates/vm2.xml > $dir/vm2.xml
envsubst < $dir/templates/meta-datavm1 > $dir/config-drives/vm1-config/meta-data
envsubst < $dir/templates/meta-datavm2 > $dir/config-drives/vm2-config/meta-data
envsubst < $dir/templates/external.xml > $dir/networks/external.xml
envsubst < $dir/templates/internal.xml > $dir/networks/internal.xml
envsubst < $dir/templates/management.xml > $dir/networks/management.xml
envsubst < $dir/templates/user-datavm1 > $dir/config-drives/vm1-config/user-data
envsubst < $dir/templates/user-datavm2 > $dir/config-drives/vm2-config/user-data

for n in $dir/networks/*
do
virsh net-define $n
done
virsh net-start external
virsh net-start internal
virsh net-start management

wget -O /var/lib/libvirt/images/ubuntu-server-16.04.qcow2 $VM_BASE_IMAGE

cp /var/lib/libvirt/images/ubuntu-server-16.04.qcow2 $VM1_HDD
cp /var/lib/libvirt/images/ubuntu-server-16.04.qcow2 $VM2_HDD

#Creating iso files for vm1 and vm2
mkisofs -o $VM1_CONFIG_ISO -V cidata -r -J --quiet $dir/config-drives/vm1-config
mkisofs -o $VM2_CONFIG_ISO -V cidata -r -J --quiet $dir/config-drives/vm2-config
#Definin and starting VMs
virsh define $dir/vm1.xml
virsh define $dir/vm2.xml
virsh start vm1
virsh start vm2
