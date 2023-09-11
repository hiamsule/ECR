/*This terraform file creates a Jenkins Server using JDK 11 on EC2 Instance.
  Jenkins Server is enabled with Git, Docker and Docker Compose,
  AWS CLI Version 2. Jenkins Server will run on Amazon Linux 2023 EC2 Instance with
  custom security group allowing HTTP(80, 8080) and SSH (22) connections from anywhere. 
*/

provider "aws" {
  region = "us-east-1"
  //  access_key = ""
  //  secret_key = ""
  //  If you have entered your credentials in AWS CLI before, you do not need to use these arguments.
}

provider "github" {
  token = local.github-token
}

data "aws_caller_identity" "current" {}

locals {
  github-email    = "oliver@clarusway.com"     # you need to change this line
  github-username = "clarusway"                # you need to change this line
  github-token    = "xxxxxxxxx"                # you need to change this line
  key_pair        = "clarus"                   # you need to change this line
  instance_type   = "t3a.medium"
  user            = "clarusway"
}

resource "github_repository" "githubrepo" {
  name       = "todo-app-node-project"
  visibility = "private"
}

variable "sg-ports" {
  default = [80, 22, 8080]
}

resource "aws_security_group" "ec2-sec-gr" {
  name = "jenkins-sec-gr-${local.user}"
  tags = {
    Name = "jenkins-sec-gr"
  }
  dynamic "ingress" {
    for_each = var.sg-ports
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
  egress {
    from_port   = 0
    protocol    = "-1"
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role" "roleforjenkins" {
  name                = "ecr_jenkins_permission_${local.user}"
  managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess", "arn:aws:iam::aws:policy/AdministratorAccess", "arn:aws:iam::aws:policy/AmazonECS_FullAccess"]
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

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "jenkinsprofile-${local.user}"
  role = aws_iam_role.roleforjenkins.name
}

data "aws_ami" "al2023" {
  most_recent      = true
  owners           = ["amazon"]

  filter {
    name = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name = "name"
    values = ["al2023-ami-2023*"]
  }
  filter {
    name = "architecture"
    values = ["x86_64"]
  }
}

resource "aws_instance" "jenkins-server" {
  ami           = data.aws_ami.al2023.id
  instance_type = local.instance_type
  key_name      = local.key_pair
  root_block_device {
    volume_size = 16
  }
  vpc_security_group_ids = [aws_security_group.ec2-sec-gr.id]
  tags = {
    Name = "Jenkins-Server-${local.user}"
  }
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name
  user_data            = templatefile("userdata.sh", {github_username = local.github-username,  user-data-git-token = local.github-token, git-repo-name = github_repository.githubrepo.name, github_email = local.github-email})
  }

output "jenkins-dns-url" {
  value = "http://${aws_instance.jenkins-server.public_ip}:8080"
}

output "ssh-connection" {
  value = "ssh -i ${local.key_pair}.pem ec2-user@${aws_instance.jenkins-server.public_ip}"
}

output "nodejs-url" {
  value = "http://${aws_instance.jenkins-server.public_ip}"
}

output "github-url" {
  value = github_repository.githubrepo.http_clone_url
}

output "aws-account-id" {
  value = data.aws_caller_identity.current.account_id
}