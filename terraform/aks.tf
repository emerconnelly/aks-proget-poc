resource "azurerm_kubernetes_cluster" "this" {
  name                = azurerm_resource_group.this.name
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location

  kubernetes_version        = "1.28.3"
  dns_prefix                = resource_group.this.name
  sku_tier                  = "Free"
  workload_identity_enabled = true
  oidc_issuer_enabled       = true

  default_node_pool {
    name                        = "default"
    vm_size                     = "Standard_D2a_v4"
    node_count                  = 1
    os_sku                      = "AzureLinux"
    os_disk_type                = "Ephemeral"
    os_disk_size_gb             = 30
    vnet_subnet_id              = azurerm_subnet.aks_nodes.id
    temporary_name_for_rotation = "temp"

    upgrade_settings {
      max_surge = "10%"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    load_balancer_sku = "standard"
    network_plugin    = "kubenet"
    network_policy    = "calico"
    outbound_type     = "loadBalancer"
    pod_cidr          = "10.244.0.0/16" # this is Azure's default setting
    service_cidr      = "172.16.0.0/16" # using a different class helps differentiate from pods & nodes
    dns_service_ip    = "172.16.0.10"
  }

  # web_app_routing {
  #   # https://learn.microsoft.com/en-us/azure/aks/app-routing?tabs=default%2Cdeploy-app-default
  #   dns_zone_id = 
  # }

  ingress_application_gateway {
    # https://learn.microsoft.com/en-us/azure/application-gateway/tutorial-ingress-controller-add-on-new
    subnet_id = azurerm_subnet.app_gateway.id
  }

  key_vault_secrets_provider {
    # https://learn.microsoft.com/en-us/azure/aks/csi-secrets-store-driver
    secret_rotation_interval = "1m"
  }
}

resource "azurerm_kubernetes_cluster_extension" "flux" {
  name       = "microsoft.flux"
  cluster_id = azurerm_kubernetes_cluster.this.id

  extension_type    = "microsoft.flux"
  release_namespace = "flux-system"
  configuration_settings = {
    "image-automation-controller.enabled"              = true,
    "image-reflector-controller.enabled"               = true,
    "notification-controller.enabled"                  = true,
    "helm-controller.detectDrift"                      = true,
    "helm-controller.outOfMemoryWatch.enabled"         = true,
    "helm-controller.outOfMemoryWatch.memoryThreshold" = 70,
    "helm-controller.outOfMemoryWatch.interval"        = "700ms"
  }
}

resource "azurerm_kubernetes_flux_configuration" "proget" {
  name       = azurerm_resource_group.this.name
  cluster_id = azurerm_kubernetes_cluster.this.id

  namespace                         = "flux-system"
  scope                             = "cluster"
  continuous_reconciliation_enabled = true

  git_repository {
    url                      = "https://github.com/emerconnelly/aks-proget-poc"
    reference_type           = "branch"
    reference_value          = "main"
    sync_interval_in_seconds = 60
    timeout_in_seconds       = 60
  }

  kustomizations {
    name                       = "proget"
    path                       = "./k8s/proget"
    garbage_collection_enabled = true
    recreating_enabled         = true
    timeout_in_seconds         = 60
    sync_interval_in_seconds   = 60
    retry_interval_in_seconds  = 60
  }

  depends_on = [
    azurerm_kubernetes_cluster_extension.flux,
    azurerm_mssql_database.this,
    azurerm_storage_container.this,
    # azurerm_federated_identity_credential.aks_csi_driver_proget
  ]
}
