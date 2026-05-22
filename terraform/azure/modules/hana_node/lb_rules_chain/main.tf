variable "loadbalancer_id" {}
variable "hana_instance_number" {}
variable "backend_address_pool_id" {}
variable "probe_id" {}
variable "name_suffix" { default = "" }
variable "frontend_ip_configuration_name" {}

locals {
  ports = [
    "3${var.hana_instance_number}13",
    "3${var.hana_instance_number}14",
    "3${var.hana_instance_number}40",
    "3${var.hana_instance_number}41",
    "3${var.hana_instance_number}42",
    "3${var.hana_instance_number}15",
    "3${var.hana_instance_number}17",
    "5${var.hana_instance_number}13"
  ]
}

resource "azurerm_lb_rule" "hana_lb_rule_30013" {
  loadbalancer_id                = var.loadbalancer_id
  name                           = "lbrule-hana-tcp-${local.ports[0]}${var.name_suffix}"
  protocol                       = "Tcp"
  frontend_ip_configuration_name = var.frontend_ip_configuration_name
  frontend_port                  = tonumber(local.ports[0])
  backend_port                   = tonumber(local.ports[0])
  backend_address_pool_ids       = [var.backend_address_pool_id]
  probe_id                       = var.probe_id
  idle_timeout_in_minutes        = 30
  floating_ip_enabled            = "true"
}

resource "time_sleep" "wait_30013" {
  create_duration = "6s"
  depends_on      = [azurerm_lb_rule.hana_lb_rule_30013]
}

resource "azurerm_lb_rule" "hana_lb_rule_30014" {
  loadbalancer_id                = var.loadbalancer_id
  name                           = "lbrule-hana-tcp-${local.ports[1]}${var.name_suffix}"
  protocol                       = "Tcp"
  frontend_ip_configuration_name = var.frontend_ip_configuration_name
  frontend_port                  = tonumber(local.ports[1])
  backend_port                   = tonumber(local.ports[1])
  backend_address_pool_ids       = [var.backend_address_pool_id]
  probe_id                       = var.probe_id
  idle_timeout_in_minutes        = 30
  floating_ip_enabled            = "true"

  depends_on = [time_sleep.wait_30013]
}

resource "time_sleep" "wait_30014" {
  create_duration = "6s"
  depends_on      = [azurerm_lb_rule.hana_lb_rule_30014]
}

resource "azurerm_lb_rule" "hana_lb_rule_30040" {
  loadbalancer_id                = var.loadbalancer_id
  name                           = "lbrule-hana-tcp-${local.ports[2]}${var.name_suffix}"
  protocol                       = "Tcp"
  frontend_ip_configuration_name = var.frontend_ip_configuration_name
  frontend_port                  = tonumber(local.ports[2])
  backend_port                   = tonumber(local.ports[2])
  backend_address_pool_ids       = [var.backend_address_pool_id]
  probe_id                       = var.probe_id
  idle_timeout_in_minutes        = 30
  floating_ip_enabled            = "true"

  depends_on = [time_sleep.wait_30014]
}

resource "time_sleep" "wait_30040" {
  create_duration = "6s"
  depends_on      = [azurerm_lb_rule.hana_lb_rule_30040]
}

resource "azurerm_lb_rule" "hana_lb_rule_30041" {
  loadbalancer_id                = var.loadbalancer_id
  name                           = "lbrule-hana-tcp-${local.ports[3]}${var.name_suffix}"
  protocol                       = "Tcp"
  frontend_ip_configuration_name = var.frontend_ip_configuration_name
  frontend_port                  = tonumber(local.ports[3])
  backend_port                   = tonumber(local.ports[3])
  backend_address_pool_ids       = [var.backend_address_pool_id]
  probe_id                       = var.probe_id
  idle_timeout_in_minutes        = 30
  floating_ip_enabled            = "true"

  depends_on = [time_sleep.wait_30040]
}

resource "time_sleep" "wait_30041" {
  create_duration = "6s"
  depends_on      = [azurerm_lb_rule.hana_lb_rule_30041]
}

resource "azurerm_lb_rule" "hana_lb_rule_30042" {
  loadbalancer_id                = var.loadbalancer_id
  name                           = "lbrule-hana-tcp-${local.ports[4]}${var.name_suffix}"
  protocol                       = "Tcp"
  frontend_ip_configuration_name = var.frontend_ip_configuration_name
  frontend_port                  = tonumber(local.ports[4])
  backend_port                   = tonumber(local.ports[4])
  backend_address_pool_ids       = [var.backend_address_pool_id]
  probe_id                       = var.probe_id
  idle_timeout_in_minutes        = 30
  floating_ip_enabled            = "true"

  depends_on = [time_sleep.wait_30041]
}

resource "time_sleep" "wait_30042" {
  create_duration = "6s"
  depends_on      = [azurerm_lb_rule.hana_lb_rule_30042]
}

resource "azurerm_lb_rule" "hana_lb_rule_30015" {
  loadbalancer_id                = var.loadbalancer_id
  name                           = "lbrule-hana-tcp-${local.ports[5]}${var.name_suffix}"
  protocol                       = "Tcp"
  frontend_ip_configuration_name = var.frontend_ip_configuration_name
  frontend_port                  = tonumber(local.ports[5])
  backend_port                   = tonumber(local.ports[5])
  backend_address_pool_ids       = [var.backend_address_pool_id]
  probe_id                       = var.probe_id
  idle_timeout_in_minutes        = 30
  floating_ip_enabled            = "true"

  depends_on = [time_sleep.wait_30042]
}

resource "time_sleep" "wait_30015" {
  create_duration = "6s"
  depends_on      = [azurerm_lb_rule.hana_lb_rule_30015]
}

resource "azurerm_lb_rule" "hana_lb_rule_30017" {
  loadbalancer_id                = var.loadbalancer_id
  name                           = "lbrule-hana-tcp-${local.ports[6]}${var.name_suffix}"
  protocol                       = "Tcp"
  frontend_ip_configuration_name = var.frontend_ip_configuration_name
  frontend_port                  = tonumber(local.ports[6])
  backend_port                   = tonumber(local.ports[6])
  backend_address_pool_ids       = [var.backend_address_pool_id]
  probe_id                       = var.probe_id
  idle_timeout_in_minutes        = 30
  floating_ip_enabled            = "true"

  depends_on = [time_sleep.wait_30015]
}

resource "time_sleep" "wait_30017" {
  create_duration = "6s"
  depends_on      = [azurerm_lb_rule.hana_lb_rule_30017]
}

resource "azurerm_lb_rule" "hana_lb_rule_50013" {
  loadbalancer_id                = var.loadbalancer_id
  name                           = "lbrule-hana-tcp-${local.ports[7]}${var.name_suffix}"
  protocol                       = "Tcp"
  frontend_ip_configuration_name = var.frontend_ip_configuration_name
  frontend_port                  = tonumber(local.ports[7])
  backend_port                   = tonumber(local.ports[7])
  backend_address_pool_ids       = [var.backend_address_pool_id]
  probe_id                       = var.probe_id
  idle_timeout_in_minutes        = 30
  floating_ip_enabled            = "true"

  depends_on = [time_sleep.wait_30017]
}

resource "time_sleep" "wait_50013" {
  create_duration = "6s"
  depends_on      = [azurerm_lb_rule.hana_lb_rule_50013]
}

