# ---  EC2 INSTANCES ---
resource "aws_instance" "ec2-primary-instance" {
  ami                  = var.ami_id
  instance_type        = var.instance_type
  iam_instance_profile = aws_iam_instance_profile.ssm_profile.id
  subnet_id            = aws_subnet.primary-subnet.id
  vpc_security_group_ids = [aws_security_group.sg_vpc_primary.id]
  associate_public_ip_address = false
  tags                 = { Name = "primary-instance" }
}

resource "aws_instance" "ec2-secondary-instance" {
  ami                  = var.ami_id
  instance_type        = var.instance_type
  subnet_id            = aws_subnet.secondary-subnet.id
  iam_instance_profile = aws_iam_instance_profile.secondary_profile.name
  vpc_security_group_ids = [aws_security_group.sg_vpc_secondary.id]
  associate_public_ip_address = false
  tags                 = { Name = "secondary-instance" }
}