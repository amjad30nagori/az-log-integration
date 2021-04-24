# Common Parameters

$prefix="az"
$IPRange="172.0.0.0/25"
$location="eastus2"
$supportpath="./"
$eventhubretention = 2

# Splunk Parameters for Logic App configuration

$splunkuser="root"
$splunkpass="Password@123"
$splunkchannel="1234568790"
$splunkport=8089

# Virtual machines parameters

$vmsize="Standard_DS1_v2"
$username="newuser1"
$password="Password@123"

# Resource Group

$splunkrg=New-AzResourceGroup -Name "$prefix-splunk-rg" -Location $location
$jumprg=New-AzResourceGroup -Name "$prefix-jump-rg" -Location $location

# Network Security Groups

$splunknsg=New-AzNetworkSecurityGroup -Name "$prefix-splunk-snet-nsg" -ResourceGroupName $splunkrg.ResourceGroupName -Location $location
$jumpnsg=New-AzNetworkSecurityGroup -Name "$prefix-jump-snet-nsg" -ResourceGroupName $jumprg.ResourceGroupName -Location $location

# Subnet Configuration

$IPRangeC=$IPRange.Remove($IPRange.Length -3)
$IPRange0splunk=$IPRangeC

$octets = $IPRangeC.Split(".")                        # or $octets = $IP -split "\."
$octets[2] = [string]([int]$octets[2] + 0)      # or other manipulation of the third octet
$IPRange2 = $octets -join "."

$IPRange1splunk=$IPRange2

$IPRange1Prodjump=$IPRange2.Split('.')
$IPRange1Prodjump[-1]=64
$IPRange1Prodjump=$IPRange1Prodjump -join '.'


$Snet0splunk = New-AzVirtualNetworkSubnetConfig -Name "$prefix-vnet-splunk-snet" -AddressPrefix "$IPRange0splunk/26" -NetworkSecurityGroup $splunknsg -ServiceEndpoint Microsoft.KeyVault, Microsoft.Storage, Microsoft.EventHub  -WarningAction Ignore
$Snet0jump = New-AzVirtualNetworkSubnetConfig -Name "$prefix-vnet-jump-snet" -AddressPrefix "$IPRange1Prodjump/26" -NetworkSecurityGroup $jumpnsg -ServiceEndpoint Microsoft.KeyVault, Microsoft.Storage, Microsoft.EventHub -WarningAction Ignore


# Virtual Network

$Vnet=New-AzVirtualNetwork -Name "$prefix-vnet" -ResourceGroupName $splunkrg.ResourceGroupName -Location $location -AddressPrefix $IPRange -Subnet $Snet0splunk,$Snet0jump -WarningAction Ignore

# Jump Server Deployment

$vmName = $prefix+"jump"+"vm01"
$rgname = $jumprg.ResourceGroupName
$nicName = "$vmname-nic-01"
$diskName = "$vmname-OsDisk-01"
$pip = $vmName+"-pip"

    # Credentials
$secpasswd = ConvertTo-SecureString $password -AsPlainText -Force
$mycreds = New-Object System.Management.Automation.PSCredential ($username, $secpasswd)

    # NIC setup
$subnet=Get-AzVirtualNetworkSubnetConfig -Name $Snet0jump.name -VirtualNetwork $vnet
$publicip=New-AzPublicIpAddress -ResourceGroupName $rgname -Name $pip -Location $location -AllocationMethod Dynamic -SKU Basic -WarningAction Ignore
$jumpnic = New-AzNetworkInterface -Name $nicName -ResourceGroupName $rgName -Location $location -Subnet $subnet -PublicIpAddress $publicip

    # VM Config
$vm = New-AzVMConfig -VMName $vmname -VMSize $vmsize
$vm = Set-AzVMOperatingSystem -VM $vm -Windows -ComputerName $vmname -Credential $mycreds -ProvisionVMAgent
$vm = Add-AzVMNetworkInterface -VM $vm -Id $jumpnic.Id
$vm = Set-AzVMSourceImage -VM $vm -PublisherName 'MicrosoftWindowsDesktop' -Offer 'Windows-10' -Skus '20h1-pro' -Version latest
$vm = Set-AzVMBootDiagnostic -VM $vm -Disable
$vm = Set-AzVMOSDisk -VM $vm -Name $diskname -CreateOption fromImage -StorageAccountType Standard_LRS

    # VM Creation
New-AzVM -ResourceGroupName $rgname -Location $location -VM $vm

    # NIC Static
$jumpnic.IpConfigurations[0].PrivateIpAllocationMethod='Static'
Set-AzNetworkInterface -NetworkInterface $jumpnic

# Splunk Server Deployment

$vmName = $prefix+"splunk"+"vm01"
$rgname = $splunkrg.ResourceGroupName
$nicName = "$vmname-nic-01"
$diskName = "$vmname-OsDisk-01"
$datadiskName = "$vmname-DataDisk-01"
$pip=$vmname+"-pip"


    # Credentials
$secpasswd = ConvertTo-SecureString $password -AsPlainText -Force
$mycreds = New-Object System.Management.Automation.PSCredential ($username, $secpasswd)

    # NIC setup
$subnet=Get-AzVirtualNetworkSubnetConfig -Name $Snet0splunk.name -VirtualNetwork $vnet
$publicip=New-AzPublicIpAddress -ResourceGroupName $rgname -Name $pip -Location $location -AllocationMethod Dynamic -SKU Basic -WarningAction Ignore
$splunknic = New-AzNetworkInterface -Name $nicName -ResourceGroupName $rgName -Location $location -Subnet $subnet -PublicIpAddress $publicip


    # Data Disk
$datadiskconfig = New-AzDiskConfig -SkuName Standard_LRS -Location $location -CreateOption Empty -DiskSizeGB 127
$vmDataDisk01 = New-AzDisk -DiskName $datadiskName -Disk $datadiskconfig -ResourceGroupName $splunkrg.resourcegroupname


    # VM Config
$vm = New-AzVMConfig -VMName $vmname -VMSize $vmsize
$vm = Set-AzVMOperatingSystem -VM $vm -Linux -ComputerName $vmname -Credential $mycreds
$vm = Add-AzVMNetworkInterface -VM $vm -Id $splunknic.Id
$vm = Set-AzVMSourceImage -VM $vm -PublisherName 'RedHat' -Offer 'RHEL' -Skus '8.2' -Version latest
$vm = Set-AzVMBootDiagnostic -VM $vm -Disable
$vm = Set-AzVMOSDisk -VM $vm -Name $diskname -CreateOption fromImage -StorageAccountType Standard_LRS
$vm = Add-AzVMDataDisk -VM $vm -Name $datadiskName -CreateOption Attach -ManagedDiskId $vmDataDisk01.Id -Lun 0

    # VM Creation
New-AzVM -ResourceGroupName $rgname -Location $location -VM $vm

    # NIC Static
$splunknic.IpConfigurations[0].PrivateIpAllocationMethod='Static'
Set-AzNetworkInterface -NetworkInterface $splunknic


# Splunk Script Deployment
#Set-Location -Path $supportpath

Invoke-AzVMRunCommand -ResourceGroupName $rgname -Name $vmName -CommandId 'RunShellScript' -ScriptPath .\SplunkDeployScript.sh -AsJob

# Security Rule to Allow RDP

$jumpserverip = ($jumpnic.IpConfigurations | Select-Object PrivateIpaddress).privateipaddress
$splunkserverip = ($splunknic.IpConfigurations | Select-Object PrivateIpaddress).privateipaddress

$jumpnsg | Add-AzNetworkSecurityRuleConfig -Name "rdp-allowed" -Protocol * -SourcePortRange * -DestinationPortRange 3389 -SourceAddressPrefix * -DestinationAddressPrefix $jumpserverip -Access Allow -Priority 4096 -Direction Inbound
$splunknsg | Add-AzNetworkSecurityRuleConfig -Name "rdp-allowed" -Protocol * -SourcePortRange * -DestinationPortRange 22 -SourceAddressPrefix * -DestinationAddressPrefix $splunkserverip -Access Allow -Priority 4096 -Direction Inbound
$splunknsg | Set-AzNetworkSecurityGroup
$jumpnsg | Set-AzNetworkSecurityGroup

# Event Hub Namespace
$randomsuffix = Get-Random
$namespacename = $prefix+"ns"+$randomsuffix
$namespace = New-AzEventHubNamespace -ResourceGroupName $splunkrg.ResourceGroupName -NamespaceName $namespacename -Location $location -WarningAction Ignore

# Event Log Profile

$namespacerule=Get-AzEventHubAuthorizationRule -ResourceGroupName $splunkrg.ResourceGroupName -Namespace $namespacename

# Settings needed for the new log profile
$logProfileName = $prefix+"SplunkLogProfile"
$locations = (Get-AzLocation).Location
$locations += "global"
$resourceGroupName = $splunkrg.ResourceGroupName
$eventHubNamespace = $namespacename

# Configure Log Profile to send logs to EvenHub directly.

Add-AzLogProfile -Name $logProfileName -Location $locations -ServiceBusRuleId $namespacerule.Id -RetentionInDays $eventhubretention -WarningAction Ignore

#Logic App Definition

$splunkrgname=$splunkrg.ResourceGroupName
$subsid=(Get-AzContext).Subscription.id
$logicappname="$prefix-logicapp"
$splunkuri="http://"+$splunkserverip+":"+"$splunkport"+"/services/collector/raw"
$apiconnectionexternalid="/subscriptions/$subsid/resourceGroups/$splunkrgname/providers/Microsoft.Web/connections/eventhubs"
$apiconnectioninternalid="/subscriptions/$subsid/providers/Microsoft.Web/locations/$location/managedApis/eventhubs"

$definition = Get-Content .\SupportedFiles\LogicApp.json -raw | ConvertFrom-Json

$definition.parameters.workflows_az1_logicapp_name.defaultValue = $logicappname
$definition.parameters.connections_eventhubs_externalid.defaultValue = $apiconnectionexternalid
$definition.resources[0].location = $location
$definition.resources[0].properties.definition.actions.HTTP.inputs.uri=$splunkuri
$definition.resources[0].properties.definition.actions.HTTP.inputs.authentication.username=$splunkuser
$definition.resources[0].properties.definition.actions.HTTP.inputs.authentication.password=$splunkpass
$definition.resources[0].properties.definition.actions.HTTP.inputs.headers.'X-Splunk-Request-Channel'=$splunkchannel
$definition.resources[0].properties.parameters.'$connections'.value.eventhubs.id = $apiconnectioninternalid
$defition= $definition | ConvertTo-Json -depth 32 | Set-Content .\SupportedFiles\LogicApp_Updated.json -Force

# Api Connection

$nsendpoint=(Get-AzEventHubKey -ResourceGroupName $splunkrg.ResourceGroupName -NamespaceName $namespace.Name -AuthorizationRuleName $namespacerule.Name).PrimaryConnectionString

$eventhubconnection = Get-Content .\SupportedFiles\ApiConnection.json -raw | ConvertFrom-Json

$eventhubconnection.resources[0].properties.api.id = $eventhubconnection.resources[0].properties.api.id.Replace("<subsid>",$subsid)
$eventhubconnection.resources[0].properties.api.id = $eventhubconnection.resources[0].properties.api.id.Replace("<location>",$location)
$eventhubconnection.resources[0].location = $location
$eventhubconnection.resources[0].properties.parameterValues.connectionString = $nsendpoint
$eventhubconnection | ConvertTo-Json -depth 32 | Set-Content .\SupportedFiles\ApiConnection_Updated.json -Force


New-AzResourceGroupDeployment -Name "apiconnection" -ResourceGroupName $splunkrg.ResourceGroupName -TemplateFile .\SupportedFiles\ApiConnection_Updated.json -Force

New-AzResourceGroupDeployment -Name "logicapp" -ResourceGroupName $splunkrg.ResourceGroupName -TemplateFile .\SupportedFiles\LogicApp_Updated.json -Force

#------------------------------------------End----------------------------------------------------#