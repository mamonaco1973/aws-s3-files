# ================================================================================
# FILE: networking.tf
#
# Purpose:
#   - Defines the network baseline for the mini-ad lab environment.
#   - Creates a VPC with public and private subnets.
#   - Enables internet egress for private instances via a NAT Gateway.
#
# Scope:
#   - VPC, subnets, IGW, NAT Gateway, route tables, and associations.
#
# Notes:
#   - CIDRs and AZs are examples; align to your region and IP plan.
#   - NAT Gateway must reside in a public subnet with a route to the IGW.
# ================================================================================

# ================================================================================
# RESOURCE: aws_vpc.ad-vpc
# ================================================================================
resource "aws_vpc" "ad-vpc" {
  cidr_block           = "10.0.0.0/24"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = var.vpc_name }
}

# ================================================================================
# RESOURCE: aws_internet_gateway.ad-igw
# ================================================================================
# Purpose:
#   - Provides internet egress for public subnets in the VPC.
# ================================================================================
resource "aws_internet_gateway" "ad-igw" {
  vpc_id = aws_vpc.ad-vpc.id
  tags   = { Name = "ad-igw" }
}

# ================================================================================
# SUBNETS
# ================================================================================
# Notes:
#   - Public subnets: utility/bastion hosts with direct IGW routing.
#   - Private subnet: AD/DC hosts with outbound-only routing via NAT.
# ================================================================================

# ------------------------------------------------------------------------------
# RESOURCE: aws_subnet.vm-subnet-1
# ------------------------------------------------------------------------------
resource "aws_subnet" "vm-subnet-1" {
  vpc_id                  = aws_vpc.ad-vpc.id
  cidr_block              = "10.0.0.64/26"
  map_public_ip_on_launch = true
  availability_zone_id    = "use1-az6"

  tags = { Name = "vm-subnet-1" }
}

# ------------------------------------------------------------------------------
# RESOURCE: aws_subnet.vm-subnet-2
# ------------------------------------------------------------------------------
# Optional second public subnet for HA / additional utility hosts.
# ------------------------------------------------------------------------------
# resource "aws_subnet" "vm-subnet-2" {
#   vpc_id                  = aws_vpc.ad-vpc.id
#   cidr_block              = "10.0.0.128/26"
#   map_public_ip_on_launch = true
#   availability_zone_id    = "use1-az4"
#
#   tags = { Name = "vm-subnet-2" }
# }

# ------------------------------------------------------------------------------
# RESOURCE: aws_subnet.ad-subnet
# ------------------------------------------------------------------------------
resource "aws_subnet" "ad-subnet" {
  vpc_id                  = aws_vpc.ad-vpc.id
  cidr_block              = "10.0.0.0/26"
  map_public_ip_on_launch = false
  availability_zone_id    = "use1-az4"

  tags = { Name = "ad-subnet" }
}

# ================================================================================
# RESOURCE: aws_eip.nat_eip
# ================================================================================
# Purpose:
#   - Provides a stable public IP for the NAT Gateway.
# ================================================================================
resource "aws_eip" "nat_eip" {
  tags = { Name = "nat-eip" }
}

# ================================================================================
# RESOURCE: aws_nat_gateway.ad_nat
# ================================================================================
# Purpose:
#   - Provides outbound internet access for private subnets without inbound
#     exposure.
#
# Notes:
#   - NAT Gateways must be placed in a public subnet.
# ================================================================================
resource "aws_nat_gateway" "ad_nat" {
  subnet_id     = aws_subnet.vm-subnet-1.id
  allocation_id = aws_eip.nat_eip.id

  tags = { Name = "ad-nat" }
}

# # ================================================================================
# # RESOURCE: time_sleep.wait_for_nat
# # ================================================================================
# # Purpose:
# #   - Forces a fixed stabilization delay after NAT Gateway creation.
# #
# # Notes:
# #   - AWS reports NAT as "available" before it is fully routable.
# #   - This avoids race conditions with route tables and instances.
# # ================================================================================
# resource "time_sleep" "wait_for_nat" {
#   depends_on = [aws_nat_gateway.ad_nat]
#   create_duration = "120s"
# }

# ================================================================================
# ROUTE TABLES
# ================================================================================

# ------------------------------------------------------------------------------
# RESOURCE: aws_route_table.public
# ------------------------------------------------------------------------------
# Purpose:
#   - Routes public subnet traffic to the Internet Gateway.
# ------------------------------------------------------------------------------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.ad-vpc.id
  tags   = { Name = "public-route-table" }
}

# ------------------------------------------------------------------------------
# RESOURCE: aws_route.public_default
# ------------------------------------------------------------------------------
resource "aws_route" "public_default" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.ad-igw.id
}

# ------------------------------------------------------------------------------
# RESOURCE: aws_route_table.private
# ------------------------------------------------------------------------------
# Purpose:
#   - Routes private subnet traffic to the NAT Gateway for outbound egress.
# ------------------------------------------------------------------------------
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.ad-vpc.id
  tags   = { Name = "private-route-table" }
}

# ------------------------------------------------------------------------------
# RESOURCE: aws_route.private_default
# ------------------------------------------------------------------------------
resource "aws_route" "private_default" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.ad_nat.id
}

# ================================================================================
# ROUTE TABLE ASSOCIATIONS
# ================================================================================

# ------------------------------------------------------------------------------
# RESOURCE: aws_route_table_association.rt_assoc_vm_public
# ------------------------------------------------------------------------------
resource "aws_route_table_association" "rt_assoc_vm_public" {
  subnet_id      = aws_subnet.vm-subnet-1.id
  route_table_id = aws_route_table.public.id
}

# ------------------------------------------------------------------------------
# RESOURCE: aws_route_table_association.rt_assoc_vm_public_2
# ------------------------------------------------------------------------------
# Optional association for vm-subnet-2 when enabled.
# ------------------------------------------------------------------------------
# resource "aws_route_table_association" "rt_assoc_vm_public_2" {
#   subnet_id      = aws_subnet.vm-subnet-2.id
#   route_table_id = aws_route_table.public.id
# }

# ------------------------------------------------------------------------------
# RESOURCE: aws_route_table_association.rt_assoc_ad_private
# ------------------------------------------------------------------------------
resource "aws_route_table_association" "rt_assoc_ad_private" {
  subnet_id      = aws_subnet.ad-subnet.id
  route_table_id = aws_route_table.private.id
}
