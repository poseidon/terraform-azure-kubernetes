locals {
  # coreos-stable -> Container Linux Stable
  # flatcar-stable -> Flatcar Linux Stable
  flavor  = split("-", var.os_image)[0]
  channel = split("-", var.os_image)[1]
}

# Workers scale set
resource "azurerm_linux_virtual_machine_scale_set" "workers" {
  resource_group_name = var.resource_group_name

  name                   = "${var.name}-worker"
  location               = var.region
  sku = var.vm_type
  instances = var.worker_count
  # instance name prefix for instances in the set
  computer_name_prefix = "${var.name}-worker"
  single_placement_group = false
  custom_data          = base64encode(data.ct_config.worker-ignition.rendered)

  # storage
  os_disk {
    storage_account_type = "Standard_LRS"
    caching           = "ReadWrite"
  }

  source_image_reference {
    publisher = local.flavor == "flatcar" ? "Kinvolk" : "CoreOS"
    offer     = local.flavor == "flatcar" ? "flatcar-container-linux" : "CoreOS"
    sku       = local.channel
    version   = "latest"
  }

  # Gross hack just for Flatcar Linux
  dynamic "plan" {
    for_each = local.flavor == "flatcar" ? [1] : []

    content {
      name = local.channel
      publisher = "kinvolk"
      product = "flatcar-container-linux"
    }
  }

  # Azure requires setting admin_ssh_key, though Ignition custom_data handles it too
  admin_username = "core"
  admin_ssh_key {
    username = "core"
    public_key = var.ssh_authorized_key
  }

  # network
  network_interface {
    name                      = "nic0"
    primary                   = true
    network_security_group_id = var.security_group_id

    ip_configuration {
      name      = "ip0"
      primary   = true
      subnet_id = var.subnet_id

      # backend address pool to which the NIC should be added
      load_balancer_backend_address_pool_ids = [var.backend_address_pool_id]
    }
  }

  # lifecycle
  upgrade_mode = "Manual"
  # eviction policy may only be set when priority is Spot
  priority        = var.priority
  eviction_policy = var.priority == "Spot" ? "Delete" : null
}

# Scale up or down to maintain desired number, tolerating deallocations.
resource "azurerm_monitor_autoscale_setting" "workers" {
  resource_group_name = var.resource_group_name

  name     = "${var.name}-maintain-desired"
  location = var.region

  # autoscale
  enabled            = true
  target_resource_id = azurerm_linux_virtual_machine_scale_set.workers.id

  profile {
    name = "default"

    capacity {
      minimum = var.worker_count
      default = var.worker_count
      maximum = var.worker_count
    }
  }
}

# Worker Ignition configs
data "ct_config" "worker-ignition" {
  content      = data.template_file.worker-config.rendered
  pretty_print = false
  snippets     = var.clc_snippets
}

# Worker Container Linux configs
data "template_file" "worker-config" {
  template = file("${path.module}/cl/worker.yaml")

  vars = {
    kubeconfig             = indent(10, var.kubeconfig)
    ssh_authorized_key     = var.ssh_authorized_key
    cluster_dns_service_ip = cidrhost(var.service_cidr, 10)
    cluster_domain_suffix  = var.cluster_domain_suffix
    node_labels            = join(",", var.node_labels)
  }
}

