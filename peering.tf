# --- 3. PEERING & ROUTING ---
resource "aws_vpc_peering_connection" "vpc-peering" {
  vpc_id      = aws_vpc.primary-vpc.id
  peer_vpc_id = aws_vpc.secondary-vpc.id
  auto_accept = true
  tags        = { Name = "primary-to-secondary-peering" }
}

resource "aws_vpc_peering_connection_options" "vpc-peering-options" {
  vpc_peering_connection_id = aws_vpc_peering_connection.vpc-peering.id
  accepter  { allow_remote_vpc_dns_resolution = true }
  requester { allow_remote_vpc_dns_resolution = true }
}