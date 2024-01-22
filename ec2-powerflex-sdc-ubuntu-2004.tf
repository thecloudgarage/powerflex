provider "aws" {
  region = "eu-west-1"
}

variable "prefix" {
  description = "servername prefix"
  default = "ubuntu-2204-apex-block-sdc-ami"
}

#PLEASE CHANGE UBUNTU 22.04 AMI AS PER REGION. THIS IS FOR EU IRELAND
resource "aws_instance" "sdc" {
  ami           = "ami-08031206a0ff5a6ac"
  instance_type = "t2.micro"
  key_name = "csc-ireland"
  count = 1
  vpc_security_group_ids = [
    "sg-080b7c006220a6283"
  ]
  user_data = <<EOF
#!/bin/bash
sudo apt update -y
sudo apt install tree libaio1 linux-image-5.4.0-167-generic linux-image-extra-virtual libnuma1 uuid-runtime nano sshpass unzip -y
cd /home/ubuntu

cp /etc/default/grub /etc/default/grub.backup
# In the above list of packages, we have installed 5.4.0-167-generic linux kernel for ubuntu 20.04
# This ensures compatability with the scini driver files available in Dell FTP site
# Below we are setting the grub to boot from 167 generic kernel version
sed -i \
s/GRUB_DEFAULT=0/GRUB_DEFAULT='"Advanced options for Ubuntu>Ubuntu, with Linux 5.4.0-167-generic"'/g \
/etc/default/grub
sudo update-grub
cd /home/ubuntu
wget https://pflex-packages.s3.eu-west-1.amazonaws.com/pflex-45/Software_Only_Complete_4.5.0_287/PowerFlex_4.5.0.287_SDCs_for_manual_install.zip
unzip PowerFlex_4.5.0.287_SDCs_for_manual_install.zip
cd PowerFlex_4.5.0.287_SDCs_for_manual_install/
unzip PowerFlex_4.5.0.287_Ubuntu20.04_SDC.zip
cd PowerFlex_4.5.0.287_Ubuntu20.04_SDC/
tar -xvf EMC-ScaleIO-sdc-4.5-0.287.Ubuntu.20.04.4.x86_64.tar
./siob_extract EMC-ScaleIO-sdc-4.5-0.287.Ubuntu.20.04.4.x86_64.siob
MDM_IP=10.204.111.85,10.204.111.86,10.204.111.87 dpkg -i EMC-ScaleIO-sdc-4.5-0.287.Ubuntu.20.04.4.x86_64.deb
export REPO_USER=QNzgdxXix
export REPO_PASSWORD=Aw3wFAwAq3
export MDM_IP=10.204.111.85,10.204.111.86,10.204.111.87
cd /bin/emc/scaleio/scini_sync/
wget https://raw.githubusercontent.com/thecloudgarage/powerflex/main/driver_sync.conf
touch /etc/emc/scaleio/scini_test.txt
/bin/emc/scaleio/scini_sync/driver_sync.sh scini retrieve Ubuntu20.04/4.5.0.287/5.4.0-167-generic/
systemctl restart scini
sleep 20
cd /etc/emc/scaleio/
wget https://raw.githubusercontent.com/thecloudgarage/powerflex/main/set_scini_initiator.sh
chmod +x /etc/emc/scaleio/set_scini_initiator.sh
cd /etc/systemd/system/
wget https://raw.githubusercontent.com/thecloudgarage/powerflex/main/set_scini_initiator.service
sudo systemctl daemon-reload
sudo systemctl enable set_scini_initiator.service
sudo systemctl start set_scini_initiator.service
sudo sed -i "s/PasswordAuthentication no/PasswordAuthentication yes/g" /etc/ssh/sshd_config
sudo sed -i "s/#PermitRootLogin prohibit-password/PermitRootLogin yes/g" /etc/ssh/sshd_config
sudo service ssh restart
sudo chpasswd <<<"root:ubuntu"
sudo chpasswd <<<"ubuntu:ubuntu"
reboot
EOF
  subnet_id = "subnet-05b6a79635031102c"
  tags = {
    Name = "${var.prefix}${count.index}"
  }
}

output "instances" {
  value       = "${aws_instance.sdc.*.private_ip}"
  description = "PrivateIP address details"
}