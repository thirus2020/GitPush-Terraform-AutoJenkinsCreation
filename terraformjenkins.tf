terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "eu-central-1"
}
data "aws_availability_zones" "available" {}
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# Create a VPC-01
resource "aws_vpc" "VPC-01" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "VPC-01"
  }
}

resource "aws_internet_gateway" "VPC-01-IGW" {
  vpc_id = aws_vpc.VPC-01.id

  tags = {
    Name = "VPC-01-IGW"
  }
}
# Create public subnet
resource "aws_subnet" "VPC01-Public-SN" {
  vpc_id     = aws_vpc.VPC-01.id
  cidr_block = "10.0.1.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "VPC01-Public-SN"
  }
}

resource "aws_route_table" "VPC01-Public-RT" {
  vpc_id = aws_vpc.VPC-01.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.VPC-01-IGW.id
  }

  tags = {
    Name = "VPC01-Public-RT"
  }
}

resource "aws_route_table_association" "VPC01-Public-RT-Association" {
  subnet_id      = aws_subnet.VPC01-Public-SN.id
  route_table_id = aws_route_table.VPC01-Public-RT.id
}

resource "aws_security_group" "VPC01-VM-NSG" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.VPC-01.id

  tags = {
    Name = "VPC01-VM-NSG"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_ssh" {
  security_group_id = aws_security_group.VPC01-VM-NSG.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_vpc_security_group_ingress_rule" "allow_dataservice_5000" {
  security_group_id = aws_security_group.VPC01-VM-NSG.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 5000
  ip_protocol       = "tcp"
  to_port           = 5000
}

resource "aws_vpc_security_group_ingress_rule" "allow_userservice_5001" {
  security_group_id = aws_security_group.VPC01-VM-NSG.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 5001
  ip_protocol       = "tcp"
  to_port           = 5001
}

resource "aws_vpc_security_group_ingress_rule" "allow_jenkins" {
  security_group_id = aws_security_group.VPC01-VM-NSG.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 8080
  ip_protocol       = "tcp"
  to_port           = 8080
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.VPC01-VM-NSG.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

resource "aws_key_pair" "jenkins_key" {
  key_name   = "Jenkins_Server_Key"
  public_key = file("jenkins_key.pub")
}

# Create a Public Instance
resource "aws_instance" "Jenkins_Server" {
  ami                     = data.aws_ami.amazon_linux.id
  instance_type           = "t3.micro"
  key_name                = aws_key_pair.jenkins_key.key_name
  subnet_id               = aws_subnet.VPC01-Public-SN.id
  vpc_security_group_ids  = [aws_security_group.VPC01-VM-NSG.id]
  associate_public_ip_address 	=  true
    root_block_device {
    volume_size = 20   
    volume_type = "gp3"
  }
  user_data = <<-EOF
#!/bin/bash
sudo yum update -y

sudo yum install wget -y

sudo wget -O /etc/yum.repos.d/jenkins.repo \
    https://pkg.jenkins.io/rpm-stable/jenkins.repo

sudo yum upgrade -y

sudo yum install java-21-amazon-corretto -y

sudo yum install jenkins -y

sudo systemctl daemon-reload

sudo yum install -y git

systemctl enable jenkins
systemctl start jenkins
EOF


  tags = {
    Name = "Jenkins_Server"
  }
}