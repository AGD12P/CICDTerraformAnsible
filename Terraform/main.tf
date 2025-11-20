terraform {
  backend "s3" {
    bucket = "alfs3git-20112025"
    key = "terraform.tfstate"
    region = "us-east-1"
    encrypt = true
    
  }
}



resource "aws_vpc" "alf_vpc" {
    cidr_block = "10.0.0.0/16"
    enable_dns_support = true
    enable_dns_hostnames = true
    tags = {
        Name = "AlfonsoTerraformVPC"
    }
}

#Primera subnet para ALB
resource "aws_subnet" "public_subnet_1" {
    vpc_id = aws_vpc.alf_vpc.id
    cidr_block = "10.0.0.0/24"
    availability_zone = "us-east-1a"
    map_public_ip_on_launch = true
}

#Segunda subnet para ALB
resource "aws_subnet" "public_subnet_2" {
    vpc_id = aws_vpc.alf_vpc.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "us-east-1b"
    map_public_ip_on_launch = true
}

#Primera subnet privada
resource "aws_subnet" "private_subnet_1" {
    vpc_id = aws_vpc.alf_vpc.id
    cidr_block = "10.0.2.0/24"
    availability_zone = "us-east-1a"
    map_public_ip_on_launch = false
}

#Segunda subnet privada
resource "aws_subnet" "private_subnet_2" {
    vpc_id = aws_vpc.alf_vpc.id
    cidr_block = "10.0.3.0/24"
    availability_zone = "us-east-1b"
    map_public_ip_on_launch = false
}

resource "aws_internet_gateway" "alf_igw" {
    vpc_id = aws_vpc.alf_vpc.id
}

resource "aws_route_table" "alf_public_rt" {
    vpc_id = aws_vpc.alf_vpc.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.alf_igw.id
    }  
}

resource "aws_route_table_association" "public_subnet_1_association" {
    subnet_id = aws_subnet.public_subnet_1.id
    route_table_id = aws_route_table.alf_public_rt.id
}

resource "aws_route_table_association" "public_subnet_2_association" {
    subnet_id = aws_subnet.public_subnet_2.id
    route_table_id = aws_route_table.alf_public_rt.id
}

#To make the system more robust im making 2 nat gateway, 1 in each zone

resource "aws_eip" "nat_eip_1" {
    domain = "vpc"
}

resource "aws_eip" "nat_eip_2" {
    domain = "vpc"
}

resource "aws_nat_gateway" "alf_nat_gw_1" {
    allocation_id = aws_eip.nat_eip_1.id
    subnet_id = aws_subnet.public_subnet_1.id
}

resource "aws_nat_gateway" "alf_nat_gw_2" {
    allocation_id = aws_eip.nat_eip_2.id
    subnet_id = aws_subnet.public_subnet_2.id
}


resource "aws_route_table" "alf_private_rt_1"{
    vpc_id = aws_vpc.alf_vpc.id
}

resource "aws_route_table" "alf_private_rt_2"{
    vpc_id = aws_vpc.alf_vpc.id
}

resource "aws_route" "private_subnet_1_nat_route" {
    route_table_id = aws_route_table.alf_private_rt_1.id
    destination_cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.alf_nat_gw_1.id
}

resource "aws_route" "private_subnet_2_nat_route" {
    route_table_id = aws_route_table.alf_private_rt_2.id
    destination_cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.alf_nat_gw_2.id
}


resource "aws_route_table_association" "private_subnet_1_association" {
    subnet_id = aws_subnet.private_subnet_1.id
    route_table_id = aws_route_table.alf_private_rt_1.id
}

resource "aws_route_table_association" "private_subnet_2_association" {
    subnet_id = aws_subnet.private_subnet_2.id
    route_table_id = aws_route_table.alf_private_rt_2.id
}

resource "aws_security_group" "alf_alb_sg" {
    #name = "Alf_ALB_SG"
    description = "Security group for ALB"
    vpc_id = aws_vpc.alf_vpc.id

    ingress {
        description = "HTTP"
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        description = "HTTPS"
        from_port = 443
        to_port = 443
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
    tags = {
      Name = "Alf_ALB_SG"
    }
}

resource "aws_security_group" "alf_ec2_sg" {
    #name = "Alf_EC2_SG"
    description = "Security group for EC2 instances"
    vpc_id = aws_vpc.alf_vpc.id

    ingress {
        description = "HTTP desde ALB"
        from_port = 80
        to_port = 80
        protocol = "tcp"
        security_groups = [aws_security_group.alf_alb_sg.id]
    }
    ingress {
        description = "HTTPS desde ALB"
        from_port = 443
        to_port = 443
        protocol = "tcp"
        security_groups = [aws_security_group.alf_alb_sg.id]
    }
    ingress {
        description = "SSH"
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
        description = "Salida"
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
    tags = {
      Name = "Alf_EC2_SG"
    }
}

resource "aws_lb" "alf_alb" {
    name = "alf-alb"
    internal = false
    load_balancer_type = "application"
    security_groups = [aws_security_group.alf_alb_sg.id]
    subnets = [aws_subnet.public_subnet_1.id,aws_subnet.public_subnet_2.id]
    enable_deletion_protection = false
    enable_cross_zone_load_balancing = true

    tags = {
        Name = "Alf_ALB"
    }
}

resource "aws_lb_target_group" "alf_web_target_group_1" {
    name = "alf-web-tg-1"
    port = 80
    protocol = "HTTP"
    vpc_id = aws_vpc.alf_vpc.id

      health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 2
  }
}

#resource "aws_lb_target_group" "alf_web_target_group_2" {
#    name = "alf-web-tg-2"
#    port = 80
#    protocol = "HTTP"
#    vpc_id = aws_vpc.alf_vpc.id
#}

resource "aws_lb_listener" "alf_http_listener" {
    load_balancer_arn = aws_lb.alf_alb.arn
    port = 80
    protocol = "HTTP"

    #default_action {
    #  type = "fixed-response"
    #  fixed_response {
    #    status_code = 200
    #    content_type = "text/plain"
    #    message_body = "ALB HTTP is working"
    #  }
    #}
    default_action {
      type = "forward"
      forward {
        target_group {
          arn = aws_lb_target_group.alf_web_target_group_1.arn
          weight = 1
        }
        #target_group {
        #  arn = aws_lb_target_group.alf_web_target_group_2.arn
        #  weight = 1
        #}
      }
    }
}

#resource "aws_lb_listener" "alf_https_listener" {
#    load_balancer_arn = aws_lb.alf_alb.arn
#    port = 443
#    protocol = "HTTPS"
#    ssl_policy = "ELBSecurityPolicy-2016-08"
#    certificate_arn = "arn:aws:acm:region:account-id:certificate/certificate-id" # Replace with your certificate ARN ¿?
#    
#    default_action {
#      type = "fixed-response"
#      fixed_response {
#        status_code = 200
#        content_type = "text/plain"
#        message_body = "ALB HTTPS is working"
#      }
#    }
#}

resource "aws_launch_template" "alf_launch_template" {
    name_prefix = "alf-launch-template"
    image_id = "ami-0ecb62995f68bb549"
    instance_type = "t3.micro"

    #vpc_security_group_ids = [aws_security_group.alf_ec2_sg.id]
    #key_name = aws_key_pair.alf_key_pair.key_name
    key_name = "alf-key-ssh"
    network_interfaces {
      security_groups = [aws_security_group.alf_ec2_sg.id]
      associate_public_ip_address = true
    }
    lifecycle {
      create_before_destroy = true
    }
    
    tag_specifications {
      resource_type = "instance"

      tags = {
        Name = "Alf_instance"
        role = "alfec2"
      }
    }
    #user_data = base64encode(<<EOF
##!/bin/bash
#apt-get update -y
#apt-get install -y apache2
#systemctl enable apache2
#systemctl start apache2
#echo "Hello from AGD" > /var/www/html/index.html
#EOF
#    )
}

resource "aws_autoscaling_group" "alf_autoscaling" {
    min_size = 2
    max_size = 4
    vpc_zone_identifier = [aws_subnet.public_subnet_1.id,aws_subnet.public_subnet_2.id]
    launch_template {
      id = aws_launch_template.alf_launch_template.id
    }

    target_group_arns = [
        aws_lb_target_group.alf_web_target_group_1.arn
    ]
    #aws_lb_target_group.alf_web_target_group_2.arn,
    health_check_type = "EC2"
    health_check_grace_period = 300

    force_delete = true #Delete EC2s when ASG is deleted

    tag {
      key = "Name" #
      value = "AlfInstance"
      propagate_at_launch = true
    }
}

resource "aws_db_subnet_group" "alf_rds_subnet_group" {
    name = "alf-rds-subnet-group"
    subnet_ids = [aws_subnet.private_subnet_1.id,aws_subnet.private_subnet_2.id]

    tags = {
        Name = "Alf_RDS_Subnet_Group"
    }
}

resource "aws_security_group" "alf_RDS_SG" {
    #name = "Alf_RDS_SG"
    description = "Security group for RDS"
    vpc_id = aws_vpc.alf_vpc.id

    ingress {
        description = "5432 desde EC2"
        from_port = 5432
        to_port = 5432
        protocol = "tcp"
        security_groups = [aws_security_group.alf_ec2_sg.id]
    }
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
    tags = {
      Name = "Alf_RDS_SG"
    }
}
resource "aws_db_instance" "alf_rds_postgresql" {
    identifier = "alf-rds-postgresql"
    engine = "postgres"
    #engine_version = "13.4"
    instance_class = "db.t3.micro"
    allocated_storage = 20
    db_subnet_group_name = aws_db_subnet_group.alf_rds_subnet_group.name

    multi_az = true
    storage_type = "gp2"

    username = "masteruser" #
    password = "password" #
    db_name = "alf_db"

    port = 5432

    vpc_security_group_ids = [aws_security_group.alf_RDS_SG.id]

    tags = {
        Name = "Alf_RDS_PostgreSQL"
    }
    skip_final_snapshot = true
    #final_snapshot_identifier = "alf-rds-postgresql-final-snapshot-3"
}

#resource "aws_key_pair" "alf_key_pair" {
#    key_name = "alf-key-ssh"
#    public_key = file("./alf-key-shh.pub")
#    
#}

