provider "aws" {
    access_key = "--------------" // put credentials here
    secret_key = "--------------" // put credentials here
    region = "eu-central-1"
}

## Create VPC ##
resource "aws_vpc" "terraform-vpc" {
  cidr_block       = "172.16.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "terraform-demo-vpc"
  }
}

output "aws_vpc_id" {
  value = aws_vpc.terraform-vpc.id
}

## Security Group ##
#Do not forget to open the port 8888 it the script which creates a WebSite!!!#
resource "aws_security_group" "terraform_private_sg" {
  description = "Allow limited inbound external traffic"
  vpc_id      = aws_vpc.terraform-vpc.id
  name        = "terraform_ec2_private_sg"

  ingress {
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 8888
    to_port     = 8888 // Do not forget to open the port 8888 it the script which creates a WebSite!!!
  }

  ingress {
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = -1
    to_port     = -1  // For ICMP Ping (from any port to any)
  }

    ingress {
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 3389
    to_port     = 3389  // For WinRM connection
  }

  ingress {
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 53
    to_port     = 53
  }

  ingress {
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 53
    to_port     = 53
  }

  ingress {
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 5985
    to_port     = 5985
  }

  ingress {
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 5986
    to_port     = 5986
  }

  ingress {
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 80
    to_port     = 80
  }

  ingress {
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 53
    to_port     = 53
  }

  ingress {
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 443
    to_port     = 443
  }

  egress {
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 0
    to_port     = 0
  }

  tags = {
    Name = "ec2-private-sg"
  }
}

output "aws_security_gr_id" {
  value = aws_security_group.terraform_private_sg.id
}

## Create Subnet ##
resource "aws_subnet" "main_subnet" {
  vpc_id     = aws_vpc.terraform-vpc.id
  cidr_block = "172.16.10.0/24"
//  availability_zone = "eu-central-1a"

  tags = {
    Name = "MainSubnet"
  }
}
output "aws_subnet_subnet" {
  value = aws_subnet.main_subnet.id
}


## Main Internet Gateway for VPC ##
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.terraform-vpc.id

  tags = {
    name = "Main IGW"
  }
}
## Route table for Public subnet ##
resource "aws_route_table" "public" {
    vpc_id = aws_vpc.terraform-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    name = "Public Route Table"
  }
}

## Association between Public Subnet and Public Route Table ##
resource "aws_route_table_association" "public1" {
  subnet_id = aws_subnet.main_subnet.id
  route_table_id = aws_route_table.public.id
}

## My instances ##
## instance1 ##
resource "aws_instance" "terraform_inst1" {
  ami = "ami-0fbc0724a0721c688"
  instance_type = "t2.micro"
  vpc_security_group_ids = [
    aws_security_group.terraform_private_sg.id]
  subnet_id = aws_subnet.main_subnet.id
  key_name = "terraform-demo"
  // create a pem key and put in the same folder
  associate_public_ip_address = true
#to run the code inside Windows Server 2019
  user_data = <<EOF
    <script>
    Enable-PsRemoting -Force
    netsh advfirewall firewall add rule name="WinRM-HTTP" dir=in localport=5985 protocol=TCP action=allow
    netsh advfirewall firewall add rule name="MySite" dir=in localport=8888 protocol=TCP action=allow
    </script>
    <persist>false</persist>
    EOF

  tags = {
    Name = "terraform_windows2019_1"
    Environment = "development"
    Project = "DEMO-TERRAFORM"
  }
}

## instance2 ##
resource "aws_instance" "terraform_inst2" {
    ami = "ami-0fbc0724a0721c688"
    instance_type = "t2.micro"
    vpc_security_group_ids =  [ aws_security_group.terraform_private_sg.id ]
    subnet_id = aws_subnet.main_subnet.id
    key_name               = "terraform-demo" // create a pem key and put in the same folder
    associate_public_ip_address = true
  #to run the code inside Windows Server 2019
  user_data = <<EOF
    <script>
    Enable-PsRemoting -Force
    netsh advfirewall firewall add rule name="WinRM-HTTP" dir=in localport=5985 protocol=TCP action=allow
    netsh advfirewall firewall add rule name="MySite" dir=in localport=8888 protocol=TCP action=allow
    </script>
    <persist>false</persist>
    EOF

    tags = {
      Name              = "terraform_windows2019_2"
      Environment       = "development"
      Project           = "DEMO-TERRAFORM"
    }
}

output "instance_id_list"     { value = [aws_instance.terraform_inst1.*.id] }

## Network Load Balancer ##
resource "aws_lb" "test" {
  name               = "test-lb-tf"
  internal           = false
  load_balancer_type = "network"
  subnets            = aws_subnet.main_subnet.*.id

  enable_deletion_protection = false

  tags = {
    Environment = "test"
  }
}

resource "aws_lb_target_group" "test" {
  name     = "tf-example-lb-tg"
  port     = 80
  protocol = "TCP"
  vpc_id   = aws_vpc.terraform-vpc.id
}

resource "aws_vpc" "testvpc" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_lb_target_group_attachment" "tgattach1" {
  target_group_arn = aws_lb_target_group.test.arn
  target_id        = aws_instance.terraform_inst1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "tgattach2" {
  target_group_arn = aws_lb_target_group.test.arn
  target_id        = aws_instance.terraform_inst2.id
  port             = 80
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn       = aws_lb.test.arn
      port                = 80
      protocol            = "TCP"
      default_action {
        target_group_arn = aws_lb_target_group.test.arn
        type             = "forward"
      }
}