provider "aws" {
  region = "eu-west-1"
}

variable "prefix" {
  description = "servername prefix"
  default = "my-test-sdc-ubuntu-20-04"
}

#PLEASE INSERT THE AMI ID CREATED IN THE PREVIOUS STEP
resource "aws_instance" "sdc" {
  ami           = "ami-00967270fc9e366a8"
  instance_type = "t2.micro"
  key_name = "csc-ireland"
  count = 1
  vpc_security_group_ids = [
    "sg-080b7c006220a6283"
  ]

  subnet_id = "subnet-05b6a79635031102c"
  tags = {
    Name = "${var.prefix}${count.index}"
  }
}

output "instances" {
  value       = "${aws_instance.sdc.*.private_ip}"
  description = "PrivateIP address details"
}
