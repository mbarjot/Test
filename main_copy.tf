provider "aws" {
  region     = "eu-west-1"
  access_key = ""
  secret_key = ""
}

resource "aws_instance" "labinfra" {
  ami           = "ami-079d9017cb651564d"
  instance_type = "t2.micro"
  #availability_zone = "eu-west-1b"
  key_name = "IrelandKP"


  network_interface {
    network_interface_id = aws_network_interface.WEB1_interface_1.id
    device_index         = 0
  }
  user_data = <<EOF
              #!/bin/bash
              sudo su
              yum -y install httpd
              echo "<p> Welcome on your instance host on AWS ! </p>" >> /var/www/html/index.html
              sudo systemctl enable httpd
              sudo systemctl start httpd
              EOF
  tags = {
    Name = "WEB1"
  }
}

resource "aws_vpc" "terraform_vpc" {
  cidr_block       = "192.168.0.0/16"
  tags = {
    Name = "ESGI_LAB"
  }
}

resource "aws_subnet" "subnet_1" {
  vpc_id     = aws_vpc.terraform_vpc.id
  cidr_block = "192.168.1.0/24"

  tags = {
    Name = "Laboratoire_Subnet"
  }
}

resource "aws_network_interface" "WEB1_interface_1" {
  subnet_id       = aws_subnet.subnet_1.id
  private_ips     = ["192.168.1.10"]
  security_groups = [aws_security_group.allow_http_ssh.id]
}

resource "aws_security_group" "allow_http_ssh" {
  name        = "allow_http_ssh"
  description = "Allow HTTPS & SSH inbound traffic"
  vpc_id      = aws_vpc.terraform_vpc.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_http_ssh"
  }
}

resource "aws_route_table" "esgi_route_table" {
  vpc_id = aws_vpc.terraform_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gateway.id
  }
}

resource "aws_internet_gateway" "gateway" {
  vpc_id = aws_vpc.terraform_vpc.id

  tags = {
    Name = "ESGI_gateway"
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet_1.id
  route_table_id = aws_route_table.esgi_route_table.id
}

resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.WEB1_interface_1.id
  associate_with_private_ip = "192.168.1.10"
  depends_on                = [aws_internet_gateway.gateway]
}

