
locals {
  zone_count         = 3
  vpc_zone_names     = [ for index in range(var._count): "${var.region}-${(index % local.zone_count) + 1}" ]
  gateway_count      = min(length(var.gateways), local.zone_count)
  ipv4_cidr_provided = length(var.ipv4_cidr_blocks) >= var._count
  ipv4_cidr_block    = local.ipv4_cidr_provided ? var.ipv4_cidr_blocks : [ for index in range(var._count): "" ]
  ipv4_address_count = local.ipv4_cidr_provided ? "" : var.ipv4_address_count
  subnets            = local.ipv4_cidr_provided ? ibm_is_subnet.vpc_subnet_cidr_block : ibm_is_subnet.vpc_subnet_total_count
}

resource null_resource print_names {
  provisioner "local-exec" {
    command = "echo 'Resource group: ${var.resource_group_id}'"
  }
  provisioner "local-exec" {
    command = "echo 'VPC name: ${var.vpc_name}'"
  }
  provisioner "local-exec" {
    command = "echo 'IPv4 address count: ${local.ipv4_address_count}'"
  }
  provisioner "local-exec" {
    command = "echo 'IPv4 cidr blocks: ${jsonencode(local.ipv4_cidr_block)}'"
  }
}

data ibm_is_vpc vpc {
  depends_on = [null_resource.print_names]

  name  = var.vpc_name
}

resource ibm_is_subnet vpc_subnet_cidr_block {
  count                    = local.ipv4_cidr_provided ? var._count : 0

  name                     = "${var.vpc_name}-subnet-${var.label}${format("%02s", count.index)}"
  zone                     = local.vpc_zone_names[count.index]
  vpc                      = data.ibm_is_vpc.vpc.id
  public_gateway           = coalesce([ for gateway in var.gateways: gateway.id if gateway.zone == local.vpc_zone_names[count.index] ]...)
  total_ipv4_address_count = local.ipv4_address_count
  resource_group           = var.resource_group_id
  network_acl              = var.acl_id
  ipv4_cidr_block          = local.ipv4_cidr_block[count.index]
}

resource ibm_is_subnet vpc_subnet_total_count {
  count                    = local.ipv4_cidr_provided ? 0 : var._count

  name                     = "${var.vpc_name}-subnet-${var.label}${format("%02s", count.index)}"
  zone                     = local.vpc_zone_names[count.index]
  vpc                      = data.ibm_is_vpc.vpc.id
  public_gateway           = coalesce([ for gateway in var.gateways: gateway.id if gateway.zone == local.vpc_zone_names[count.index] ]...)
  total_ipv4_address_count = local.ipv4_address_count
  resource_group           = var.resource_group_id
  network_acl              = var.acl_id
}
