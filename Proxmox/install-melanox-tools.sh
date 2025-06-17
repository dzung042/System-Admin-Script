apt -y update
apt -y install pve-headers proxmox-default-headers gcc make dkms opensm
## Melanox x3 mft version < 4.22
# Unpack the tools and install.

wget https://www.mellanox.com/downloads/MFT/mft-4.22.1-417-x86_64-deb.tgz
tar -xvzf mft-4.22.1-417-x86_64-deb.tgz
cd mft-4.22.1-417-x86_64-deb
./install.sh

#You should now be able to start the tools and check the status of the card.

mst start
mst status

# If so, configure the card. In this example the card will be configured with 8 virtual devices (SR-IOV), 4 on each port. If you don't need virtual devices, set SRIOV_EN=0 and ignore NUM_OF_VFS=8.
mlxconfig -d /dev/mst/mt4099_pciconf0 q
mlxconfig -d /dev/mst/mt4099_pciconf0 set SRIOV_EN=1 NUM_OF_VFS=8

# create tunning files: /etc/modprobe.d/mlx4_core.conf
options mlx4_core num_vfs=4,4,0 port_type_array=2,2 probe_vf=4,4,0
options mlx4_core enable_sys_tune=1
options mlx4_en inline_thold=0
options mlx4_core log_num_mgm_entry_size=-7

# load module
modprobe -r mlx4_en mlx4_ib
modprobe mlx4_en
update-initramfs -u
