terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "ap-south-1"
}
resource "aws_vpc" "vpsmod1" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "MYVPC"
  }
}
resource "aws_subnet" "mod1pub" {
  vpc_id     = aws_vpc.vpsmod1.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "ap-south-1a"

  tags = {
    Name = "public-vpc"
  }
}
resource "aws_subnet" "mod1pri" {
  vpc_id     = aws_vpc.v.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "ap-south-1b"

  tags = {
    Name = "private-vpc"
  }
}
resource "aws_internet_gateway" "mod1ig" {
  vpc_id = aws_vpc.vpsmod1.id

  tags = {
    Name = "igw"
  }
}
resource "aws_route_table" "mod1rt1" {
  vpc_id = aws_vpc.vpsmod1.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.mod1ig.id
  }


  tags = {
    Name = "public-rt"
  }
}
resource "aws_eip" "mod1elastic" {
  domain   = "vpc"
}
resource "aws_nat_gateway" "mod1ng" {
  allocation_id = aws_eip.mod1elastic.id
  subnet_id     = aws_subnet.mod1pub.id

  tags = {
    Name = "NGW"
  }
}
resource "aws_route_table" "mod1rt2" {
  vpc_id = aws_vpc.vpsmod1.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.mod1ng.id
  }


  tags = {
    Name = "private-rt"
  }
}
resource "aws_route_table_association" "mod1associate1" {
  subnet_id      = aws_subnet.mod1pub.id
  route_table_id = aws_route_table.mod1rt1.id
}
resource "aws_route_table_association" "mod1associate2" {
  subnet_id      = aws_subnet.mod1pri.id
  route_table_id = aws_route_table.mod1rt2.id
}
resource "aws_security_group" "mod1publicsec" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.vpsmod1.id

  ingress {
    description      = "TLS from VPC"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

    ingress {
    description      = "TLS from VPC"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    
  }

  resource "aws_security_group" "mod1privatesec" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.vpsmod1.id

  ingress {
    description      = "TLS from VPC"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["10.0.2.0/24"]
    
  }
  ingress {
    description      = "TLS from VPC"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["10.0.2.0/24"]
    
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    
  }

  tags = {
    Name = "allow_tls"
  }
}

  tags = {
    Name = "private_security"
  }
}

# stage2
# Create the Elastic Load Balancer
resource "aws_elb" "mod1balancer" {
  name               = "model1elb"
  subnets            = [aws_subnet.mod1pub.id]
  security_groups    = [aws_security_group.mod1publicsec.id]
  instances          = aws_autoscaling_group.mod1scalingpub.ids
  health_check {
    target              = "HTTP:80/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}



resource "aws_instance" "publicmachine1" {
  count         = 2
  instance_type = "t2.micro"
  ami           = "ami-078efad6f7ec18b8a"
  key_name      =  "today2502"
  subnet_id     = "mod1pub"
  security_group_ids = ["mod1publicsec"]
  
  tags = {
    Name = "example-instance-${count.index + 1}"
  }
  
  # Additional instance configuration
}

resource "aws_launch_configuration" "mod1config" {
  name_prefix   = "mod1config"
  image_id      = "ami-078efad6f7ec18b8a"
  instance_type = "t2.micro"
  security_groups = ["mod1publicsec"]
  
  # Additional launch configuration settings
}

resource "aws_autoscaling_group" "mod1scalingpub" {
  name                 = "scaling"
  desired_capacity     = 2
  min_size             = 2
  max_size             = 5
  launch_configuration = aws_launch_configuration.mod1config.name
  vpc_zone_identifier  = ["subnet-xxxxxxxxxxxxxxx"]
  
  # Additional auto scaling group settings
}



#stage 3
# Create the Elastic Load Balancer
resource "aws_elb" "mod1balancer" {
  name               = "model1elb"
  subnets            = [aws_subnet.mod1pub.id]
  security_groups    = [aws_security_group.mod1publicsec.id]
  instances          = aws_autoscaling_group.mod1scalingpub.ids
  health_check {
    target              = "HTTP:80/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}



resource "aws_instance" "privatemachine1" {
  count         = 2
  instance_type = "t2.micro"
  ami           = "ami-078efad6f7ec18b8a"
  key_name      =  "today2502"
  subnet_id     = "mod1pri"
  security_group_ids = ["mod1privatesec"]
  
  tags = {
    Name = "privatemachine1-${count.index + 1}"
  }
  
  # Additional instance configuration
}

resource "aws_launch_configuration" "mod1config1" {
  name_prefix   = "mod1config1"
  image_id      = "ami-078efad6f7ec18b8a"
  instance_type = "t2.micro"
  security_groups = ["mod1privatesec"]
  
  # Additional launch configuration settings
}

resource "aws_autoscaling_group" "mod1scalingpri" {
  name                 = "scaling"
  desired_capacity     = 2
  min_size             = 2
  max_size             = 5
  launch_configuration = aws_launch_configuration.mod1config1.name
  vpc_zone_identifier  = ["subnet-xxxxxxxxxxxxxxx"]
  
  # Additional auto scaling group settings
}

