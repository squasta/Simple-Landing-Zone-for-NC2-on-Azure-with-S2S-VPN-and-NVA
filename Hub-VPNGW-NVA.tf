
# A VNet named Hub-VNet
# cf. https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network

resource "azurerm_virtual_network" "TF_HubVNet" {
  name                = var.HubVNetName
  location            = var.Location
  resource_group_name = azurerm_resource_group.TF_RG.name
  # address_space       = ["172.16.0.0/16"]
  address_space     = var.HubVNetCIDR

    tags = {
        environment = "Hub"
    }
}


# A Subnet in Hub VNet
# cf. https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet
# https://www.ipaddressguide.com/cidr 

resource "azurerm_subnet" "TF_HubSubnet" {
  name                 = "HubSubnet"
  resource_group_name  = azurerm_resource_group.TF_RG.name
  virtual_network_name = azurerm_virtual_network.TF_HubVNet.name
  # address_prefixes     = ["172.16.0.0/24"]
  address_prefixes     = var.HubSubnetCIDR

}

# Subnet for Azure Firewall in Hub VNet
# cf. https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet
# https://learn.microsoft.com/en-us/azure/firewall/tutorial-firewall-deploy-portal
resource "azurerm_subnet" "TF_HubFWSubnet" {
  name                 = "AzureFirewallSubnet"  # This name is required by Azure Firewall
  resource_group_name  = azurerm_resource_group.TF_RG.name
  virtual_network_name = azurerm_virtual_network.TF_HubVNet.name
  # address_prefixes     = ["172.16.1.0/24"]
  address_prefixes     = var.HubFirewallSubnetCIDR
}


# Subnet for AzureBastion
# This subnet is for Azure Bastion
# cf. https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet
# more info on Azure Bastion : https://docs.microsoft.com/en-us/azure/bastion/bastion-create-host-portal
resource "azurerm_subnet" "TF_Azure_Bastion_Subnet" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.TF_RG.name
  virtual_network_name = azurerm_virtual_network.TF_HubVNet.name
  address_prefixes     = var.HubBastionSubnetCIDR 
}



# A Subnet in Hub VNet for VPN Gateway
# cf. https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet

resource "azurerm_subnet" "TF_HubVPNGWSubnet" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.TF_RG.name
  virtual_network_name = azurerm_virtual_network.TF_HubVNet.name
  # address_prefixes     = ["172.16.250.0/27"]
  address_prefixes     = var.HubVPNGWSubnetCIDR
}


# A Public IP for VPN Gateway in Hub VNet
# cf. https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip

resource "azurerm_public_ip" "TF_HubVPNGWPublicIP" {
  name                = "Hub-VPNGW-PublicIP"
  location            = var.Location
  resource_group_name = azurerm_resource_group.TF_RG.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones = [1, 2, 3]
}


# A VPN Gateway in Hub VNet in GatewaySubnet
# cf. https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network_gateway
# Important : deploying a new VPN Gateway needs about 30-45 minutes for deployment
# Microsoft does not support the Basic SKU and any gateway in an Active-Active mode.
# Only VpnGw1 and higher VPN gateway SKUs are supported
# cf. https://portal.nutanix.com/page/documents/details?targetId=Nutanix-Cloud-Clusters-Azure:nc2-clusters-azure-setting-up-vpnexpressroute-t.html
# available Azure VPN gateway : https://docs.azure.cn/en-us/vpn-gateway/about-gateway-skus
# https://docs.azure.cn/en-us/vpn-gateway/gateway-sku-consolidation
resource "azurerm_virtual_network_gateway" "TF_HubVPNGW" {
  name                = "Hub-VPNGW"
  location            = var.Location
  resource_group_name = azurerm_resource_group.TF_RG.name
  type                = "Vpn"
  vpn_type            = "RouteBased"
  sku                 = "VpnGw1AZ"    
  active_active       = false
  # enable_bgp          = false

  ip_configuration {
    name                          = "HubGWIPConfig"
    public_ip_address_id          = azurerm_public_ip.TF_HubVPNGWPublicIP.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.TF_HubVPNGWSubnet.id
  }

}

## Local gateway for on premises
# cf. https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/local_network_gateway
# The local network gateway is a specific object that represents your on-premises location (the site) for routing purposes.
# The local network gateway object is deployed in Azure, not to your on-premises location.
# When you created that VPN connection and identified the subnets in your on prem environment, 
# Azure auto creates routes as system defaults

resource "azurerm_local_network_gateway" "TF_HubLocalGW" {
  name                = "On-Premises-LocalGW"
  location            = var.Location
  resource_group_name = azurerm_resource_group.TF_RG.name
  gateway_address     = var.PublicIPRemoteVPNGateway # This is the public IP of your on-premises VPN device
  # address_space       = ["10.0.0.0/16"]
  address_space = var.OnPremisesDataCenterCIDRs
}




# VPN Connection between hub and on prem
# cf. https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network_gateway_connection

resource "azurerm_virtual_network_gateway_connection" "TF_HubOnPremConn" {
  name                     = "Hub-OnPrem-Connection"
  location                 = azurerm_resource_group.TF_RG.location
  resource_group_name      = azurerm_resource_group.TF_RG.name
  type                     = "IPsec"
  routing_weight      = 1
  virtual_network_gateway_id = azurerm_virtual_network_gateway.TF_HubVPNGW.id

  local_network_gateway_id = azurerm_local_network_gateway.TF_HubLocalGW.id
  shared_key = var.VPNSiteToSiteSharedKey
  connection_protocol = "IKEv2"
  # The IPsec policy is used to configure the encryption and integrity algorithms for the VPN connection.
  # The policy is applied to both the VPN gateway and the local network gateway.
  # cf. https://learn.microsoft.com/en-gb/azure/vpn-gateway/vpn-gateway-ipsecikepolicy-rm-powershell
  ipsec_policy {
    ike_encryption             = "AES256"
    ike_integrity              = "SHA256"
    dh_group                   = "DHGroup2"
    ipsec_encryption           = "AES256"
    ipsec_integrity            = "SHA256"
    pfs_group                  = "PFS2"
  }

  depends_on = [ azurerm_virtual_network_gateway.TF_HubVPNGW, azurerm_local_network_gateway.TF_HubLocalGW]
}

#### Peering between Hub VNet and Spoke VNets ####


# Peering between Cluster VNet and Hub Vnet
# cf. https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network_peering
resource "azurerm_virtual_network_peering" "TF_Peering_Cluster2Hub" {
  name                      = "Peer-ClusterVNet-to-HubVNet"
  resource_group_name       = azurerm_resource_group.TF_RG.name
  virtual_network_name      = azurerm_virtual_network.TF_Cluster_VNet.name
  remote_virtual_network_id = azurerm_virtual_network.TF_HubVNet.id
  allow_virtual_network_access = true
  use_remote_gateways = true  # because there is a VPN gateway in the Hub VNet
  allow_forwarded_traffic = true # because Azure Firewall is in Hub VNet and is a NVA
  depends_on = [ azurerm_virtual_network.TF_HubVNet, azurerm_virtual_network.TF_Cluster_VNet, azurerm_virtual_network_gateway.TF_HubVPNGW ]
  timeouts {
    create = "60m"
  }
}

# Peering between Hub Vnet and Cluster Vnet
# cf. https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network_peering
# cf. https://learn.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-peering-gateway-transit

resource "azurerm_virtual_network_peering" "TF_Peering_Hub2Cluster" {
  name                      = "Peer-HubVNet-to-ClusterVNet"
  resource_group_name       = azurerm_resource_group.TF_RG.name
  virtual_network_name      = azurerm_virtual_network.TF_HubVNet.name
  remote_virtual_network_id = azurerm_virtual_network.TF_Cluster_VNet.id
  allow_virtual_network_access = true
  allow_forwarded_traffic = false # because Azure Firewall is in Hub VNet and is a NVA.   <--- avant à Trrue mais Non pas utile devrait etre à false
  allow_gateway_transit = true                                                         # <-- devrait etre à true car le Hub VNet a un VPN gateway et on veut permettre le transit via ce gateway
  # use_remote_gateways = false
  depends_on = [ azurerm_virtual_network.TF_HubVNet, azurerm_virtual_network.TF_Cluster_VNet, azurerm_virtual_network_peering.TF_Peering_Cluster2Hub ]
  timeouts {
    create = "60m"
  }
}


# Peering between PC Vnet and hub Vnet
# cf. https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network_peering
# cf. https://learn.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-peering-gateway-transit
resource "azurerm_virtual_network_peering" "TF_Peering_PC2Hub" {
  name                      = "Peer-PCVNet-to-HubVNet"
  resource_group_name       = azurerm_resource_group.TF_RG.name
  virtual_network_name      = azurerm_virtual_network.TF_PC_VNet.name
  remote_virtual_network_id = azurerm_virtual_network.TF_HubVNet.id
  allow_virtual_network_access = true
  use_remote_gateways = true  # because there is a VPN gateway in the Hub VNet
  allow_forwarded_traffic = true # because Azure Firewall is in Hub VNet and is a NVA
  # `allow_gateway_transit` must be set to false for vnet Global Peering
  depends_on = [ azurerm_virtual_network.TF_HubVNet, azurerm_virtual_network.TF_PC_VNet, azurerm_virtual_network_gateway.TF_HubVPNGW ]
  timeouts {
    create = "60m"
  }
}

# Peering between Hub Vnet and PC Vnet
# cf. https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network_peering

resource "azurerm_virtual_network_peering" "TF_Peering_Hub2PC" {
  name                      = "Peer-HubVNet-to-PCVNet"
  resource_group_name       = azurerm_resource_group.TF_RG.name
  virtual_network_name      = azurerm_virtual_network.TF_HubVNet.name
  remote_virtual_network_id = azurerm_virtual_network.TF_PC_VNet.id
  allow_virtual_network_access = true
  allow_gateway_transit = true # because There is a VPN gateway in the Hub VNet and we want to allow transit through it
  allow_forwarded_traffic = false # because this is not nva in PC VNet
  depends_on = [ azurerm_virtual_network.TF_HubVNet, azurerm_virtual_network.TF_PC_VNet, azurerm_virtual_network_peering.TF_Peering_PC2Hub  ]
  timeouts {
    create = "60m"
  }
}


# Peering between FGW Vnet and Hub Vnet
# cf. https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network_peering

resource "azurerm_virtual_network_peering" "TF_Peering_FGW2Hub" {
  name                      = "Peer-FGWVNet-to-HubVNet"
  resource_group_name       = azurerm_resource_group.TF_RG.name
  virtual_network_name      = azurerm_virtual_network.TF_FGW_VNet.name
  remote_virtual_network_id = azurerm_virtual_network.TF_HubVNet.id
  allow_virtual_network_access = true
  use_remote_gateways = true     # because there is a gateway on Hub VNet
  allow_forwarded_traffic = true # because Azure Firewall is in Hub VNet and is a NVA
  depends_on = [ azurerm_virtual_network.TF_HubVNet, azurerm_virtual_network.TF_FGW_VNet, azurerm_virtual_network_gateway.TF_HubVPNGW ]
  timeouts {
    create = "60m"
  }
}

# Peering between Hub Vnet and FGW Vnet
# cf. https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network_peering

resource "azurerm_virtual_network_peering" "TF_Peering_Hub2FGW" {
  name                      = "Peer-HubVNet-to-FGWVNet"
  resource_group_name       = azurerm_resource_group.TF_RG.name
  virtual_network_name      = azurerm_virtual_network.TF_HubVNet.name
  remote_virtual_network_id = azurerm_virtual_network.TF_FGW_VNet.id
  allow_virtual_network_access = true
  allow_gateway_transit = true
  allow_forwarded_traffic = true # because Flow Gateway is in FGW VNet and is a NVA
  depends_on = [ azurerm_virtual_network.TF_HubVNet, azurerm_virtual_network.TF_FGW_VNet, azurerm_virtual_network_peering.TF_Peering_FGW2Hub ]
  timeouts {
    create = "60m"
  }
}


# ======= Routes et Route Tables

# An Azure Route table and associated routes for Cluster VNet, PC VNet and FGW VNet
# cf. https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/route_table
# cf. https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/route

resource "azurerm_route_table" "TF_Route_Table_Cluster_PC_FGW" {
  name                = "rt-cluster-pc-fgw"
  location            = azurerm_resource_group.TF_RG.location
  resource_group_name = azurerm_resource_group.TF_RG.name
}

# Route Spokes to Internet via Hub FW Private IP
# cf. https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/route
resource "azurerm_route" "TF_Route_Cluster_PC_FGW_to_Internet_via_HubFW" {
  name                   = "route-to-internet-via-hub-fw"
  resource_group_name    = azurerm_resource_group.TF_RG.name
  route_table_name       = azurerm_route_table.TF_Route_Table_Cluster_PC_FGW.name
  address_prefix         = "0.0.0.0/0"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = azurerm_firewall.TF_AzureFW.ip_configuration[0].private_ip_address
}



# Route Spokes to Datacenter via VPN gateway (not FW)
# cf. https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/route
resource "azurerm_route" "TF_Route_Cluster_PC_FGW_to_Datacenter_via_HubVPNGW" {
  name                   = "route-to-datacenter-via-hub-vpngw"
  resource_group_name    = azurerm_resource_group.TF_RG.name
  route_table_name       = azurerm_route_table.TF_Route_Table_Cluster_PC_FGW.name
  address_prefix         = var.OnPremisesDataCenterCIDRs[0]
  next_hop_type          = "VirtualNetworkGateway"
}



# Associate Route Table to Cluster Subnet
# cf. https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet_route_table_association
resource "azurerm_subnet_route_table_association" "TF_Subnet_RouteTable_Association_Cluster_Subnet" {
  subnet_id      = azurerm_subnet.TF_SubNet_Cluster.id
  route_table_id = azurerm_route_table.TF_Route_Table_Cluster_PC_FGW.id
} 

# Associate Route Table to PC Subnet
# cf. https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet_route_table_association
resource "azurerm_subnet_route_table_association" "TF_Subnet_RouteTable_Association_PC_Subnet" {
  subnet_id      = azurerm_subnet.TF_Subnet_Cluster_PC.id
  route_table_id = azurerm_route_table.TF_Route_Table_Cluster_PC_FGW.id
} 

# Associate Route Table to FGW External Subnet
# cf. https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet_route_table_association
resource "azurerm_subnet_route_table_association" "TF_Subnet_RouteTable_Association_FGW_External_Subnet" {
  subnet_id      = azurerm_subnet.TF_Fgw_External_Subnet.id
  route_table_id = azurerm_route_table.TF_Route_Table_Cluster_PC_FGW.id
}

# Associate Route Table to BGP Subnet
# cf. https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet_route_table_association
resource "azurerm_subnet_route_table_association" "TF_Subnet_RouteTable_Association_BGP_Subnet" {
  subnet_id      = azurerm_subnet.TF_BGP_Subnet.id
  route_table_id = azurerm_route_table.TF_Route_Table_Cluster_PC_FGW.id
}   




# ======= NVA - Here Azure Firewall is deployed in the Hub Vnet, but you can deploy your own NVA in the Hub Vnet and configure it as a next hop for traffic 
# from spoke Vnets to on-premises network.

# Azure Firewall
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/firewall
resource "azurerm_firewall" "TF_AzureFW" {
  name                = "azfw"
  location            = azurerm_resource_group.TF_RG.location
  resource_group_name = azurerm_resource_group.TF_RG.name
  # sku_name            = "AZFW_VNet"
  sku_name            = var.AzureFirewallSKUName
  #sku_tier            = "Standard"
  sku_tier            = var.AzureFirewallSKUTier
  ip_configuration {
    name                 = "azfw-ipconfig"
    subnet_id            = azurerm_subnet.TF_HubFWSubnet.id
    public_ip_address_id = azurerm_public_ip.TF_HubFWPublicIP.id
  }
  firewall_policy_id = azurerm_firewall_policy.TF_AzureFWPolicy.id  
}


# Azure Firewall Public IP
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip
resource "azurerm_public_ip" "TF_HubFWPublicIP" {
  name                = "azfw-pip"
  location            = azurerm_resource_group.TF_RG.location
  resource_group_name = azurerm_resource_group.TF_RG.name
  allocation_method   = "Static"  # Azure Firewall requires a static public IP
  sku                 = "Standard" # Azure Firewall requires a Standard SKU public IP     
}


# Azure Firewall Policy
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/firewall-policy
resource "azurerm_firewall_policy" "TF_AzureFWPolicy" {
  name                     = "azfw-policy"
  resource_group_name      = azurerm_resource_group.TF_RG.name
  location                 = azurerm_resource_group.TF_RG.location
  # sku                      = var.firewall_sku_tier
  sku                      = "Standard"
  threat_intelligence_mode = "Alert"
  # insights {
  #   enabled = true
  #   default_log_analytics_workspace_id = azurerm_log_analytics_workspace.TF_Logs_Analytics_Workspace_AzureFW.id
  # }
}


# IP Group for NC2 Subnets
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/ip_group
resource "azurerm_ip_group" "TF_nc2_ip_group" {
  name                = "nc2-ip-group"
  resource_group_name = azurerm_resource_group.TF_RG.name
  location            = azurerm_resource_group.TF_RG.location
  cidrs               = var.IPGroupNC2SubnetsCIDR
}

# Analytics workspace for Azure Firewall logs
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/log_analytics_workspace
resource "azurerm_log_analytics_workspace" "TF_Logs_Analytics_Workspace_AzureFW" {
  name                = var.LogAnalyticsWorkspaceAzureFWName
  location            = azurerm_resource_group.TF_RG.location
  resource_group_name = azurerm_resource_group.TF_RG.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  daily_quota_gb      = 1 # in GB
}

# Get available diagnostic categories for Azure Firewall
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/monitor_diagnostic_categories
data "azurerm_monitor_diagnostic_categories" "TF_Diagnostic_Setting_AzureFW_Categories" {
  resource_id = azurerm_firewall.TF_AzureFW.id
}


# Set diagnostic settings to send Azure Firewall logs to the Log Analytics workspace
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_diagnostic_setting
resource "azurerm_monitor_diagnostic_setting" "TF_Diagnostic_Setting_AzureFW" {
  name               = "DiagnosticSetting-AzureFW"
  target_resource_id = data.azurerm_monitor_diagnostic_categories.TF_Diagnostic_Setting_AzureFW_Categories.resource_id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.TF_Logs_Analytics_Workspace_AzureFW.id

  dynamic "metric" {
      for_each = data.azurerm_monitor_diagnostic_categories.TF_Diagnostic_Setting_AzureFW_Categories.metrics
      content {
        category = metric.value      
      }
    }

  dynamic "enabled_log" {
    for_each = data.azurerm_monitor_diagnostic_categories.TF_Diagnostic_Setting_AzureFW_Categories.log_category_types
    content {
      category = enabled_log.value
    }
  }

  # enabled_log {
  #   category = "AllLogs"
  # }

  # enabled_metric {
  #   category = "AllMetrics"
  # }
}

# Azure Firewall Policy Rule Collection Group with a Network Rule
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/firewall_policy_rule_collection_group
# https://learn.microsoft.com/en-us/azure/firewall/policy-rules-overview
# https://learn.microsoft.com/en-us/azure/firewall/policy-rule-collection-overview
# https://learn.microsoft.com/en-us/azure/firewall/policy-rule-collection-group-overview
# https://learn.microsoft.com/en-us/azure/firewall/policy-rules-overview#network-rules
#
# This rule allows all traffic from NC2 subnets to any destination
# this can/should be restricted based on security requirements
# cf. https://portal.nutanix.com/page/documents/solutions/details?targetId=TN-2156-NC2-on-Azure:tn-outbound-communication.html
#
resource "azurerm_firewall_policy_rule_collection_group" "net_policy_rule_collection_group" {
  name               = "DefaultNetworkRuleCollectionGroup"
  firewall_policy_id = azurerm_firewall_policy.TF_AzureFWPolicy.id
  priority           = 200
  network_rule_collection {
    name     = "DefaultNetworkRuleCollection"
    action   = "Allow"
    priority = 200
    rule {
      name                  = "AllowAll"
      protocols             = ["Any"]
      source_ip_groups      = [azurerm_ip_group.TF_nc2_ip_group.id]
      destination_ports     = ["*"]
      destination_addresses = ["*"]
    }
  }
}