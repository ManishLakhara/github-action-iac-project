# create an VPC
resource "aws_vpc" "main" {
cidr_block = "10.0.0.0/16"
instance_tenancy = "default"
  tags = {
  Name = "github-action-cicd-vpc"
  }
}

# Create an public subnet
resource "aws_subnet" "public" {
 vpc_id = aws_vpc.main.id
 cidr_block = "10.0.1.0/24"
 map_public_ip_on_launch = true
 tags = {
   Name = "public-subnet"
 }
}

# Create an Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "github-action-cicd-igw"
  }
}

# Create a route table for public subnet
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "public-route-table"
  }
}

# Add default route to Internet Gateway
resource "aws_route" "default_route" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

# Associate route table with public subnet
resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public_rt.id
}