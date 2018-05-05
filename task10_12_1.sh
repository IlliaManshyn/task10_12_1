#!bin/bash
dir="$(cd "$(dirname "$0")" && pwd)"
source $dir/config
 
#Configuring network
MAC=52:54:00:`(date; cat /proc/interrupts) | md5sum | sed -r 's/^(.{6}).*$/\1/; s/([0-9a-f]{2})/\1:/g; s/:$//;'`
cat $dir/networks/external.xml | \
sed 's/EXTERNAL_NET_NAME/'$EXTERNAL_NET_NAME'/; s/EXTERNAL_NET_HOST_IP/'$EXTERNAL_NET_HOST_IP'/; s/EXTERNAL_NET_MASK/'$EXTERNAL_NET_MASK'/; s/MAC/'$MAC'/; s/VM1_NAME/'$VM1_NAME'/; s/VM1_EXTERNAL_IP/'$VM1_EXTERNAL_IP'/' > $dir/networks/external1.xml
cp $dir/networks/external1.xml $dir/networks/external.xml
rm $dir/networks/external1.xml

cat $dir/networks/internal.xml | \
sed 's/INTERNAL_NET_NAME/'$INTERNAL_NET_NAME'/' > $dir/networks/internal1.xml
cp $dir/networks/internal1.xml $dir/networks/internal.xml
rm $dir/networks/internal1.xml
 
cat $dir/networks/management.xml | \
sed 's/MANAGEMENT_NET_NAME/'$MANAGEMENT_NET_NAME'/; s/MANAGEMENT_HOST_IP/'$MANAGEMENT_HOST_IP'/; s/MANAGEMENT_NET_MASK/'$MANAGEMENT_NET_MASK'/' > $dir/networks/management1.xml
cp $dir/networks/management1.xml $dir/networks/management.xml
rm $dir/networks/management1.xml

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
ssh-keygen  -f /home/jenkins/.ssh/id_rsa 
key="$(cat /home/jenkins/.ssh/id_rsa.pub | cut -d ' ' -f2)"
cat $dir/config-drives/vm1-config/user-data | \
sed 's@KEY@'$key'@; s/VM1_MANAGEMENT_IP/'$VM1_MANAGEMENT_IP'/' > $dir/user-data 
cp $dir/user-data $dir/config-drives/vm1-config/user-data 
rm $dir/user-data

cat $dir/config-drives/vm1-config/meta-data  | \
sed 's/VM1_NAME/'$VM1_NAME'/; s/VM1_EXTERNAL_IF/'$VM1_EXTERNAL_IF'/g; s/VM1_INTERNAL_IF/'$VM1_INTERNAL_IF'/g; s/VM1_INTERNAL_IP/'$VM1_INTERNAL_IP'/; s/INTERNAL_NET_IP/'$INTERNAL_NET_IP'/ ; s/INTERNAL_NET_MASK/'$INTERNAL_NET_MASK'/1; s/VM1_MANAGEMENT_IF/'$VM1_MANAGEMENT_IF'/g; s/VM1_MANAGEMENT_IP/'$VM1_MANAGEMENT_IP'/; s/MANAGEMENT_NET_IP/'$MANAGEMENT_NET_IP'/; s/MANAGEMENT_NET_MASK/'$MANAGEMENT_NET_MASK'/'  > $dir/meta-data
cp $dir/meta-data $dir/config-drives/vm1-config/meta-data 
rm $dir/meta-data

cat $dir/vm1-libvirt.xml | \
sed 's/VM1_NAME/'$VM1_NAME'/; s/VM1_NUM_CPU/'$VM1_NUM_CPU'/; s/VM1_MB_RAM/'$VM1_MB_RAM'/; s/VM_TYPE/'$VM_TYPE'/; s@VM1_HDD@'$VM1_HDD'@; s@VM1_CONFIG_ISO@'$VM1_CONFIG_ISO'@; s/MAC/'$MAC'/; s/EXTERNAL_NET_NAME/'$EXTERNAL_NET_NAME'/; s/INTERNAL_NET_NAME/'$INTERNAL_NET_NAME'/; s/MANAGEMENT_NET_NAME/'$MANAGEMENT_NET_NAME'/;' > $dir/vm1-libvirt
cp $dir/vm1-libvirt $dir/vm1-libvirt.xml
rm $dir/vm1-libvirt

#Configuring vm2 ...
cat $dir/config-drives/vm2-config/user-data | \
sed 's@KEY@'$key'@; s/VM2_MANAGEMENT_IP/'$VM2_MANAGEMENT_IP'/' > $dir/user-data 
cp $dir/user-data $dir/config-drives/vm2-config/user-data 
rm $dir/user-data

cat $dir/config-drives/vm2-config/meta-data  | \
sed 's/VM2_NAME/'$VM2_NAME'/; s/VM1_INTERNAL_IP/'$VM1_INTERNAL_IP'/ ; s/VM2_INTERNAL_IF/'$VM2_INTERNAL_IF'/g; s/VM2_INTERNAL_IP/'$VM2_INTERNAL_IP'/; s/INTERNAL_NET_IP/'$INTERNAL_NET_IP'/ ; s/INTERNAL_NET_MASK/'$INTERNAL_NET_MASK'/; s/VM2_MANAGEMENT_IF/'$VM2_MANAGEMENT_IF'/g; s/VM2_MANAGEMENT_IP/'$VM2_MANAGEMENT_IP'/; s/MANAGEMENT_NET_IP/'$MANAGEMENT_NET_IP'/; s/MANAGEMENT_NET_MASK/'$MANAGEMENT_NET_MASK'/'  > $dir/meta-data
cp $dir/meta-data $dir/config-drives/vm2-config/meta-data 
rm $dir/meta-data

cat $dir/vm2-libvirt.xml | \
sed 's/VM2_NAME/'$VM2_NAME'/; s/VM2_NUM_CPU/'$VM2_NUM_CPU'/; s/VM2_MB_RAM/'$VM2_MB_RAM'/; s/VM_TYPE/'$VM_TYPE'/; s@VM2_HDD@'$VM2_HDD'@; s@VM2_CONFIG_ISO@'$VM2_CONFIG_ISO'@; s/INTERNAL_NET_NAME/'$INTERNAL_NET_NAME'/; s/MANAGEMENT_NET_NAME/'$MANAGEMENT_NET_NAME'/' > $dir/vm2-libvirt
cp $dir/vm2-libvirt $dir/vm2-libvirt.xml
rm $dir/vm2-libvirt


#wget -O /var/lib/libvirt/images/ubuntu-server-16.04.qcow2 $VM_BASE_IMAGE

cp /var/lib/libvirt/images/ubuntu-server-16.04.qcow2 $VM1_HDD
cp /var/lib/libvirt/images/ubuntu-server-16.04.qcow2 $VM2_HDD

#creating iso files for vm1 and vm2
mkisofs -o $VM1_CONFIG_ISO -V cidata -r -J --quiet $dir/config-drives/vm1-config
mkisofs -o $VM2_CONFIG_ISO -V cidata -r -J --quiet $dir/config-drives/vm2-config

virsh define $dir/vm1-libvirt.xml
virsh define $dir/vm2-libvirt.xml
virsh start vm1
virsh start vm2
