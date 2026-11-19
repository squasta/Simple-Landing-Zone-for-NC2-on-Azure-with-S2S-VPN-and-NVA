

# A Network Interface for Azure Windows VM
# cf. https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_interface
resource "azurerm_network_interface" "TF_VM_Jumbox_Nic" {
  count               = var.EnableJumboxVM
  name                = var.VMBastionNicName
  location            = azurerm_resource_group.TF_RG.location
  resource_group_name = azurerm_resource_group.TF_RG.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.TF_HubSubnet.id
    private_ip_address_allocation = "Dynamic"
  }
}


# A Windows Virtual Machine for Bastion
# cf. https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/windows_virtual_machine
resource "azurerm_windows_virtual_machine" "TF_VM_Jumbox" {
  count                 = var.EnableJumboxVM
  name                  = var.VMJumpboxName
  resource_group_name   = azurerm_resource_group.TF_RG.name
  location              = azurerm_resource_group.TF_RG.location
  size                  = var.AzureVMSize    # B2ms or greater is better for good experience
  admin_username        = var.AdminUsername
  admin_password        = var.AdminPassword
  network_interface_ids = [azurerm_network_interface.TF_VM_Jumbox_Nic[0].id]
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2025-Datacenter"
    version   = "latest"
  }
  computer_name = var.HostnameVMJumbox
  provision_vm_agent = true
  patch_mode = "AutomaticByOS"
  timezone = "W. Europe Standard Time"
  tags = {
    usage = "Jumpbox with Azure Bastion"
  }
}
