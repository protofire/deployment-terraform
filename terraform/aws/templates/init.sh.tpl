#!/bin/bash
echo "Create ${username} user..."
useradd -m -s /bin/bash ${username}
usermod -aG sudo ${username}
mkdir -p /home/${username}/.ssh/
touch /home/${username}/.ssh/authorized_keys
echo "${ansible_public_key}" >> /home/${username}/.ssh/authorized_keys
echo "${engineer_public_key}" >> /home/${username}/.ssh/authorized_keys
echo "${username} ALL = (ALL: ALL) NOPASSWD: ALL" | tee /etc/sudoers.d/${username}
chown -R ${username}:${username} /home/${username}/.ssh
chmod 700 -R /home/${username}/.ssh
chmod 600 /home/${username}/.ssh/authorized_keys
echo "User ${username} created!"
echo "Set hostname..."
hostnamectl set-hostname ${hostname}
echo "Done!"
echo "Starting do some stuff with additional volume..."
while true
do
if [ -e ${ebs_device_name} ] ; then
  echo "Disk attached! Trying to find file system..."
  DISK_NAME=$(echo ${ebs_device_name} | sed 's/dev//' | tr -d /)
  FS=$(lsblk --output NAME,FSTYPE --pairs | grep $DISK_NAME | cut -d ' ' -f 2 | grep -o '".*"' | sed 's/"//g')
  
  if [[ -z $FS ]]; then
    
    echo "Disk doesn't have file system! Preparing..."
    mkfs.ext4 -m 0 -F -E lazy_itable_init=0,lazy_journal_init=0,discard ${ebs_device_name}
    mkdir /data && chmod -R 777 /data
    cp /etc/fstab /etc/fstab.orig
    UUID=$(blkid ${ebs_device_name} -s UUID -o value)
    echo "UUID=$UUID  /data  ext4  discard,defaults,nofail  0  2" | tee -a /etc/fstab
    mount -a
    break
  else
    echo "Disk has file system! Attaching..."
    mkdir /data && chmod -R 777 /data
    cp /etc/fstab /etc/fstab.orig
    UUID=$(blkid ${ebs_device_name} -s UUID -o value)
    echo "UUID=$UUID  /data  ext4  discard,defaults,nofail  0  2" | tee -a /etc/fstab
    mount -a
    break
  fi
else
  echo "Disk still attaching..."
  sleep 5
fi
done
echo "All steps completed!"
