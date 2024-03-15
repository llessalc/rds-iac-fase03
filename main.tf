##########################################
## VPC SETUP
##################

data "aws_subnets" "db_subnets" {

  filter {
    name   = "tag:Name"
    values = ["chosen"]
  }
}

data "aws_vpc" "vpc" {
  filter {
    name   = "tag:Name"
    values = ["default"]
  }
}

# DB instance will be deployed in the VPC
# where those subnets are deployed. IF
# it isn't especified, then the subnet_group
# is deploy in the default VPC
resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "db-subnet-group-58"
  subnet_ids = data.aws_subnets.db_subnets.ids

  tags = {
    Name = "db-subnet-group"
  }
}


##########################################
## SECURITY GROUP AND INBOUND RULES
##################

data "aws_subnet" "ec2_sub" {
  filter {
    name   = "tag:Name"
    values = ["ec2_sub"]
  }
}

resource "aws_security_group" "allow_node_group" {
  name        = "allow_node_group"
  description = "Allow inbound traffic from the EKS node group"
  vpc_id      = data.aws_vpc.vpc.id

  tags = {
    Name = "allow_node_group"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_node_group" {
  security_group_id = aws_security_group.allow_node_group.id
  cidr_ipv4         = data.aws_subnet.ec2_sub.cidr_block
  from_port         = 3306
  ip_protocol       = "tcp"
  to_port           = 3306
}

############################################
#### DB
###############


resource "aws_db_instance" "db_instance" {
  allocated_storage     = 10 #GB
  max_allocated_storage = 20
  db_name               = "mydb"
  engine                = "mysql"
  engine_version        = "5.7"
  instance_class        = "db.t3.micro"
  username              = var.username
  password              = var.password
  parameter_group_name  = "default.mysql5.7"
  skip_final_snapshot   = true
  publicly_accessible   = false

  # Assign this instance to a specific VPC
  db_subnet_group_name = aws_db_subnet_group.db_subnet_group.name

  # Assing group with the correct inbound rules
  vpc_security_group_ids = [aws_security_group.allow_node_group.id]
}
