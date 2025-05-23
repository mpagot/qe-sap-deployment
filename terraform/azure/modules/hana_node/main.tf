# Availabilityset for the hana VMs

locals {
  shared_storage_anf         = var.common_variables["hana"]["scale_out_enabled"] && var.common_variables["hana"]["scale_out_shared_storage_type"] == "anf" ? 1 : 0
  create_scale_out           = var.hana_count > 1 && var.common_variables["hana"]["scale_out_enabled"] ? 1 : 0
  create_ha_infra            = var.hana_count > 1 && var.common_variables["hana"]["ha_enabled"] ? 1 : 0
  sites                      = var.common_variables["hana"]["ha_enabled"] ? 2 : 1
  create_active_active_infra = local.create_ha_infra == 1 && var.common_variables["hana"]["cluster_vip_secondary"] != "" ? 1 : 0
  provisioning_addresses     = data.azurerm_public_ip.hana.*.ip_address
  hana_lb_rules_ports = local.create_ha_infra == 1 ? toset([
    "3${var.hana_instance_number}13",
    "3${var.hana_instance_number}14",
    "3${var.hana_instance_number}40",
    "3${var.hana_instance_number}41",
    "3${var.hana_instance_number}42",
    "3${var.hana_instance_number}15",
    "3${var.hana_instance_number}17",
    "5${var.hana_instance_number}13" # S4HANA DB import checks sapctrl port
  ]) : toset([])

  hana_lb_rules_ports_secondary = local.create_active_active_infra == 1 ? local.hana_lb_rules_ports : toset([])
  hostname                      = var.common_variables["deployment_name_in_hostname"] ? format("%s-%s", var.common_variables["deployment_name"], var.name) : var.name
}

resource "azurerm_availability_set" "hana-availability-set" {
  count                       = local.create_ha_infra
  name                        = "avset-hana"
  location                    = var.az_region
  resource_group_name         = var.resource_group_name
  managed                     = "true"
  platform_fault_domain_count = 2 + local.create_scale_out

  tags = {
    workspace = var.common_variables["deployment_name"]
  }
}

# hana load balancer items

resource "azurerm_lb" "hana-load-balancer" {
  count               = local.create_ha_infra
  name                = "lb-hana"
  location            = var.az_region
  resource_group_name = var.resource_group_name

  frontend_ip_configuration {
    name                          = "lbfe-hana"
    subnet_id                     = var.network_subnet_id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.common_variables["hana"]["cluster_vip"]
  }

  # Create a new frontend for the Active/Active scenario
  dynamic "frontend_ip_configuration" {
    for_each = local.create_active_active_infra == 1 ? [var.common_variables["hana"]["cluster_vip_secondary"]] : []
    content {
      name                          = "lbfe-hana-secondary"
      subnet_id                     = var.network_subnet_id
      private_ip_address_allocation = "Static"
      private_ip_address            = frontend_ip_configuration.value
    }
  }

  tags = {
    workspace = var.common_variables["deployment_name"]
  }
}

# backend pools

resource "azurerm_lb_backend_address_pool" "hana-load-balancer" {
  count           = local.create_ha_infra
  loadbalancer_id = azurerm_lb.hana-load-balancer[0].id
  name            = "lbbe-hana"
}

resource "azurerm_network_interface_backend_address_pool_association" "hana" {
  count                   = var.common_variables["hana"]["ha_enabled"] ? var.hana_count : 0
  network_interface_id    = element(azurerm_network_interface.hana.*.id, count.index)
  ip_configuration_name   = "ipconf-primary"
  backend_address_pool_id = azurerm_lb_backend_address_pool.hana-load-balancer[0].id
}

resource "azurerm_lb_probe" "hana-load-balancer" {
  count = local.create_ha_infra
  #resource_group_name = var.resource_group_name
  loadbalancer_id     = azurerm_lb.hana-load-balancer[0].id
  name                = "lbhp-hana"
  protocol            = "Tcp"
  port                = tonumber("625${var.hana_instance_number}")
  interval_in_seconds = 5
  number_of_probes    = 2
}

resource "azurerm_lb_probe" "hana-load-balancer-secondary" {
  count = local.create_active_active_infra
  #resource_group_name = var.resource_group_name
  loadbalancer_id     = azurerm_lb.hana-load-balancer[0].id
  name                = "lbhp-hana-secondary"
  protocol            = "Tcp"
  port                = tonumber("626${var.hana_instance_number}")
  interval_in_seconds = 5
  number_of_probes    = 2
}

# Load balancing rules for HANA 2.0
resource "azurerm_lb_rule" "hana-lb-rules" {
  for_each = local.hana_lb_rules_ports
  #resource_group_name            = var.resource_group_name
  loadbalancer_id                = azurerm_lb.hana-load-balancer[0].id
  name                           = "lbrule-hana-tcp-${each.value}"
  protocol                       = "Tcp"
  frontend_ip_configuration_name = "lbfe-hana"
  frontend_port                  = tonumber(each.value)
  backend_port                   = tonumber(each.value)
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.hana-load-balancer[0].id]
  probe_id                       = azurerm_lb_probe.hana-load-balancer[0].id
  idle_timeout_in_minutes        = 30
  enable_floating_ip             = "true"
}

# Load balancing rules for the Active/Active setup
resource "azurerm_lb_rule" "hana-lb-rules-secondary" {
  for_each = local.hana_lb_rules_ports_secondary
  #resource_group_name            = var.resource_group_name
  loadbalancer_id                = azurerm_lb.hana-load-balancer[0].id
  name                           = "lbrule-hana-tcp-${each.value}-secondary"
  protocol                       = "Tcp"
  frontend_ip_configuration_name = "lbfe-hana-secondary"
  frontend_port                  = tonumber(each.value)
  backend_port                   = tonumber(each.value)
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.hana-load-balancer[0].id]
  probe_id                       = azurerm_lb_probe.hana-load-balancer-secondary[0].id
  idle_timeout_in_minutes        = 30
  enable_floating_ip             = "true"
}

resource "azurerm_lb_rule" "hanadb_exporter" {
  count = var.common_variables["monitoring_enabled"] ? local.create_ha_infra : 0
  #resource_group_name            = var.resource_group_name
  loadbalancer_id                = azurerm_lb.hana-load-balancer[0].id
  name                           = "hanadb_exporter"
  protocol                       = "Tcp"
  frontend_ip_configuration_name = "lbfe-hana"
  frontend_port                  = 9668
  backend_port                   = 9668
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.hana-load-balancer[0].id]
  probe_id                       = azurerm_lb_probe.hana-load-balancer[0].id
  idle_timeout_in_minutes        = 30
  enable_floating_ip             = "true"
}

# hana network configuration

resource "azurerm_network_interface" "hana" {
  count                          = var.hana_count
  name                           = "nic-${var.name}${format("%02d", count.index + 1)}"
  location                       = var.az_region
  resource_group_name            = var.resource_group_name
  accelerated_networking_enabled = var.enable_accelerated_networking

  ip_configuration {
    name                          = "ipconf-primary"
    subnet_id                     = var.network_subnet_id
    private_ip_address_allocation = "Static"
    private_ip_address            = element(var.host_ips, count.index)
    public_ip_address_id          = element(azurerm_public_ip.hana.*.id, count.index)
  }

  tags = {
    workspace = var.common_variables["deployment_name"]
  }
}

resource "azurerm_public_ip" "hana" {
  count                   = var.hana_count
  name                    = "pip-${var.name}${format("%02d", count.index + 1)}"
  location                = var.az_region
  resource_group_name     = var.resource_group_name
  allocation_method       = "Dynamic"
  idle_timeout_in_minutes = 30

  tags = {
    workspace = var.common_variables["deployment_name"]
  }
}

resource "azurerm_image" "sles4sap" {
  count               = var.sles4sap_uri != "" ? 1 : 0
  name                = "BVSles4SapImg"
  location            = var.az_region
  resource_group_name = var.resource_group_name

  os_disk {
    os_type  = "Linux"
    os_state = "Generalized"
    blob_uri = var.sles4sap_uri
    size_gb  = "32"
  }

  tags = {
    workspace = var.common_variables["deployment_name"]
  }
}

# ANF volumes
resource "azurerm_netapp_volume" "hana-netapp-volume-data" {
  count = local.shared_storage_anf * local.sites

  lifecycle {
    prevent_destroy = false
  }

  name                = "${var.name}-netapp-volume-data-${count.index + 1}"
  location            = var.az_region
  resource_group_name = var.resource_group_name
  account_name        = var.anf_account_name
  pool_name           = var.anf_pool_name
  volume_path         = "${var.name}-data-${count.index + 1}"
  service_level       = var.anf_pool_service_level
  subnet_id           = var.network_subnet_netapp_id
  protocols           = ["NFSv4.1"]
  storage_quota_in_gb = var.hana_scale_out_anf_quota_data

  export_policy_rule {
    rule_index          = 1
    protocols_enabled   = ["NFSv4.1"]
    allowed_clients     = ["0.0.0.0/0"]
    unix_read_write     = true
    root_access_enabled = true
  }

  # Following section is only required if deploying a data protection volume (secondary)
  # to enable Cross-Region Replication feature
  # data_protection_replication {
  #   endpoint_type             = "dst"
  #   remote_volume_location    = azurerm_resource_group.example_primary.location
  #   remote_volume_resource_id = azurerm_netapp_volume.example_primary.id
  #   replication_frequency     = "10minutes"
  # }
}

resource "azurerm_netapp_volume" "hana-netapp-volume-log" {
  count = local.shared_storage_anf * local.sites

  lifecycle {
    prevent_destroy = false
  }

  name                = "${var.name}-netapp-volume-log-${count.index + 1}"
  location            = var.az_region
  resource_group_name = var.resource_group_name
  account_name        = "netapp-acc-${lower(var.common_variables["deployment_name"])}"
  pool_name           = "netapp-pool-${lower(var.common_variables["deployment_name"])}"
  volume_path         = "${var.name}-log-${count.index + 1}"
  service_level       = var.anf_pool_service_level
  subnet_id           = var.network_subnet_netapp_id
  protocols           = ["NFSv4.1"]
  storage_quota_in_gb = var.hana_scale_out_anf_quota_log

  export_policy_rule {
    rule_index          = 1
    protocols_enabled   = ["NFSv4.1"]
    allowed_clients     = ["0.0.0.0/0"]
    unix_read_write     = true
    root_access_enabled = true
  }

  # Following section is only required if deploying a data protection volume (secondary)
  # to enable Cross-Region Replication feature
  # data_protection_replication {
  #   endpoint_type             = "dst"
  #   remote_volume_location    = azurerm_resource_group.example_primary.location
  #   remote_volume_resource_id = azurerm_netapp_volume.example_primary.id
  #   replication_frequency     = "10minutes"
  # }
}

resource "azurerm_netapp_volume" "hana-netapp-volume-backup" {
  count = local.shared_storage_anf * local.sites

  lifecycle {
    prevent_destroy = false
  }

  name                = "${var.name}-netapp-volume-backup-${count.index + 1}"
  location            = var.az_region
  resource_group_name = var.resource_group_name
  account_name        = "netapp-acc-${lower(var.common_variables["deployment_name"])}"
  pool_name           = "netapp-pool-${lower(var.common_variables["deployment_name"])}"
  volume_path         = "${var.name}-backup-${count.index + 1}"
  service_level       = var.anf_pool_service_level
  subnet_id           = var.network_subnet_netapp_id
  protocols           = ["NFSv4.1"]
  storage_quota_in_gb = var.hana_scale_out_anf_quota_backup

  export_policy_rule {
    rule_index          = 1
    protocols_enabled   = ["NFSv4.1"]
    allowed_clients     = ["0.0.0.0/0"]
    unix_read_write     = true
    root_access_enabled = true
  }

  # Following section is only required if deploying a data protection volume (secondary)
  # to enable Cross-Region Replication feature
  # data_protection_replication {
  #   endpoint_type             = "dst"
  #   remote_volume_location    = azurerm_resource_group.example_primary.location
  #   remote_volume_resource_id = azurerm_netapp_volume.example_primary.id
  #   replication_frequency     = "10minutes"
  # }
}

resource "azurerm_netapp_volume" "hana-netapp-volume-shared" {
  count = local.shared_storage_anf * local.sites

  lifecycle {
    prevent_destroy = false
  }

  name                = "${var.name}-netapp-volume-shared-${count.index + 1}"
  location            = var.az_region
  resource_group_name = var.resource_group_name
  account_name        = "netapp-acc-${lower(var.common_variables["deployment_name"])}"
  pool_name           = "netapp-pool-${lower(var.common_variables["deployment_name"])}"
  volume_path         = "${var.name}-shared-${count.index + 1}"
  service_level       = var.anf_pool_service_level
  subnet_id           = var.network_subnet_netapp_id
  protocols           = ["NFSv4.1"]
  storage_quota_in_gb = var.hana_scale_out_anf_quota_shared

  export_policy_rule {
    rule_index          = 1
    protocols_enabled   = ["NFSv4.1"]
    allowed_clients     = ["0.0.0.0/0"]
    unix_read_write     = true
    root_access_enabled = true
  }

  # Following section is only required if deploying a data protection volume (secondary)
  # to enable Cross-Region Replication feature
  # data_protection_replication {
  #   endpoint_type             = "dst"
  #   remote_volume_location    = azurerm_resource_group.example_primary.location
  #   remote_volume_resource_id = azurerm_netapp_volume.example_primary.id
  #   replication_frequency     = "10minutes"
  # }
}


# hana instances
module "os_image_reference" {
  source           = "../../modules/os_image_reference"
  os_image         = var.os_image
  os_image_srv_uri = var.sles4sap_uri != ""
}

locals {
  disks_number           = length(split(",", var.hana_data_disks_configuration["disks_size"]))
  disks_size             = [for disk_size in split(",", var.hana_data_disks_configuration["disks_size"]) : tonumber(trimspace(disk_size))]
  disks_type             = [for disk_type in split(",", var.hana_data_disks_configuration["disks_type"]) : trimspace(disk_type)]
  disks_caching          = [for caching in split(",", var.hana_data_disks_configuration["caching"]) : trimspace(caching)]
  disks_writeaccelerator = [for writeaccelerator in split(",", var.hana_data_disks_configuration["writeaccelerator"]) : tobool(trimspace(writeaccelerator))]
}

resource "azurerm_managed_disk" "hana_data_disk" {
  count                = var.hana_count * local.disks_number
  name                 = "disk-${var.name}${format("%02d", floor(count.index / local.disks_number) + 1)}-Data${format("%02d", count.index % local.disks_number + 1)}"
  location             = var.az_region
  resource_group_name  = var.resource_group_name
  storage_account_type = element(local.disks_type, count.index % local.disks_number)
  create_option        = "Empty"
  disk_size_gb         = element(local.disks_size, count.index % local.disks_number)
}

resource "azurerm_virtual_machine_data_disk_attachment" "hana_data_disk_attachment" {
  count              = var.hana_count * local.disks_number
  managed_disk_id    = azurerm_managed_disk.hana_data_disk[count.index].id
  virtual_machine_id = azurerm_linux_virtual_machine.hana[floor(count.index / local.disks_number)].id
  lun                = count.index % local.disks_number
  caching            = element(local.disks_caching, count.index % local.disks_number)
  timeouts {
    read = "30m"
  }
}

resource "azurerm_linux_virtual_machine" "hana" {
  count                 = var.hana_count
  name                  = "${var.name}${format("%02d", count.index + 1)}"
  location              = var.az_region
  resource_group_name   = var.resource_group_name
  network_interface_ids = [element(azurerm_network_interface.hana.*.id, count.index)]
  availability_set_id   = var.common_variables["hana"]["ha_enabled"] ? azurerm_availability_set.hana-availability-set[0].id : null
  size                  = var.vm_size

  admin_username = var.common_variables["authorized_user"]
  admin_ssh_key {
    username   = var.common_variables["authorized_user"]
    public_key = var.common_variables["public_key"]
  }
  disable_password_authentication = true

  dynamic "source_image_reference" {
    for_each = var.sles4sap_uri != "" ? [] : [1]
    content {
      publisher = module.os_image_reference.publisher
      offer     = module.os_image_reference.offer
      sku       = module.os_image_reference.sku
      version   = module.os_image_reference.version
    }
  }

  source_image_id = var.sles4sap_uri != "" ? join(",", azurerm_image.sles4sap.*.id) : null

  os_disk {
    name                 = "disk-${var.name}${format("%02d", count.index + 1)}-Os"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  boot_diagnostics {
    storage_account_uri = var.storage_account
  }

  tags = {
    workspace = var.common_variables["deployment_name"]
  }
}

module "hana_majority_maker" {
  source                        = "../majority_maker_node"
  node_count                    = local.create_scale_out
  name                          = var.name
  common_variables              = var.common_variables
  az_region                     = var.az_region
  vm_size                       = var.majority_maker_vm_size
  hana_count                    = var.hana_count
  majority_maker_ip             = var.majority_maker_ip
  host_ips                      = var.host_ips
  resource_group_name           = var.resource_group_name
  network_subnet_id             = var.network_subnet_id
  storage_account               = var.storage_account
  enable_accelerated_networking = var.enable_accelerated_networking
  sles4sap_uri                  = var.sles4sap_uri
  os_image                      = var.os_image
  iscsi_srv_ip                  = var.iscsi_srv_ip
  # only used by azure fence agent (native fencing)
  subscription_id           = var.subscription_id
  tenant_id                 = var.tenant_id
  fence_agent_app_id        = var.fence_agent_app_id
  fence_agent_client_secret = var.fence_agent_client_secret
}