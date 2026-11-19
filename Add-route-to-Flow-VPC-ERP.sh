
# 1. Créer la table de routage
  az network route-table create \
  --resource-group RG-NC2 \
  --name RT-FLOW-VPCS \
  --location germanywestcentral \
  --disable-bgp-route-propagation true


# 2. Ajouter les routes  
az network route-table route create \
  --resource-group RG-NC2 \
  --route-table-name RT-FLOW-VPCS \
  --name default-to-user-vpc-2-subnet1 \
  --address-prefix 192.168.201.0/24 \
  --next-hop-type VirtualAppliance \
  --next-hop-ip-address 192.168.12.54


# 3. Associer la table aux subnets du Spoke
az network vnet subnet update \
  --resource-group RG-NC2 \
  --vnet-name hub-vnet-germanywestcentral \
  --name GatewaySubnet \
  --route-table RT-FLOW-VPCS



-----------

# 1. Créer la table de routage pour le subnet AzureFirewall
  az network route-table create \
  --resource-group RG-NC2 \
  --name RT-AzureFirewall\
  --location germanywestcentral 
 # --disable-bgp-route-propagation true


# 2. Ajouter les routes  
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


# 3. Associer la table aux subnets du Spoke
az network vnet subnet update \
  --resource-group RG-NC2 \
  --vnet-name hub-vnet-germanywestcentral \
  --name AzureFirewallSubnet \
  --route-table RT-AzureFirewall


