data "ibm_is_image" "ds_image" {
  name = "ibm-centos-7-6-minimal-amd64-2"
}

data "ibm_is_ssh_key" "ds_key" {
  name = var.ssh_keyname
}

data "ibm_resource_group" "group" {
  is_default = "true"
}

resource "ibm_is_vpc" "vpc" {
  name           = var.vpc_name
  resource_group = data.ibm_resource_group.group.id
}

resource "ibm_is_security_group" "sg1" {
  name = "${var.basename}-sg1"
  vpc  = ibm_is_vpc.vpc.id
}

# allow all incoming network traffic on port 22
resource "ibm_is_security_group_rule" "ingress_ssh_all" {
  group     = ibm_is_security_group.sg1.id
  direction = "inbound"
  remote    = "0.0.0.0/0"

  tcp {
    port_min = 22
    port_max = 22
  }
}

# allow all incoming network traffic on port 80
resource "ibm_is_security_group_rule" "ingress_web_all" {
  group     = ibm_is_security_group.sg1.id
  direction = "inbound"
  remote    = "0.0.0.0/0"

  tcp {
    port_min = 80
    port_max = 80
  }
}

# allow all incoming network traffic on port 443
resource "ibm_is_security_group_rule" "ingress_secweb_all" {
  group     = ibm_is_security_group.sg1.id
  direction = "inbound"
  remote    = "0.0.0.0/0"

  tcp {
    port_min = 443
    port_max = 443
  }
}

# allow all outcoming network traffic
resource "ibm_is_security_group_rule" "egress_all_web" {
  group     = ibm_is_security_group.sg1.id
  direction = "outbound"

  tcp {
    port_min = 80
    port_max = 80
  }
}

resource "ibm_is_security_group_rule" "egress_all_secweb" {
  group     = ibm_is_security_group.sg1.id
  direction = "outbound"

  tcp {
    port_min = 443
    port_max = 443
  }
}

resource "ibm_is_security_group_rule" "egress_all_dns_tcp" {
  group     = ibm_is_security_group.sg1.id
  direction = "outbound"

  tcp {
    port_min = 53
    port_max = 53
  }
}

resource "ibm_is_security_group_rule" "egress_all_dns_udp" {
  group     = ibm_is_security_group.sg1.id
  direction = "outbound"

  udp {
    port_min = 53
    port_max = 53
  }
}

resource "ibm_is_public_gateway" "cloud" {
  vpc   = ibm_is_vpc.vpc.id
  name  = "${var.basename}-pubgw"
  zone  = var.subnet_zone
}

resource "ibm_is_vpc_address_prefix" "vpc_address_prefix" {
  name = "${var.basename}-prefix"
  zone = var.subnet_zone
  vpc  = ibm_is_vpc.vpc.id
  cidr = "192.168.0.0/16"
}

resource "ibm_is_subnet" "subnet" {
  name            = "${var.basename}-subnet"
  vpc             = ibm_is_vpc.vpc.id
  zone            = var.subnet_zone
  resource_group  = data.ibm_resource_group.group.id
  public_gateway  = ibm_is_public_gateway.cloud.id
  ipv4_cidr_block = ibm_is_vpc_address_prefix.vpc_address_prefix.cidr
}

resource "ibm_is_instance" "instance" {
  count          = var.instance_count
  name           = "${var.basename}-instance-${count.index}"
  vpc            = ibm_is_vpc.vpc.id
  zone           = var.subnet_zone
  profile        = "cx2-2x4"
  image          = data.ibm_is_image.ds_image.id
  keys           = [data.ibm_is_ssh_key.ds_key.id]
  resource_group = data.ibm_resource_group.group.id

  primary_network_interface {
    subnet = ibm_is_subnet.subnet.id
    security_groups = [ibm_is_security_group.sg1.id]
  }
}
