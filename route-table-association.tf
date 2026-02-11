resource "aws_route_table_association" "primary-route-table-association" {
  subnet_id      = aws_subnet.primary-subnet.id
  route_table_id = aws_route_table.primary-route-table.id
}

resource "aws_route_table_association" "secondary-route-table-association" {
  subnet_id      = aws_subnet.secondary-subnet.id
  route_table_id = aws_route_table.secondary-route-table.id
}