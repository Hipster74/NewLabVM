# Setup Azureconnection
if (!(Get-AzureAccount).count -ge 1) {Add-AzureAccount}
#Get-AzureSubscription
#Select-AzureSubscription -SubscriptionName "Visual Studio Premium med MSDN"
$SubscriptionName = (Get-AzureSubscription)[0].SubscriptionName
$SubscriptionID = (Get-AzureSubscription)[0].SubscriptionId

#$AutomationAccountName = (New-AzureAutomationAccount -Name ManagedSystemsAutomation -Location "West Europe").AutomationAccountName
$AutomationAccountName = (Get-AzureAutomationAccount).AutomationAccountName

# Get Assets from Azure Automation
$CustomerTCStdAdDn = Get-AzureAutomationVariable -AutomationAccountName $AutomationAccountName -Name 'CMSetupVar-149999 Telecomputing Standard AD Base DN'
$CustomerADSrvFQDN = Get-AzureAutomationVariable -AutomationAccountName $AutomationAccountName -Name 'CMSetupVar-149999 Domain Controller FQDN'
$CMServersADGroup = Get-AzureAutomationVariable -AutomationAccountName $AutomationAccountName -Name 'CMSetupVar-149999 Telecomputing Standard CMServersgroup'

#$AzureAccount = "CMSetup"
$RBname = "New-LabSrv"
$Params = @{"Sourcefile"='D:\DownloadImages\REFWS2012R2-001.wim';"SrvSettingsXMLFile"="ad_srv_settings.xml";"VMName"='AD01';"VMLocation"='d:\VMs';"VMMemory"="2048";"IPAddress"='10.96.130.120';"DifforCreate"="CREATE";"VMType"="UEFI";"DomainOrWorkGroup"="WORKGROUP"}

$RBjob = Start-AzureAutomationRunbook -AutomationAccountName $AutomationAccountName -name $RBname -Parameters $Params -RunOn 'CSCLabHost' -Verbose

DO { 
    $RBjobId = Get-AzureAutomationJob -AutomationAccountName $AutomationAccountName -id $RBjob.Id 
    $RBjobstatus = $RBjobId.Status 
    } Until ($RBjobstatus -eq "Completed")

Get-AzureAutomationJobOutput -AutomationAccountName $AutomationAccountName -Id $RBjob.Id -stream Any

$RBname = "Configure-LabADSrvWF"
$Params = @{"VMName"="AD01";"VMCredential"='CMLabCred-SrvLocalAdmin';"SrvSettingsXMLFile"="ad_srv_settings.xml"}

$RBjob = Start-AzureAutomationRunbook -AutomationAccountName $AutomationAccountName -name $RBname -Parameters $Params -RunOn 'CSCLabHost' -Verbose

DO { 
    $RBjobId = Get-AzureAutomationJob -AutomationAccountName $AutomationAccountName -id $RBjob.Id 
    $RBjobstatus = $RBjobId.Status 
    } Until ($RBjobstatus -eq "Completed")

Get-AzureAutomationJobOutput -AutomationAccountName $AutomationAccountName -Id $RBjob.Id -stream Any

$RBname = "New-LabSrv"
$Params = @{"Sourcefile"='D:\DownloadImages\REFWS2012R2-001.wim';"SrvSettingsXMLFile"="cm_srv_settings.xml";"VMName"='CM01';"VMLocation"='d:\VMs';"VMMemory"="16384";"IPAddress"='DHCP';"DifforCreate"="CREATE";"VMType"="UEFI";"DomainOrWorkGroup"="DOMAIN"}

$RBjob = Start-AzureAutomationRunbook -AutomationAccountName $AutomationAccountName -name $RBname -Parameters $Params -RunOn 'CSCLabHost' -Verbose

DO { 
    $RBjobId = Get-AzureAutomationJob -AutomationAccountName $AutomationAccountName -id $RBjob.Id 
    $RBjobstatus = $RBjobId.Status 
    } Until ($RBjobstatus -eq "Completed")

Get-AzureAutomationJobOutput -AutomationAccountName $AutomationAccountName -Id $RBjob.Id -stream Any

#

$RBname = "Create-ADUser"
$Params = @{"NewUserCredentialAsset"="CMSetupCred-149999 NetworkAccessAccount";'FirstName'='Telecomputing';'LastName'='Serviceaccount';'Description'='ConfigurationManager Network Access Account';'CustomerDomainController'="AD01";'AdminRights'=$false;"SchemaAdminRights"=$false;'UserOU'="OU=ServiceAccounts,$(($CustomerTCStdAdDn).Value)";"VMCredential"='CMLabCred-SrvLocalAdmin'}

$RBjob = Start-AzureAutomationRunbook -AutomationAccountName $AutomationAccountName -name $RBname -Parameters $Params -RunOn 'CSCLabHost' -Verbose

DO { 
    $RBjobId = Get-AzureAutomationJob -AutomationAccountName $AutomationAccountName -id $RBjob.Id 
    $RBjobstatus = $RBjobId.Status 
    } Until ($RBjobstatus -eq "Completed")

Get-AzureAutomationJobOutput -AutomationAccountName $AutomationAccountName -Id $RBjob.Id -stream Any

#
$RBname = "Create-ADUser"
$Params = @{"NewUserCredentialAsset"="CMSetupCred-149999 SQL Service Account";'FirstName'='Telecomputing';'LastName'='Serviceaccount';'Description'='ConfigurationManager SQL Server Account';'CustomerDomainController'="AD01";'AdminRights'=$false;"SchemaAdminRights"=$false;'UserOU'="OU=ServiceAccounts,$(($CustomerTCStdAdDn).Value)";"VMCredential"='CMLabCred-SrvLocalAdmin'}

$RBjob = Start-AzureAutomationRunbook -AutomationAccountName $AutomationAccountName -name $RBname -Parameters $Params -RunOn 'CSCLabHost' -Verbose

DO { 
    $RBjobId = Get-AzureAutomationJob -AutomationAccountName $AutomationAccountName -id $RBjob.Id 
    $RBjobstatus = $RBjobId.Status 
    } Until ($RBjobstatus -eq "Completed")

Get-AzureAutomationJobOutput -AutomationAccountName $AutomationAccountName -Id $RBjob.Id -stream Any
#
$RBname = "Create-ADUser"
$Params = @{"NewUserCredentialAsset"="CMSetupCred-149999 CMInstaller Domainaccount";'FirstName'='Telecomputing';'LastName'='Serviceaccount';'Description'='Adminaccount used when running Configuration Manager installations';'CustomerDomainController'="AD01";'AdminRights'=$true;"SchemaAdminRights"=$true;'UserOU'="OU=ServiceAccounts,$(($CustomerTCStdAdDn).Value)";"VMCredential"='CMLabCred-SrvLocalAdmin'}

$RBjob = Start-AzureAutomationRunbook -AutomationAccountName $AutomationAccountName -name $RBname -Parameters $Params -RunOn 'CSCLabHost' -Verbose

DO { 
    $RBjobId = Get-AzureAutomationJob -AutomationAccountName $AutomationAccountName -id $RBjob.Id 
    $RBjobstatus = $RBjobId.Status 
    } Until ($RBjobstatus -eq "Completed")

Get-AzureAutomationJobOutput -AutomationAccountName $AutomationAccountName -Id $RBjob.Id -stream Any
#
$RBname = "Enable-CredSSP"
$Params = @{"VMName"="CM01";"VMCredential"='CMLabCred-SrvLocalAdmin'}

$RBjob = Start-AzureAutomationRunbook -AutomationAccountName $AutomationAccountName -name $RBname -Parameters $Params -RunOn 'CSCLabHost' -Verbose

DO { 
    $RBjobId = Get-AzureAutomationJob -AutomationAccountName $AutomationAccountName -id $RBjob.Id 
    $RBjobstatus = $RBjobId.Status 
    } Until ($RBjobstatus -eq "Completed")

Get-AzureAutomationJobOutput -AutomationAccountName $AutomationAccountName -Id $RBjob.Id -stream Any
#
$RBname = "Create-SourcefileDisk"
$Params = @{"VMName"="CM01";"VMCredential"='CMLabCred-SrvLocalAdmin';"SourcefilesDir"="D:\CMSetupSource";"DiskSizeInGB"=20}

$RBjob = Start-AzureAutomationRunbook -AutomationAccountName $AutomationAccountName -name $RBname -Parameters $Params -RunOn 'CSCLabHost' -Verbose

DO { 
    $RBjobId = Get-AzureAutomationJob -AutomationAccountName $AutomationAccountName -id $RBjob.Id 
    $RBjobstatus = $RBjobId.Status 
    } Until ($RBjobstatus -eq "Completed")

Get-AzureAutomationJobOutput -AutomationAccountName $AutomationAccountName -Id $RBjob.Id -stream Any
#
$RBname = "Create-CMShares"
$Params = @{"VMName"="CM01";'CMNetworkAccountCredential'="CMSetupCred-149999 NetworkAccessAccount";'CMSharesParentFolder'='c:\Shares';"VMCredential"='CMSetupCred-149999 CMInstaller Domainaccount'}

$RBjob = Start-AzureAutomationRunbook -AutomationAccountName $AutomationAccountName -name $RBname -Parameters $Params -RunOn 'CSCLabHost' -Verbose

DO { 
    $RBjobId = Get-AzureAutomationJob -AutomationAccountName $AutomationAccountName -id $RBjob.Id 
    $RBjobstatus = $RBjobId.Status 
    } Until ($RBjobstatus -eq "Completed")

Get-AzureAutomationJobOutput -AutomationAccountName $AutomationAccountName -Id $RBjob.Id -stream Any
#
$RBname = "Install-CMPrimarySiteWinFeatures"
$Params = @{"VMName"="CM01";"VMCredential"='CMSetupCred-149999 CMInstaller Domainaccount';"MacSupport"=$true}

$RBjob = Start-AzureAutomationRunbook -AutomationAccountName $AutomationAccountName -name $RBname -Parameters $Params -RunOn 'CSCLabHost' -Verbose

DO { 
    $RBjobId = Get-AzureAutomationJob -AutomationAccountName $AutomationAccountName -id $RBjob.Id 
    $RBjobstatus = $RBjobId.Status 
    } Until ($RBjobstatus -eq "Completed")

Get-AzureAutomationJobOutput -AutomationAccountName $AutomationAccountName -Id $RBjob.Id -stream Any
#
$RBname = "Install-WDS"
$Params = @{"VMName"="CM01";"VMCredential"='CMSetupCred-149999 CMInstaller Domainaccount'}

$RBjob = Start-AzureAutomationRunbook -AutomationAccountName $AutomationAccountName -name $RBname -Parameters $Params -RunOn 'CSCLabHost' -Verbose

DO { 
    $RBjobId = Get-AzureAutomationJob -AutomationAccountName $AutomationAccountName -id $RBjob.Id 
    $RBjobstatus = $RBjobId.Status 
    } Until ($RBjobstatus -eq "Completed")

Get-AzureAutomationJobOutput -AutomationAccountName $AutomationAccountName -Id $RBjob.Id -stream Any
#
$RBname = "Extend-ADSchema"
$Params = @{"VMName"="CM01";"VMCredential"='CMSetupCred-149999 CMInstaller Domainaccount';"SourceFilesParentDir"='e:\Source'}

$RBjob = Start-AzureAutomationRunbook -AutomationAccountName $AutomationAccountName -name $RBname -Parameters $Params -RunOn 'CSCLabHost' -Verbose

DO { 
    $RBjobId = Get-AzureAutomationJob -AutomationAccountName $AutomationAccountName -id $RBjob.Id 
    $RBjobstatus = $RBjobId.Status 
    } Until ($RBjobstatus -eq "Completed")

Get-AzureAutomationJobOutput -AutomationAccountName $AutomationAccountName -Id $RBjob.Id -stream Any
#
$RBname = "Create-SysmanContainer"
$Params = @{"VMName"="AD01";"VMCredential"='CMSetupCred-149999 CMInstaller Domainaccount';"CMServersADGroup"="$(($CMServersADGroup).value)";"CMServersADGroupOU"="OU=Resources,$(($CustomerTCStdAdDn).value)";"CustomerCMSrvHostname"="CM01"}

$RBjob = Start-AzureAutomationRunbook -AutomationAccountName $AutomationAccountName -name $RBname -Parameters $Params -RunOn 'CSCLabHost' -Verbose

DO { 
    $RBjobId = Get-AzureAutomationJob -AutomationAccountName $AutomationAccountName -id $RBjob.Id 
    $RBjobstatus = $RBjobId.Status 
    } Until ($RBjobstatus -eq "Completed")

Get-AzureAutomationJobOutput -AutomationAccountName $AutomationAccountName -Id $RBjob.Id -stream Any
#
$RBname = "Restart-VM"
$Params = @{"VMName"="CM01";"VMCredential"='CMSetupCred-149999 CMInstaller Domainaccount'}

$RBjob = Start-AzureAutomationRunbook -AutomationAccountName $AutomationAccountName -name $RBname -Parameters $Params -RunOn 'CSCLabHost' -Verbose

DO { 
    $RBjobId = Get-AzureAutomationJob -AutomationAccountName $AutomationAccountName -id $RBjob.Id 
    $RBjobstatus = $RBjobId.Status 
    } Until ($RBjobstatus -eq "Completed")

Get-AzureAutomationJobOutput -AutomationAccountName $AutomationAccountName -Id $RBjob.Id -stream Any
#
$RBname = "Install-MDT2013U1"
$Params = @{"VMName"="CM01";"VMCredential"='CMSetupCred-149999 CMInstaller Domainaccount';"SourceFilesParentDir"='e:\Source'}

$RBjob = Start-AzureAutomationRunbook -AutomationAccountName $AutomationAccountName -name $RBname -Parameters $Params -RunOn 'CSCLabHost' -Verbose

DO { 
    $RBjobId = Get-AzureAutomationJob -AutomationAccountName $AutomationAccountName -id $RBjob.Id 
    $RBjobstatus = $RBjobId.Status 
    } Until ($RBjobstatus -eq "Completed")

Get-AzureAutomationJobOutput -AutomationAccountName $AutomationAccountName -Id $RBjob.Id -stream Any
#
$RBname = "Install-ADK10"
$Params = @{"VMName"="CM01";"VMCredential"='CMSetupCred-149999 CMInstaller Domainaccount';"SourceFilesParentDir"='e:\Source'}

$RBjob = Start-AzureAutomationRunbook -AutomationAccountName $AutomationAccountName -name $RBname -Parameters $Params -RunOn 'CSCLabHost' -Verbose

DO { 
    $RBjobId = Get-AzureAutomationJob -AutomationAccountName $AutomationAccountName -id $RBjob.Id 
    $RBjobstatus = $RBjobId.Status 
    } Until ($RBjobstatus -eq "Completed")

Get-AzureAutomationJobOutput -AutomationAccountName $AutomationAccountName -Id $RBjob.Id -stream Any
#
$RBname = "Install-CMSQLSrv"
$Params = @{"VMName"="CM01";"VMCredential"='CMSetupCred-149999 CMInstaller Domainaccount';"SourceFilesParentDir"='e:\Source';"SQLSrvUnattendName"='CMSetupVar-149999 SQLserver 2014 Unattend';"CMSQLServiceAccountCredential"="CMSetupCred-149999 SQL Service Account";"CMSQLServerSAAccountCredential"="CMSetupCred-149999 SQL SA Account"}

$RBjob = Start-AzureAutomationRunbook -AutomationAccountName $AutomationAccountName -name $RBname -Parameters $Params -RunOn 'CSCLabHost' -Verbose

DO { 
    $RBjobId = Get-AzureAutomationJob -AutomationAccountName $AutomationAccountName -id $RBjob.Id 
    $RBjobstatus = $RBjobId.Status 
    } Until ($RBjobstatus -eq "Completed")

Get-AzureAutomationJobOutput -AutomationAccountName $AutomationAccountName -Id $RBjob.Id -stream Any
#
$RBname = "Restart-VM"
$Params = @{"VMName"="CM01";"VMCredential"='CMSetupCred-149999 CMInstaller Domainaccount'}

$RBjob = Start-AzureAutomationRunbook -AutomationAccountName $AutomationAccountName -name $RBname -Parameters $Params -RunOn 'CSCLabHost' -Verbose

DO { 
    $RBjobId = Get-AzureAutomationJob -AutomationAccountName $AutomationAccountName -id $RBjob.Id 
    $RBjobstatus = $RBjobId.Status 
    } Until ($RBjobstatus -eq "Completed")

Get-AzureAutomationJobOutput -AutomationAccountName $AutomationAccountName -Id $RBjob.Id -stream Any
#
$RBname = "Install-CM2012SP2"
$Params = @{"VMName"="CM01";"VMCredential"='CMSetupCred-149999 CMInstaller Domainaccount';"SourceFilesParentDir"='e:\Source';"CM2012SP2UnattendName"='CMSetupVar-149999 Configuration Manager 2012 Unattend'}

$RBjob = Start-AzureAutomationRunbook -AutomationAccountName $AutomationAccountName -name $RBname -Parameters $Params -RunOn 'CSCLabHost' -Verbose

DO { 
    $RBjobId = Get-AzureAutomationJob -AutomationAccountName $AutomationAccountName -id $RBjob.Id 
    $RBjobstatus = $RBjobId.Status 
    } Until ($RBjobstatus -eq "Completed")

Get-AzureAutomationJobOutput -AutomationAccountName $AutomationAccountName -Id $RBjob.Id -stream Any
#
$RBname = "Install-CM2012R2SP1"
$Params = @{"VMName"="CM01";"VMCredential"='CMSetupCred-149999 CMInstaller Domainaccount';"SourceFilesParentDir"='e:\Source'}

$RBjob = Start-AzureAutomationRunbook -AutomationAccountName $AutomationAccountName -name $RBname -Parameters $Params -RunOn 'CSCLabHost' -Verbose

DO { 
    $RBjobId = Get-AzureAutomationJob -AutomationAccountName $AutomationAccountName -id $RBjob.Id 
    $RBjobstatus = $RBjobId.Status 
    } Until ($RBjobstatus -eq "Completed")

Get-AzureAutomationJobOutput -AutomationAccountName $AutomationAccountName -Id $RBjob.Id -stream Any
#
$RBname = "Install-CM2012R2SP1CU2"
$Params = @{"VMName"="CM01";"VMCredential"='CMSetupCred-149999 CMInstaller Domainaccount';"SourceFilesParentDir"='e:\Source'}

$RBjob = Start-AzureAutomationRunbook -AutomationAccountName $AutomationAccountName -name $RBname -Parameters $Params -RunOn 'CSCLabHost' -Verbose

DO { 
    $RBjobId = Get-AzureAutomationJob -AutomationAccountName $AutomationAccountName -id $RBjob.Id 
    $RBjobstatus = $RBjobId.Status 
    } Until ($RBjobstatus -eq "Completed")

Get-AzureAutomationJobOutput -AutomationAccountName $AutomationAccountName -Id $RBjob.Id -stream Any