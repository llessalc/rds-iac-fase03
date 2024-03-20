##########################################
## VPC AND SUBNETS SETUP
##################
# Here, we will create two new private subnets
# inside a existing VPC and assign them to
# the RDS instance.

data "aws_subnets" "db_subnets" {

  filter {
    name = "tag:Name"
    values = ["fiap-58-private-us-east-1a",
    "fiap-58-private-us-east-1b"]
  }
}

data "aws_subnet" "subnet" {
  for_each = toset(data.aws_subnets.db_subnets.ids)
  id       = each.value
}

data "aws_vpc" "vpc" {
  filter {
    name   = "tag:Name"
    values = ["fiap-58-vpc"]
  }
}

# Subnets creation
resource "aws_subnet" "private-a" {
  vpc_id            = data.aws_vpc.vpc.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = "us-east-1a"

  tags = {
    "Name" = "private-subnet-58-a"
  }
}

resource "aws_subnet" "private-b" {
  vpc_id            = data.aws_vpc.vpc.id
  cidr_block        = "10.0.9.0/24"
  availability_zone = "us-east-1b"

  tags = {
    "Name" = "private-subnet-58-b"
  }
}

# DB instance will be deployed in the VPC
# where those subnets are deployed. IF
# it isn't especified, then the subnet_group
# is deploy in the default VPC
resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "db-subnet-group-58"
  subnet_ids = [aws_subnet.private-a.id, aws_subnet.private-b.id]

  tags = {
    Name = "db-subnet-group"
  }
}


##########################################
## SECURITY GROUP AND INBOUND RULES
##################


resource "aws_security_group" "allow_node_group" {
  name        = "allow_node_group"
  description = "Allow inbound traffic from the EKS node group"
  vpc_id      = data.aws_vpc.vpc.id

  tags = {
    Name = "allow_node_group"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_node_group" {
  # Allow each subnet to access the RDS instance
  for_each          = data.aws_subnet.subnet
  security_group_id = aws_security_group.allow_node_group.id
  cidr_ipv4         = each.value.cidr_block
  from_port         = 3306
  ip_protocol       = "tcp"
  to_port           = 3306
}

############################################
#### DB
###############

resource "aws_db_parameter_group" "db_param_group" {
  name   = "rds-pg"
  family = "mysql8.0"

  parameter {
    apply_method = "pending-reboot"
    name         = "lower_case_table_names"
    value        = "1"
  }

}


resource "aws_db_instance" "db_instance" {
  allocated_storage     = 10 #GB
  max_allocated_storage = 20
  db_name               = "mydb"
  engine                = "mysql"
  engine_version        = "8.0"
  instance_class        = "db.t3.micro"
  # username              = var.username
  # password              = var.password
  parameter_group_name  = aws_db_parameter_group.db_param_group.name
  skip_final_snapshot   = true
  publicly_accessible   = false
  apply_immediately     = true

  # Assign this instance to a specific VPC
  db_subnet_group_name = aws_db_subnet_group.db_subnet_group.name

  # Assign group with the correct inbound rules
  vpc_security_group_ids = [aws_security_group.allow_node_group.id]

  depends_on = [aws_security_group.allow_node_group, aws_db_subnet_group.db_subnet_group]
}
