terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }

  required_version = ">= 0.14.9"
}

provider "aws" {
  region = var.region
}

# =========================================
#                   S3
# =========================================
# ----- Create a S3 Buchet -----
resource "aws_s3_bucket" "image-bucket" {
  bucket        = "${var.bucket_name}"
  force_destroy = true
}

# =========================================
#                    RDS
# =========================================
# ----- Add Security Group for RDS -----
resource "aws_security_group" "ss_db_sg" {
  name = "Security Group for social something db"

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ----- Create a RDS Instance -----
resource "aws_db_instance" "ss_db" {
  allocated_storage      = 20
  engine                 = "mysql"
  engine_version         = "8.0.23"
  instance_class         = "db.t2.micro"
  username               = "admin"
  password               = var.database_admin_password
  skip_final_snapshot    = true
  publicly_accessible    = true
  vpc_security_group_ids = [aws_security_group.ss_db_sg.id]
}

# =========================================
#               EC2 (node app) 
# =========================================
# ----- Add Security Group for Node App -----
resource "aws_security_group" "ss_app_sg" {
  name = "Security Group for social something node app"

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["172.31.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ----- Add an IAM Policy for Node App -----
resource "aws_iam_policy" "ss_ec2_policy" {
  name        = "ss_ec2_policy"
  path        = "/"
  description = "My policy for social something ec2"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "VisualEditor0",
        "Effect" : "Allow",
        "Action" : [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject"
        ],
        "Resource" : [
          "arn:aws:s3:::*/*",
          "arn:aws:s3:::${var.bucket_name}"
        ]
      }
    ]
  })
}

# ----- Add an IAM Role for Node App -----
resource "aws_iam_role" "iam_role_ss_app" {
  name = "iam_role_ss_app"

  # This is a role for EC2 instances
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

# ----- Add a Profile -----
resource "aws_iam_instance_profile" "ss_instance_profile" {
  name = "ss_instance_profile"
  role = aws_iam_role.iam_role_ss_app.name
}

# ----- IAM role Policy Attachment -----
resource "aws_iam_role_policy_attachment" "ss_ec2_policy_attachment" {
  role       = aws_iam_role.iam_role_ss_app.name
  policy_arn = aws_iam_policy.ss_ec2_policy.arn
}

# ----- Find the AMI to Use -----
data "aws_ami" "app_ami" {
  most_recent = true
  name_regex = "social_something-app-*"
  owners    = ["self"]
}

# ----- Cloud Init -----
data "cloudinit_config" "app_config" {
  gzip          = true
  base64_encode = true
  part {
    content_type = "text/cloud-config"
    content = templatefile("${path.module}/app.yml", {
      region : var.region,
      bucket_name : var.bucket_name
      rds_endpoint: split(":", aws_db_instance.ss_db.endpoint)[0]
    })
  }
}

# ----- Create 3 Instances -----
resource "aws_instance" "web_app" {
  instance_type               = "t2.micro"
  ami                         = data.aws_ami.app_ami.id
  vpc_security_group_ids      = [aws_security_group.ss_app_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.ss_instance_profile.name
  associate_public_ip_address = false
  user_data                   = data.cloudinit_config.app_config.rendered
  count                       = 3
}


# =========================================
#                EC2 (lb) 
# =========================================
# ----- Add Security Group for LB -----
resource "aws_security_group" "ss_lb_sg" {
  name = "Security Group for social something LB"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ----- Find the AMI for LB -----
data "aws_ami" "lb_ami" {
  most_recent = true
  name_regex = "ss-lb-*"
  owners    = ["self"]
}

# ----- Cloud Init -----
data "cloudinit_config" "lb_config" {
  gzip          = true
  base64_encode = true
  part {
    content_type = "text/cloud-config"
    content = templatefile("${path.module}/lb.yml", {
      ips : join("\n", [for i in aws_instance.web_app : "server ${i.private_ip}:8080;"])
    })
  }
}

# ----- Create an Instance for LB -----
resource "aws_instance" "ss_lb" {
  instance_type               = "t2.micro"
  ami                         = data.aws_ami.lb_ami.id
  vpc_security_group_ids      = [aws_security_group.ss_lb_sg.id]
  associate_public_ip_address = false
  user_data                   = data.cloudinit_config.lb_config.rendered
}

