# --- OUTPUTS ---
output "primary_ip" { value = aws_instance.ec2-primary-instance.private_ip }
output "secondary_ip" { value = aws_instance.ec2-secondary-instance.private_ip }