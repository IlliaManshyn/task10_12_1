#!bin/bash
dir="$(cd "$(dirname "$0")" && pwd)"
source $dir/config
mkdir $dir/networks
mkdir -p $dir/config-drives/vm1-config
mkdir -p $dir/config-drives/vm2-config


#Configuring network
MAC=52:54:00:`(date; cat /proc/interrupts) | md5sum | sed -r 's/^(.{6}).*$/\1/; s/([0-9a-f]{2})/\1:/g; s/:$//;'`
cat $dir/templates/external.xml | \
sed 's/EXTERNAL_NET_NAME/'$EXTERNAL_NET_NAME'/; s/EXTERNAL_NET_HOST_IP/'$EXTERNAL_NET_HOST_IP'/; s/EXTERNAL_NET_MASK/'$EXTERNAL_NET_MASK'/; s/MAC/'$MAC'/; s/VM1_NAME/'$VM1_NAME'/; s/VM1_EXTERNAL_IP/'$VM1_EXTERNAL_IP'/' > $dir/networks/external.xml

cat $dir/templates/internal.xml | \
sed 's/INTERNAL_NET_NAME/'$INTERNAL_NET_NAME'/' > $dir/networks/internal.xml
 
cat $dir/templates/management.xml | \
sed 's/MANAGEMENT_NET_NAME/'$MANAGEMENT_NET_NAME'/; s/MANAGEMENT_HOST_IP/'$MANAGEMENT_HOST_IP'/; s/MANAGEMENT_NET_MASK/'$MANAGEMENT_NET_MASK'/' > $dir/networks/management.xml

for n in $dir/networks/*
do
virsh net-define $n
done

virsh net-start external
virsh net-start internal
virsh net-start management
mkdir /var/lib/libvirt/vm1
mkdir /var/lib/libvirt/vm2

#Configuring vm1 meta-data, user-data and vm1.xml
yes "y" | ssh-keygen -f .ssh/id_rsa -N ""
key="$(cat .ssh/id_rsa.pub | cut -d ' ' -f2)"
cat $dir/templates/user-datavm1 | \
sed 's@KEY@'$key'@; s/VM1_MANAGEMENT_IP/'$VM1_MANAGEMENT_IP'/; s/VXLAN_NET/'$VXLAN_NET'/g; s/VXLAN_IF/'$VXLAN_IF'/g; s/VID/'$VID'/; s/VM1_INTERNAL_IP/'$VM1_INTERNAL_IP'/; s/VM2_INTERNAL_IP/'$VM2_INTERNAL_IP'/; s/VM_DNS/'$VM_DNS'/' > $dir/config-drives/vm1-config/user-data 

cat $dir/templates/meta-datavm1  | \
sed 's/VM1_NAME/'$VM1_NAME'/; s/VM1_EXTERNAL_IF/'$VM1_EXTERNAL_IF'/g; s/VM1_INTERNAL_IF/'$VM1_INTERNAL_IF'/g; s/VM1_INTERNAL_IP/'$VM1_INTERNAL_IP'/; s/INTERNAL_NET_IP/'$INTERNAL_NET_IP'/ ; s/INTERNAL_NET_MASK/'$INTERNAL_NET_MASK'/1; s/VM1_MANAGEMENT_IF/'$VM1_MANAGEMENT_IF'/g; s/VM1_MANAGEMENT_IP/'$VM1_MANAGEMENT_IP'/; s/MANAGEMENT_NET_IP/'$MANAGEMENT_NET_IP'/; s/MANAGEMENT_NET_MASK/'$MANAGEMENT_NET_MASK'/'  > $dir/config-drives/vm1-config/meta-data

cat $dir/templates/vm1.xml | \
sed 's/VM1_NAME/'$VM1_NAME'/; s/VM1_NUM_CPU/'$VM1_NUM_CPU'/; s/VM1_MB_RAM/'$VM1_MB_RAM'/; s/VM_TYPE/'$VM_TYPE'/; s@VM1_HDD@'$VM1_HDD'@; s@VM1_CONFIG_ISO@'$VM1_CONFIG_ISO'@; s/MAC/'$MAC'/; s/EXTERNAL_NET_NAME/'$EXTERNAL_NET_NAME'/; s/INTERNAL_NET_NAME/'$INTERNAL_NET_NAME'/; s/MANAGEMENT_NET_NAME/'$MANAGEMENT_NET_NAME'/;' > $dir/vm1.xml

#Configuring vm2 ...
cat $dir/templates/user-datavm2 | \
sed 's@KEY@'$key'@; s/VM2_MANAGEMENT_IP/'$VM2_MANAGEMENT_IP'/; s/VXLAN_IF/'$VXLAN_IF'/g; s/VID/'$VID'/; s/VXLAN_NET/'$VXLAN_NET'/g ; s/VM1_INTERNAL_IP/'$VM1_INTERNAL_IP'/; s/VM2_INTERNAL_IP/'$VM2_INTERNAL_IP'/; s/VM_DNS/'$VM_DNS'/' > $dir/config-drives/vm2-config/user-data

cat $dir/templates/meta-datavm2  | \
sed 's/VM2_NAME/'$VM2_NAME'/; s/VM1_INTERNAL_IP/'$VM1_INTERNAL_IP'/ ; s/VM2_INTERNAL_IF/'$VM2_INTERNAL_IF'/g; s/VM2_INTERNAL_IP/'$VM2_INTERNAL_IP'/; s/INTERNAL_NET_IP/'$INTERNAL_NET_IP'/ ; s/INTERNAL_NET_MASK/'$INTERNAL_NET_MASK'/; s/VM2_MANAGEMENT_IF/'$VM2_MANAGEMENT_IF'/g; s/VM2_MANAGEMENT_IP/'$VM2_MANAGEMENT_IP'/; s/MANAGEMENT_NET_IP/'$MANAGEMENT_NET_IP'/; s/MANAGEMENT_NET_MASK/'$MANAGEMENT_NET_MASK'/'  > $dir/config-drives/vm2-config/meta-data

cat $dir/templates/vm2.xml | \
sed 's/VM2_NAME/'$VM2_NAME'/; s/VM2_NUM_CPU/'$VM2_NUM_CPU'/; s/VM2_MB_RAM/'$VM2_MB_RAM'/; s/VM_TYPE/'$VM_TYPE'/; s@VM2_HDD@'$VM2_HDD'@; s@VM2_CONFIG_ISO@'$VM2_CONFIG_ISO'@; s/INTERNAL_NET_NAME/'$INTERNAL_NET_NAME'/; s/MANAGEMENT_NET_NAME/'$MANAGEMENT_NET_NAME'/' > $dir/vm2.xml


wget -O /var/lib/libvirt/images/ubuntu-server-16.04.qcow2 $VM_BASE_IMAGE

cp /var/lib/libvirt/images/ubuntu-server-16.04.qcow2 $VM1_HDD
cp /var/lib/libvirt/images/ubuntu-server-16.04.qcow2 $VM2_HDD

#creating iso files for vm1 and vm2
mkisofs -o $VM1_CONFIG_ISO -V cidata -r -J --quiet $dir/config-drives/vm1-config
mkisofs -o $VM2_CONFIG_ISO -V cidata -r -J --quiet $dir/config-drives/vm2-config

virsh define $dir/vm1.xml
virsh define $dir/vm2.xml
virsh start vm1
virsh start vm2
