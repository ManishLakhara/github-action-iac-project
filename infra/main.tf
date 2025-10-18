# Create a security group allowing HTTP (port 80)
resource "aws_security_group" "http_sg" {
  name        = "allow_http"
  description = "Allow HTTP inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP inbound traffic"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create security group allowing SSH (port 22)
resource "aws_security_group" "ssh_sg" {
  name        = "allow_ssh"
  description = "Allow SSH inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow SSH inbound traffic"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
# Create aws instance profile role
data "aws_iam_policy_document" "instance_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}
resource "aws_iam_role" "ec2_profile_role" {
  name = "ec2_instance_profile_role"
  assume_role_policy = data.aws_iam_policy_document.instance_assume_role_policy.json
}
resource "aws_iam_instance_profile" "ec2_profile_role_attach" {
  name = "ec2_instance_profile"
  role = aws_iam_role.ec2_profile_role.name
}

resource "aws_iam_role_policy_attachment" "ssm_access_attachment" {
  role = aws_iam_role.ec2_profile_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cloudwatch_full_access" {
  role = aws_iam_role.ec2_profile_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchFullAccess"
}
# Launch EC2 instance
resource "aws_instance" "web" {
  ami                    = var.instance_ami
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.http_sg.id, aws_security_group.ssh_sg.id]
  subnet_id              = aws_subnet.public.id
  key_name = "github-action-cicd"
  associate_public_ip_address = true
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile_role_attach.name
  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install docker -y
              systemctl start docker
              systemctl enable docker
              usermod -aG docker ec2-user

              # Install CloudWatch Agent
              yum install amazon-cloudwatch-agent -y

              # Create CloudWatch Agent config
              cat > /opt/aws/amazon-cloudwatch-agent/bin/config.json << CWAGENTCONFIG
              {
                "agent": {
                  "metrics_collection_interval": 60,
                  "run_as_user": "root"
                },
                "metrics": {
                  "metrics_collected": {
                    "disk": {
                      "measurement": ["free", "used", "total"],
                      "metrics_collection_interval": 60,
                      "resources": ["/"]
                    },
                    "mem": {
                      "measurement": ["mem_used_percent", "mem_available_percent"],
                      "metrics_collection_interval": 60
                    }
                  }
                }
              }
              CWAGENTCONFIG

              # Start CloudWatch Agent
              /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
                -a fetch-config \
                -m ec2 \
                -c file:/opt/aws/amazon-cloudwatch-agent/bin/config.json \
                -s
              EOF
  tags = {
    Name = "github-action-iac-ec2"
  }
}
