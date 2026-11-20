
##################################################################################################
# Route to Flow VPC ERP (Externally Routable Prefixes) in Azure Hub VNet for GatewaySubnet       #
##################################################################################################

# 1. Create an Azure Route Table for AzureGatewaySubnet (it can be also used by other subnets like HubSubnet)
  az network route-table create \
  --resource-group RG-NC2 \
  --name RT-FLOW-VPCS \
  --location germanywestcentral \
  --disable-bgp-route-propagation true


# 2. Add routes to Nutanix Flow CIDRs (aka ERP : Externally Routable Prefixes)    
az network route-table route create \
  --resource-group RG-NC2 \
  --route-table-name RT-FLOW-VPCS \
  --name default-to-user-vpc-2-subnet1 \
  --address-prefix 192.168.201.0/24 \
  --next-hop-type VirtualAppliance \
  --next-hop-ip-address 192.168.12.54


# 3. Associate Azure Route Table to GatewaySubnet in Azure Hub VNet
az network vnet subnet update \
  --resource-group RG-NC2 \
  --vnet-name hub-vnet-germanywestcentral \
  --name GatewaySubnet \
  --route-table RT-FLOW-VPCS





#################################################################################################################
# Route to Flow VPC ERP (Externally Routable Prefixes) & to Internet in Azure Hub VNet for AzureFirewallSubnet  #
#################################################################################################################

# 1. Create an Azure Route Table for AzureFirewall subnet
  az network route-table create \
  --resource-group RG-NC2 \
  --name RT-AzureFirewall\
  --location germanywestcentral 
 # --disable-bgp-route-propagation true


# 2. Add routes to Nutanix Flow CIDRs and to Internet 
az network route-table route create \
  --resource-group RG-NC2 \
  --route-table-name RT-AzureFirewall \
  --name default-to-user-vpc-2-subnet1 \
  --address-prefix 192.168.201.0/24 \
  --next-hop-type VirtualAppliance \
  --next-hop-ip-address 192.168.12.54

az network route-table route create \
  --resource-group RG-NC2 \
  --route-table-name RT-AzureFirewall \
  --name default-to-Internet \
  --address-prefix 0.0.0.0/0 \
  --next-hop-type Internet


# 3. Associate Azure Route Table to AzureFirewallSubnet in Azure Hub VNet
az network vnet subnet update \
  --resource-group RG-NC2 \
  --vnet-name hub-vnet-germanywestcentral \
  --name AzureFirewallSubnet \
  --route-table RT-AzureFirewall


