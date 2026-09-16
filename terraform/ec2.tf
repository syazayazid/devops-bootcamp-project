data "aws_ami" "my_ami" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}

data "aws_iam_instance_profile" "my_ssm_profile" {
  name = "EC2-SSM-Role"
}

data "aws_ssm_parameter" "token" {
  name = "/devops-bootcamp-2026/tunnel-token"
}


module "web_server" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 6.0"

  name                   = "web_server"
  ami                    = data.aws_ami.my_ami.id
  instance_type          = "t3.micro"
  subnet_id              = module.my_vpc.public_subnets[0]
  create_security_group  = false
  vpc_security_group_ids = [module.devops-public_sg.id]
  iam_instance_profile   = data.aws_iam_instance_profile.my_ssm_profile.name
  private_ip             = "10.0.0.5"
  key_name               = "Bootcamp"
  tags                   = { Name = "web_server" }
  root_block_device      = { size = 16 }
}

module "monitoring_server" {
  source                 = "terraform-aws-modules/ec2-instance/aws"
  version                = "~> 6.0"
  name                   = "monitoring_server"
  ami                    = data.aws_ami.my_ami.id
  instance_type          = "t3.small"
  subnet_id              = module.my_vpc.private_subnets[0]
  create_security_group  = false
  vpc_security_group_ids = [module.devops-private_sg.id]
  iam_instance_profile   = data.aws_iam_instance_profile.my_ssm_profile.name
  private_ip             = "10.0.0.136"
  key_name               = "Bootcamp"
  tags                   = { Name = "monitoring_server" }
  root_block_device      = { size = 16 }
}

module "controller_server" {
  source                 = "terraform-aws-modules/ec2-instance/aws"
  version                = "~> 6.0"
  name                   = "controller_server"
  ami                    = data.aws_ami.my_ami.id
  instance_type          = "t3.micro"
  subnet_id              = module.my_vpc.private_subnets[0]
  create_security_group  = false
  vpc_security_group_ids = [module.devops-private_sg.id]
  iam_instance_profile   = data.aws_iam_instance_profile.my_ssm_profile.name
  private_ip             = "10.0.0.135"
  key_name               = "Bootcamp"
  tags                   = { Name = "controller_server" }
  root_block_device      = { size = 16 }
}
