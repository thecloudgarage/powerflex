#PLEASE CHANGE THE SITE URL TO SELF HOSTED WEB SERVICE WHERE YOU HAVE STORED THE POWERFLEX PACKAGE ZIP FILE.

provider "aws" {
  region = "eu-west-1"
}

variable "prefix" {
  description = "servername prefix"
  default = "ubuntu-2204-apex-block-sdc-ami"
}

locals {
  mdmIpAddresses = "10.204.111.85,10.204.111.86,10.204.111.87"
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
#INSTALL REQUIRED PACKAGES
sudo apt install tree libaio1 linux-image-5.4.0-167-generic linux-image-extra-virtual libnuma1 uuid-runtime nano sshpass unzip -y
cd /home/ubuntu
#RECONFIGURE GRUB TO USE THE COMPATIBLE LINUX KERNEL
cp /etc/default/grub /etc/default/grub.backup
# In the above list of packages, we have installed 5.4.0-167-generic linux kernel for ubuntu 20.04
# This ensures compatability with the scini driver files available in Dell FTP site
# Below we are setting the grub to boot from 167 generic kernel version
sed -i \
s/GRUB_DEFAULT=0/GRUB_DEFAULT='"Advanced options for Ubuntu>Ubuntu, with Linux 5.4.0-167-generic"'/g \
/etc/default/grub
sudo update-grub
#DOWNLOAD AND INSTALL POWERFLEX SDC PACKAGES
cd /home/ubuntu
wget https://<SITE_URL>/Software_Only_Complete_4.5.0_287/PowerFlex_4.5.0.287_SDCs_for_manual_install.zip
unzip PowerFlex_4.5.0.287_SDCs_for_manual_install.zip
cd PowerFlex_4.5.0.287_SDCs_for_manual_install/
unzip PowerFlex_4.5.0.287_Ubuntu20.04_SDC.zip
cd PowerFlex_4.5.0.287_Ubuntu20.04_SDC/
tar -xvf EMC-ScaleIO-sdc-4.5-0.287.Ubuntu.20.04.4.x86_64.tar
./siob_extract EMC-ScaleIO-sdc-4.5-0.287.Ubuntu.20.04.4.x86_64.siob
MDM_IP=${local.mdmIpAddresses} dpkg -i EMC-ScaleIO-sdc-4.5-0.287.Ubuntu.20.04.4.x86_64.deb
#DOWNLOAD THE COMPATIBLE SCINI.TAR FROM DELL FTP SITE
export REPO_USER=QNzgdxXix
export REPO_PASSWORD=Aw3wFAwAq3
export MDM_IP=${local.mdmIpAddresses}
sudo echo "MDM_IP=$MDM_IP; export MDM_IP" >> ~/.profile
sudo source ~/.profile
cd /bin/emc/scaleio/scini_sync/
wget https://raw.githubusercontent.com/thecloudgarage/powerflex/main/driver_sync.conf
touch /etc/emc/scaleio/scini_test.txt
#INSTALL SCINI SERVICE WITH COMPATIBILITY
/bin/emc/scaleio/scini_sync/driver_sync.sh scini retrieve Ubuntu20.04/4.5.0.287/5.4.0-167-generic/
systemctl restart scini
sleep 20
#ENSURE UUID IS UNIQUELY CREATED FOR SDC ELSE THERE WILL BE A CONFLICT
cd /etc/emc/scaleio/
wget https://raw.githubusercontent.com/thecloudgarage/powerflex/main/set_scini_initiator.sh
chmod +x /etc/emc/scaleio/set_scini_initiator.sh
cd /etc/systemd/system/
wget https://raw.githubusercontent.com/thecloudgarage/powerflex/main/set_scini_initiator.service
sudo systemctl daemon-reload
sudo systemctl enable set_scini_initiator.service
sudo systemctl start set_scini_initiator.service
#ENSURE PASSWORD BASED AUTH IS ENABLED
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

resource "time_sleep" "wait_for_ec2_creation" {
  create_duration = "600s"
  depends_on = [ aws_instance.sdc ]
}

resource "null_resource" "checkconnection" {
  depends_on = [time_sleep.wait_for_ec2_creation]
  connection {
      type     = "ssh"
      user     = "root"
      password = "ubuntu"
      host     = "${aws_instance.sdc[0].private_ip}"
  }
  // change permissions to executable and pipe its output into a new file
  provisioner "remote-exec" {
    inline = [
      "rm -rf /etc/emc/scaleio/scini_test.txt"
    ]
  }
}

resource "time_sleep" "wait_for_ec2_root_connection" {
  create_duration = "20s"
  depends_on = [ null_resource.checkconnection ]
}

resource "aws_ami_from_instance" "create_sdc_ami" {
  depends_on = [time_sleep.wait_for_ec2_root_connection]
  name               = "test-ubuntu-20-04-sdc-ami"
  source_instance_id = "${aws_instance.sdc[0].id}"
  snapshot_without_reboot = true
}

output "ami-id" {
  value       = "${aws_ami_from_instance.create_sdc_ami.id}"
  description = "AMI ID created for the ubuntu 20.04 SDC"
}
output "instances" {
  value       = "${aws_instance.sdc.*.private_ip}"
  description = "PrivateIP address details"
}
