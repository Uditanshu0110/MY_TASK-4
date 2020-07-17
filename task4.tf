provider "aws" {
  region     = "ap-south-1"
  profile    = "default"
}

resource "tls_private_key" "UDIT" {
    algorithm = "RSA"
}


resource "local_file" "private_key" {
    content         =   tls_private_key.UDIT.private_key_pem
    filename        =   "mykey1.pem"
}


resource "aws_key_pair" "mykey1" {
    key_name   = "mykey1"
    public_key = tls_private_key.UDIT.public_key_openssh
}



resource "aws_vpc" "MyFirstVPC" {
  cidr_block       = "192.168.0.0/16"
  instance_tenancy = "default"
  enable_dns_hostnames = "true"
  tags = {
    Name = "MyFirstVPC"
  }
}
resource "aws_subnet" "publicsubnet" {
  vpc_id     = aws_vpc.MyFirstVPC.id
  cidr_block = "192.168.0.0/24"
  availability_zone = "ap-south-1a"
  map_public_ip_on_launch = "true"
tags = {
    Name = "publicsubnet"
  }
}
resource "aws_subnet" "privatesubnet" {
  vpc_id     = aws_vpc.MyFirstVPC.id
  cidr_block = "192.168.1.0/24"
  availability_zone = "ap-south-1b"
tags = {
    Name = "privatesubnet"
  }
}
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.MyFirstVPC.id
tags = {
    Name = "gw"
  }
}
resource "aws_eip" "myeip" {
  depends_on = [ aws_instance.wordpress_os , aws_instance.mysql_database , aws_instance.bastion_host ]
   vpc      = true
}
resource "aws_nat_gateway" "nat_gateway" {
  depends_on = [ aws_eip.myeip]
  allocation_id = aws_eip.myeip.id
  subnet_id     = aws_subnet.publicsubnet.id
tags = {
    Name = "my_Nat_gateway"
  }
}
resource "aws_route_table" "routetable" {
  vpc_id = aws_vpc.MyFirstVPC.id
route {
    
gateway_id = aws_internet_gateway.gw.id
    cidr_block = "0.0.0.0/0"
  }
tags = {
    Name = "my_rt2"
  }
}
resource "aws_route_table_association" "association" {
  subnet_id      = aws_subnet.publicsubnet.id
  route_table_id = aws_route_table.routetable.id
}
resource "aws_route_table" "nat_route_table" {
  depends_on = [ aws_nat_gateway.nat_gateway ]
  vpc_id = aws_vpc.MyFirstVPC.id
  route {    
    gateway_id = aws_nat_gateway.nat_gateway.id
    cidr_block = "0.0.0.0/0"
  }
    tags = {
    Name = "my_nat_route_table"
  }
}
resource "aws_route_table_association" "association1" {
  depends_on = [ aws_route_table.nat_route_table ]
  subnet_id      = aws_subnet.privatesubnet.id
  route_table_id = aws_route_table.nat_route_table.id
}
resource "aws_security_group" "Security_Guard_mysql" {
  depends_on = [ aws_vpc.MyFirstVPC ]
  name        = "Security_Guard_mysql"
  vpc_id      = aws_vpc.MyFirstVPC.id
ingress {
    description = "MYSQL"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    security_groups = [ aws_security_group.Security_Guard_wp.id ]
  }
egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
tags = {
    Name = "mysql_sg"
  }
}
resource "aws_security_group" "Security_Guard_Bastion" {
  depends_on = [ aws_vpc.MyFirstVPC ]
  name        = "Security_Guard_Bastion"
  vpc_id      = aws_vpc.MyFirstVPC.id
ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [ "0.0.0.0/0"]
  }
egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
tags = {
    Name = "bh_sg"
  }
}
resource "aws_security_group" "Security_Guard_wp" {
  depends_on = [ aws_vpc.MyFirstVPC ]
  name        = "Security_Guard_wp"
  vpc_id      = aws_vpc.MyFirstVPC.id
ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [ "0.0.0.0/0"]
  }
ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
ingress {
      description = "ICMP"  
      from_port = -1
      to_port = -1
      protocol = "icmp"
      cidr_blocks = ["0.0.0.0/0"]
    }
egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
tags = {
    Name = "wpos_sg"
  }
}
resource "aws_instance" "wordpress_os" {
  ami           = "ami-7e257211"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.publicsubnet.id
  vpc_security_group_ids = [ aws_security_group.Security_Guard_wp.id ]
  key_name  =  aws_key_pair.mykey1.key_name
  tags = {
    Name = "WordPress"
    }
}

resource "aws_instance" "mysql_database" {
  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.privatesubnet.id
  vpc_security_group_ids = [ aws_security_group.Security_Guard_mysql.id , aws_security_group.Security_Guard_Bastion.id ]
  key_name  =  aws_key_pair.mykey1.key_name
tags = {
    Name = "MySQL"
    }
}

resource "aws_instance" "bastion_host" {
  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.publicsubnet.id
  vpc_security_group_ids = [ aws_security_group.Security_Guard_Bastion.id ]
  key_name  =  aws_key_pair.mykey1.key_name
  
    tags = {
    Name = "BastionHostOS"
    }
}




