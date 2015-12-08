Workflow Install-LabMain {
	Param(
		[Parameter(Mandatory=$true)]
		[int]$CustomerNumber,
		[Parameter(Mandatory=$true)]
		[int]$Template,
		[Parameter(Mandatory=$true)]
		[string]$CustomerCMSiteCode
	)
	$AutomationAccountName = 'ManagedSystemsAutomation'
	$AzureSubscriptionName = 'Visual Studio Premium med MSDN'
	$AzureCredential = Get-AutomationPSCredential -Name 'AzureOrgIdCredential'
	$HybridWorkerGroup = 'CSCLabHost'

	$CustomerName = 'Telecomputing'
	$CustomerDomain = "tclab.local"
	$CustomerDomainNetBiosName = "tclab"
	$CustomerCMSrvHostname = "$CustomerNumber-CM01"
	#$CustomerCMSiteCode = 'P99'
	$CustomerADSrvHostname = "$CustomerNumber-AD01"
	$CustomerDomainControllerFQDN = "$CustomerNumber-AD01.$CustomerDomain"
	$CustomerTCStdAdDn = "OU=$CustomerNumber,OU=Customers,OU=$CustomerNumber" + 'ARN,OU=ASP'

	$VMPath = 'd:\VMs' # Path to VM files on Hybrid worker(Hyper-v host)
	$VMSrvOSImageDestination = 'D:\DownloadImages\REFWS2012R2-001.wim' # Path to ServerOS WIMImage on Hybrid worker(Hyper-v host) 
	$SourceFilesDestination = 'e:\Source' # Installationsfiles(SQL,CM, MDT etc.) goes to this folder in CMsrv

	$CMProductCode = 'BXH69-M62YX-QQD6R-3GPWX-8WMFY' # Telecomputings System Center licensekey
	$CMPrerequisitePath = "$SourceFilesDestination\SystemCenter\ConfigMgr2012wSP2PreReqs"
	$CMInstallDir = 'c:\ConfigMgr'
	$CMSharesParentFolder = 'c:\Shares'
	$CMServersADGroup = "_$CustomerNumber-ConfigMgrServers"
	$CMServersSettingsXML = "cm_srv_settings.xml"
	$CMServerIP = '10.96.130.9'

	$ADServersSettingsXML = "ad_srv_settings.xml"
	$ADServerIP = '10.96.130.8'

	$UniversalPassword = 'P@ssw0rd'
	$UniversalPasswordSecureString = ConvertTo-SecureString $UniversalPassword -AsPlainText -Force
	
	$CMSetupInstallerAccountUsername = "$CustomerDomainNetBiosName\__$CustomerNumber-CMInstaller"
	$CMSetupInstallerCred = New-Object System.Management.Automation.PSCredential ($CMSetupInstallerAccountUsername, $UniversalPasswordSecureString)

	$CMNetworkAccountUsername = "$CustomerDomainNetBiosName\__$CustomerNumber-R-NwAAcc"
	$CMNwAACCCred = New-Object System.Management.Automation.PSCredential ($CMNetworkAccountUsername, $UniversalPasswordSecureString)

	$CMPushInstallAccountUsername = "$CustomerDomainNetBiosName\__$CustomerNumber-R-Push"
	$CMPushInstallCred = New-Object System.Management.Automation.PSCredential ($CMPushInstallAccountUsername, $UniversalPasswordSecureString)

	$CMSQLServiceAccountUsername = "$CustomerDomainNetBiosName\__$CustomerNumber" + 'sqlsvc-mirro'
	$CMSQLServiceAccountCred = New-Object System.Management.Automation.PSCredential ($CMSQLServiceAccountUsername, $UniversalPasswordSecureString)

	$CMSQLServerSAAccountUsername = 'SA'
	$CMSQLServerSAAccountCred = New-Object System.Management.Automation.PSCredential ($CMSQLServerSAAccountUsername, $UniversalPasswordSecureString)

	# Execution start timestamp
	[datetime]$StartRun = Get-Date
	Configure-Assets `
	-CustomerNumber $CustomerNumber -CustomerName $CustomerName -AzureOrgIdCredential $AzureCredential -AzureSubscriptionName $AzureSubscriptionName -AutomationAccountName $AutomationAccountName -CMSetupInstallerCred $CMSetupInstallerCred -CMNwAACCCred $CMNwAACCCred -CMPushInstallCred $CMPushInstallCred -CMSQLServiceAccountCred $CMSQLServiceAccountCred -CMSQLServerSAAccountCred $CMSQLServerSAAccountCred -CMProductCode $CMProductCode -CustomerCMSiteCode $CustomerCMSiteCode -CustomerCMSrvHostname $CustomerCMSrvHostname -CustomerDomain $CustomerDomain -CMInstallDir $CMInstallDir -CMPrerequisitePath $CMPrerequisitePath

	$ChildRunbookName = "New-LabSrv"
    $ChildRunbookInputParams = @{"Sourcefile"="$VMSrvOSImageDestination";"SrvSettingsXMLFile"="$ADServersSettingsXML";"VMName"="$CustomerADSrvHostname";"VMLocation"="$VMPath";"VMMemory"="2048";"IPAddress"="$ADServerIP";"DifforCreate"="CREATE";"VMType"="UEFI";"DomainOrWorkGroup"="WORKGROUP";"Force"=$true}
	Start-HybridChildRunbook -ChildRunbookName $ChildRunbookName -ChildRunbookInputParams $ChildRunbookInputParams -AzureOrgIdCredential $AzureCredential -AzureSubscriptionName $AzureSubscriptionName -AutomationAccountName $AutomationAccountName -WaitForJobCompletion:$true -ReturnJobOutput:$true -HybridWorkerGroup $HybridWorkerGroup -JobPollingTimeoutInSeconds 1800
	
	$ChildRunbookName = "Configure-LabADSrvWF"
	$ChildRunbookInputParams = @{"VMName"="$CustomerADSrvHostname";"VMCredential"='CMLabCred-SrvLocalAdmin';"SrvSettingsXMLFile"="$ADServersSettingsXML"}
	Start-HybridChildRunbook -ChildRunbookName $ChildRunbookName -ChildRunbookInputParams $ChildRunbookInputParams -AzureOrgIdCredential $AzureCredential -AzureSubscriptionName $AzureSubscriptionName -AutomationAccountName $AutomationAccountName -WaitForJobCompletion:$true -ReturnJobOutput:$true -HybridWorkerGroup $HybridWorkerGroup -JobPollingTimeoutInSeconds 1200

	# Checkpoint Workflow, credentials must be cleared and reassigned for Workflow resume to work
	$AzureCredential = $null
	Checkpoint-Workflow
	$AzureCredential = Get-AutomationPSCredential -Name 'AzureOrgIdCredential'
	
	$ChildRunbookName = "New-LabSrv"
    $ChildRunbookInputParams = @{"Sourcefile"="$VMSrvOSImageDestination";"SrvSettingsXMLFile"="$CMServersSettingsXML";"VMName"="$CustomerCMSrvHostname";"VMLocation"="$VMPath";"VMMemory"="16384";"IPAddress"="$CMServerIP";"DifforCreate"="CREATE";"VMType"="UEFI";"DomainOrWorkGroup"="DOMAIN";"Force"=$true}
	Start-HybridChildRunbook -ChildRunbookName $ChildRunbookName -ChildRunbookInputParams $ChildRunbookInputParams -AzureOrgIdCredential $AzureCredential -AzureSubscriptionName $AzureSubscriptionName -AutomationAccountName $AutomationAccountName -WaitForJobCompletion:$true -ReturnJobOutput:$true -HybridWorkerGroup $HybridWorkerGroup -JobPollingTimeoutInSeconds 1800
	
	# Checkpoint Workflow, credentials must be cleared and reassigned for Workflow resume to work
	$AzureCredential = $null
	Checkpoint-Workflow
	$AzureCredential = Get-AutomationPSCredential -Name 'AzureOrgIdCredential'
	
	$ChildRunbookName = "Create-ADUser"
    $ChildRunbookInputParams = @{"NewUserCredentialAsset"="CMSetupCred-$CustomerNumber NetworkAccessAccount";'FirstName'='Telecomputing';'LastName'='Serviceaccount';'Description'='ConfigurationManager Network Access Account';'CustomerDomainController'="$CustomerADSrvHostname";'AdminRights'=$false;"SchemaAdminRights"=$false;'UserOU'="OU=ServiceAccounts,$CustomerTCStdAdDn";"VMCredential"='CMLabCred-SrvLocalAdmin'}
	Start-HybridChildRunbook -ChildRunbookName $ChildRunbookName -ChildRunbookInputParams $ChildRunbookInputParams -AzureOrgIdCredential $AzureCredential -AzureSubscriptionName $AzureSubscriptionName -AutomationAccountName $AutomationAccountName -WaitForJobCompletion:$true -ReturnJobOutput:$true -HybridWorkerGroup $HybridWorkerGroup
	
	$ChildRunbookName = "Create-ADUser"
    $ChildRunbookInputParams = @{"NewUserCredentialAsset"="CMSetupCred-$CustomerNumber PushInstallationAccount";'FirstName'='Telecomputing';'LastName'='Serviceaccount';'Description'='ConfigurationManager Push Installation Account';'CustomerDomainController'="$CustomerADSrvHostname";'AdminRights'=$true;"SchemaAdminRights"=$false;'UserOU'="OU=ServiceAccounts,$CustomerTCStdAdDn";"VMCredential"='CMLabCred-SrvLocalAdmin'}
	Start-HybridChildRunbook -ChildRunbookName $ChildRunbookName -ChildRunbookInputParams $ChildRunbookInputParams -AzureOrgIdCredential $AzureCredential -AzureSubscriptionName $AzureSubscriptionName -AutomationAccountName $AutomationAccountName -WaitForJobCompletion:$true -ReturnJobOutput:$true -HybridWorkerGroup $HybridWorkerGroup

	$ChildRunbookName = "Create-ADUser"
    $ChildRunbookInputParams = @{"NewUserCredentialAsset"="CMSetupCred-$CustomerNumber SQL Service Account";'FirstName'='Telecomputing';'LastName'='Serviceaccount';'Description'='ConfigurationManager SQL Server Account';'CustomerDomainController'="$CustomerADSrvHostname";'AdminRights'=$false;"SchemaAdminRights"=$false;'UserOU'="OU=ServiceAccounts,$CustomerTCStdAdDn";"VMCredential"='CMLabCred-SrvLocalAdmin'}
	Start-HybridChildRunbook -ChildRunbookName $ChildRunbookName -ChildRunbookInputParams $ChildRunbookInputParams -AzureOrgIdCredential $AzureCredential -AzureSubscriptionName $AzureSubscriptionName -AutomationAccountName $AutomationAccountName -WaitForJobCompletion:$true -ReturnJobOutput:$true -HybridWorkerGroup $HybridWorkerGroup
	
	$ChildRunbookName = "Create-ADUser"
    $ChildRunbookInputParams = @{"NewUserCredentialAsset"="CMSetupCred-$CustomerNumber CMInstaller Domainaccount";'FirstName'='Telecomputing';'LastName'='Serviceaccount';'Description'='Adminaccount used when running Configuration Manager installations';'CustomerDomainController'="$CustomerADSrvHostname";'AdminRights'=$true;"SchemaAdminRights"=$true;'UserOU'="OU=ServiceAccounts,$CustomerTCStdAdDn";"VMCredential"='CMLabCred-SrvLocalAdmin'}
	Start-HybridChildRunbook -ChildRunbookName $ChildRunbookName -ChildRunbookInputParams $ChildRunbookInputParams -AzureOrgIdCredential $AzureCredential -AzureSubscriptionName $AzureSubscriptionName -AutomationAccountName $AutomationAccountName -WaitForJobCompletion:$true -ReturnJobOutput:$true -HybridWorkerGroup $HybridWorkerGroup
	
	$ChildRunbookName = "Create-ADOU"
    $ChildRunbookInputParams = @{'CustomerDomainController'="$CustomerADSrvHostname";'OU'="OU=Laptops,OU=Computers,$CustomerTCStdAdDn";"VMCredential"='CMLabCred-SrvLocalAdmin'}
	Start-HybridChildRunbook -ChildRunbookName $ChildRunbookName -ChildRunbookInputParams $ChildRunbookInputParams -AzureOrgIdCredential $AzureCredential -AzureSubscriptionName $AzureSubscriptionName -AutomationAccountName $AutomationAccountName -WaitForJobCompletion:$true -ReturnJobOutput:$true -HybridWorkerGroup $HybridWorkerGroup
	
	$ChildRunbookName = "Create-ADOU"
    $ChildRunbookInputParams = @{'CustomerDomainController'="$CustomerADSrvHostname";'OU'="OU=Desktops,OU=Computers,$CustomerTCStdAdDn";"VMCredential"='CMLabCred-SrvLocalAdmin'}
	Start-HybridChildRunbook -ChildRunbookName $ChildRunbookName -ChildRunbookInputParams $ChildRunbookInputParams -AzureOrgIdCredential $AzureCredential -AzureSubscriptionName $AzureSubscriptionName -AutomationAccountName $AutomationAccountName -WaitForJobCompletion:$true -ReturnJobOutput:$true -HybridWorkerGroup $HybridWorkerGroup
	
	$ChildRunbookName = "Create-ADOU"
    $ChildRunbookInputParams = @{'CustomerDomainController'="$CustomerADSrvHostname";'OU'="OU=Users,$CustomerTCStdAdDn";"VMCredential"='CMLabCred-SrvLocalAdmin'}
	Start-HybridChildRunbook -ChildRunbookName $ChildRunbookName -ChildRunbookInputParams $ChildRunbookInputParams -AzureOrgIdCredential $AzureCredential -AzureSubscriptionName $AzureSubscriptionName -AutomationAccountName $AutomationAccountName -WaitForJobCompletion:$true -ReturnJobOutput:$true -HybridWorkerGroup $HybridWorkerGroup
	
	$ChildRunbookName = "Import-ADGPO"
    $ChildRunbookInputParams = @{'CustomerDomainController'="$CustomerADSrvHostname";'GPOLinkOU'="OU=Computers,$CustomerTCStdAdDn";"GPOName"="Managed Client - Firewall";"GPOGuid"='6FBBFCA9-5CC0-4718-8277-2E840C5A78E9';"SourceFilesParentDir"="$SourceFilesDestination";"VMCredential"='CMLabCred-SrvLocalAdmin'}
	Start-HybridChildRunbook -ChildRunbookName $ChildRunbookName -ChildRunbookInputParams $ChildRunbookInputParams -AzureOrgIdCredential $AzureCredential -AzureSubscriptionName $AzureSubscriptionName -AutomationAccountName $AutomationAccountName -WaitForJobCompletion:$true -ReturnJobOutput:$true -HybridWorkerGroup $HybridWorkerGroup


	$ChildRunbookName = "Enable-CredSSP"
    $ChildRunbookInputParams = @{"VMName"="$CustomerCMSrvHostname";"VMCredential"='CMLabCred-SrvLocalAdmin'}
	Start-HybridChildRunbook -ChildRunbookName $ChildRunbookName -ChildRunbookInputParams $ChildRunbookInputParams -AzureOrgIdCredential $AzureCredential -AzureSubscriptionName $AzureSubscriptionName -AutomationAccountName $AutomationAccountName -WaitForJobCompletion:$true -ReturnJobOutput:$true -HybridWorkerGroup $HybridWorkerGroup
	
	$ChildRunbookName = "Create-SourcefileDisk"
    $ChildRunbookInputParams = @{"VMName"="$CustomerCMSrvHostname";"VMCredential"='CMLabCred-SrvLocalAdmin';"SourcefilesDir"="D:\CMSetupSource";"DiskSizeInGB"=20}
	Start-HybridChildRunbook -ChildRunbookName $ChildRunbookName -ChildRunbookInputParams $ChildRunbookInputParams -AzureOrgIdCredential $AzureCredential -AzureSubscriptionName $AzureSubscriptionName -AutomationAccountName $AutomationAccountName -WaitForJobCompletion:$true -ReturnJobOutput:$true -HybridWorkerGroup $HybridWorkerGroup
	
	# Checkpoint Workflow, credentials must be cleared and reassigned for Workflow resume to work
	$AzureCredential = $null
	Checkpoint-Workflow
	$AzureCredential = Get-AutomationPSCredential -Name 'AzureOrgIdCredential'
	
	$ChildRunbookName = "Create-CMShares"
    $ChildRunbookInputParams = @{"VMName"="$CustomerCMSrvHostname";'CMNetworkAccountCredential'="CMSetupCred-$CustomerNumber NetworkAccessAccount";'CMSharesParentFolder'="$CMSharesParentFolder";"VMCredential"="CMSetupCred-$CustomerNumber CMInstaller Domainaccount"}
	Start-HybridChildRunbook -ChildRunbookName $ChildRunbookName -ChildRunbookInputParams $ChildRunbookInputParams -AzureOrgIdCredential $AzureCredential -AzureSubscriptionName $AzureSubscriptionName -AutomationAccountName $AutomationAccountName -WaitForJobCompletion:$true -ReturnJobOutput:$true -HybridWorkerGroup $HybridWorkerGroup
	
	# Checkpoint Workflow, credentials must be cleared and reassigned for Workflow resume to work
	$AzureCredential = $null
	Checkpoint-Workflow
	$AzureCredential = Get-AutomationPSCredential -Name 'AzureOrgIdCredential'
	
	$ChildRunbookName = "Install-CMPrimarySiteWinFeatures"
    $ChildRunbookInputParams = @{"VMName"="$CustomerCMSrvHostname";"VMCredential"="CMSetupCred-$CustomerNumber CMInstaller Domainaccount";"MacSupport"=$true}
	Start-HybridChildRunbook -ChildRunbookName $ChildRunbookName -ChildRunbookInputParams $ChildRunbookInputParams -AzureOrgIdCredential $AzureCredential -AzureSubscriptionName $AzureSubscriptionName -AutomationAccountName $AutomationAccountName -WaitForJobCompletion:$true -ReturnJobOutput:$true -HybridWorkerGroup $HybridWorkerGroup -JobPollingTimeoutInSeconds 1200
	
	# Checkpoint Workflow, credentials must be cleared and reassigned for Workflow resume to work
	$AzureCredential = $null
	Checkpoint-Workflow
	$AzureCredential = Get-AutomationPSCredential -Name 'AzureOrgIdCredential'
	
	$ChildRunbookName = "Install-WDS"
    $ChildRunbookInputParams = @{"VMName"="$CustomerCMSrvHostname";"VMCredential"="CMSetupCred-$CustomerNumber CMInstaller Domainaccount"}
	Start-HybridChildRunbook -ChildRunbookName $ChildRunbookName -ChildRunbookInputParams $ChildRunbookInputParams -AzureOrgIdCredential $AzureCredential -AzureSubscriptionName $AzureSubscriptionName -AutomationAccountName $AutomationAccountName -WaitForJobCompletion:$true -ReturnJobOutput:$true -HybridWorkerGroup $HybridWorkerGroup
	
	# Checkpoint Workflow, credentials must be cleared and reassigned for Workflow resume to work
	$AzureCredential = $null
	Checkpoint-Workflow
	$AzureCredential = Get-AutomationPSCredential -Name 'AzureOrgIdCredential'
	
	$ChildRunbookName = "Extend-ADSchema"
    $ChildRunbookInputParams = @{"VMName"="$CustomerCMSrvHostname";"VMCredential"="CMSetupCred-$CustomerNumber CMInstaller Domainaccount";"SourceFilesParentDir"="$SourceFilesDestination"}
	Start-HybridChildRunbook -ChildRunbookName $ChildRunbookName -ChildRunbookInputParams $ChildRunbookInputParams -AzureOrgIdCredential $AzureCredential -AzureSubscriptionName $AzureSubscriptionName -AutomationAccountName $AutomationAccountName -WaitForJobCompletion:$true -ReturnJobOutput:$true -HybridWorkerGroup $HybridWorkerGroup
	
	# Checkpoint Workflow, credentials must be cleared and reassigned for Workflow resume to work
	$AzureCredential = $null
	Checkpoint-Workflow
	$AzureCredential = Get-AutomationPSCredential -Name 'AzureOrgIdCredential'
	
	$ChildRunbookName = "Create-SysmanContainer"
    $ChildRunbookInputParams =  @{"VMName"="$CustomerADSrvHostname";"VMCredential"="CMSetupCred-$CustomerNumber CMInstaller Domainaccount";"CMServersADGroup"="$CMServersADGroup";"CMServersADGroupOU"="OU=Resources,$CustomerTCStdAdDn";"CustomerCMSrvHostname"="$CustomerCMSrvHostname"}
	Start-HybridChildRunbook -ChildRunbookName $ChildRunbookName -ChildRunbookInputParams $ChildRunbookInputParams -AzureOrgIdCredential $AzureCredential -AzureSubscriptionName $AzureSubscriptionName -AutomationAccountName $AutomationAccountName -WaitForJobCompletion:$true -ReturnJobOutput:$true -HybridWorkerGroup $HybridWorkerGroup
	
	$ChildRunbookName = "Restart-VM"
	$ChildRunbookInputParams = @{"VMName"="$CustomerCMSrvHostname";"VMCredential"="CMSetupCred-$CustomerNumber CMInstaller Domainaccount"}
	Start-HybridChildRunbook -ChildRunbookName $ChildRunbookName -ChildRunbookInputParams $ChildRunbookInputParams -AzureOrgIdCredential $AzureCredential -AzureSubscriptionName $AzureSubscriptionName -AutomationAccountName $AutomationAccountName -WaitForJobCompletion:$true -ReturnJobOutput:$true -HybridWorkerGroup $HybridWorkerGroup
	
	# Checkpoint Workflow, credentials must be cleared and reassigned for Workflow resume to work
	$AzureCredential = $null
	Checkpoint-Workflow
	$AzureCredential = Get-AutomationPSCredential -Name 'AzureOrgIdCredential'
	
	$ChildRunbookName = "Install-MDT2013U1"
	$ChildRunbookInputParams = @{"VMName"="$CustomerCMSrvHostname";"VMCredential"="CMSetupCred-$CustomerNumber CMInstaller Domainaccount";"SourceFilesParentDir"="$SourceFilesDestination"}
	Start-HybridChildRunbook -ChildRunbookName $ChildRunbookName -ChildRunbookInputParams $ChildRunbookInputParams -AzureOrgIdCredential $AzureCredential -AzureSubscriptionName $AzureSubscriptionName -AutomationAccountName $AutomationAccountName -WaitForJobCompletion:$true -ReturnJobOutput:$true -HybridWorkerGroup $HybridWorkerGroup
	
	# Checkpoint Workflow, credentials must be cleared and reassigned for Workflow resume to work
	$AzureCredential = $null
	Checkpoint-Workflow
	$AzureCredential = Get-AutomationPSCredential -Name 'AzureOrgIdCredential'
	
	$ChildRunbookName = "Install-ADK10"
	$ChildRunbookInputParams = @{"VMName"="$CustomerCMSrvHostname";"VMCredential"="CMSetupCred-$CustomerNumber CMInstaller Domainaccount";"SourceFilesParentDir"="$SourceFilesDestination"}
	Start-HybridChildRunbook -ChildRunbookName $ChildRunbookName -ChildRunbookInputParams $ChildRunbookInputParams -AzureOrgIdCredential $AzureCredential -AzureSubscriptionName $AzureSubscriptionName -AutomationAccountName $AutomationAccountName -WaitForJobCompletion:$true -ReturnJobOutput:$true -HybridWorkerGroup $HybridWorkerGroup
	
	# Checkpoint Workflow, credentials must be cleared and reassigned for Workflow resume to work
	$AzureCredential = $null
	Checkpoint-Workflow
	$AzureCredential = Get-AutomationPSCredential -Name 'AzureOrgIdCredential'
	
	$ChildRunbookName = "Install-CMSQLSrv"
	$ChildRunbookInputParams = @{"VMName"="$CustomerCMSrvHostname";"VMCredential"="CMSetupCred-$CustomerNumber CMInstaller Domainaccount";"SourceFilesParentDir"="$SourceFilesDestination";"SQLSrvUnattendName"="CMSetupVar-$CustomerNumber SQLserver 2014 Unattend";"CMSQLServiceAccountCredential"="CMSetupCred-$CustomerNumber SQL Service Account";"CMSQLServerSAAccountCredential"="CMSetupCred-$CustomerNumber SQL SA Account"}
	Start-HybridChildRunbook -ChildRunbookName $ChildRunbookName -ChildRunbookInputParams $ChildRunbookInputParams -AzureOrgIdCredential $AzureCredential -AzureSubscriptionName $AzureSubscriptionName -AutomationAccountName $AutomationAccountName -WaitForJobCompletion:$true -ReturnJobOutput:$true -HybridWorkerGroup $HybridWorkerGroup -JobPollingTimeoutInSeconds 1800
	
	$ChildRunbookName = "Restart-VM"
	$ChildRunbookInputParams = @{"VMName"="$CustomerCMSrvHostname";"VMCredential"="CMSetupCred-$CustomerNumber CMInstaller Domainaccount"}
	Start-HybridChildRunbook -ChildRunbookName $ChildRunbookName -ChildRunbookInputParams $ChildRunbookInputParams -AzureOrgIdCredential $AzureCredential -AzureSubscriptionName $AzureSubscriptionName -AutomationAccountName $AutomationAccountName -WaitForJobCompletion:$true -ReturnJobOutput:$true -HybridWorkerGroup $HybridWorkerGroup
	
	# Checkpoint Workflow, credentials must be cleared and reassigned for Workflow resume to work
	$AzureCredential = $null
	Checkpoint-Workflow
	$AzureCredential = Get-AutomationPSCredential -Name 'AzureOrgIdCredential'
	
	$ChildRunbookName = "Install-CM2012SP2"
	$ChildRunbookInputParams = @{"VMName"="$CustomerCMSrvHostname";"VMCredential"="CMSetupCred-$CustomerNumber CMInstaller Domainaccount";"SourceFilesParentDir"="$SourceFilesDestination";"CM2012SP2UnattendName"="CMSetupVar-$CustomerNumber Configuration Manager 2012 Unattend"}
	Start-HybridChildRunbook -ChildRunbookName $ChildRunbookName -ChildRunbookInputParams $ChildRunbookInputParams -AzureOrgIdCredential $AzureCredential -AzureSubscriptionName $AzureSubscriptionName -AutomationAccountName $AutomationAccountName -WaitForJobCompletion:$true -ReturnJobOutput:$true -HybridWorkerGroup $HybridWorkerGroup -JobPollingTimeoutInSeconds 1800
	
	# Checkpoint Workflow, credentials must be cleared and reassigned for Workflow resume to work
	$AzureCredential = $null
	Checkpoint-Workflow
	$AzureCredential = Get-AutomationPSCredential -Name 'AzureOrgIdCredential'
	
	$ChildRunbookName = "Install-CM2012R2SP1"
	$ChildRunbookInputParams = @{"VMName"="$CustomerCMSrvHostname";"VMCredential"="CMSetupCred-$CustomerNumber CMInstaller Domainaccount";"SourceFilesParentDir"="$SourceFilesDestination"}
	Start-HybridChildRunbook -ChildRunbookName $ChildRunbookName -ChildRunbookInputParams $ChildRunbookInputParams -AzureOrgIdCredential $AzureCredential -AzureSubscriptionName $AzureSubscriptionName -AutomationAccountName $AutomationAccountName -WaitForJobCompletion:$true -ReturnJobOutput:$true -HybridWorkerGroup $HybridWorkerGroup
	
	# Checkpoint Workflow, credentials must be cleared and reassigned for Workflow resume to work
	$AzureCredential = $null
	Checkpoint-Workflow
	$AzureCredential = Get-AutomationPSCredential -Name 'AzureOrgIdCredential'
	
	$ChildRunbookName = "Install-CM2012R2SP1CU2"
	$ChildRunbookInputParams = @{"VMName"="$CustomerCMSrvHostname";"VMCredential"="CMSetupCred-$CustomerNumber CMInstaller Domainaccount";"SourceFilesParentDir"="$SourceFilesDestination"}
	Start-HybridChildRunbook -ChildRunbookName $ChildRunbookName -ChildRunbookInputParams $ChildRunbookInputParams -AzureOrgIdCredential $AzureCredential -AzureSubscriptionName $AzureSubscriptionName -AutomationAccountName $AutomationAccountName -WaitForJobCompletion:$true -ReturnJobOutput:$true -HybridWorkerGroup $HybridWorkerGroup
	
	# Checkpoint Workflow, credentials must be cleared and reassigned for Workflow resume to work
	$AzureCredential = $null
	Checkpoint-Workflow
	$AzureCredential = Get-AutomationPSCredential -Name 'AzureOrgIdCredential'
	
	$ChildRunbookName = "Configure-CMPostinstall"
	$ChildRunbookInputParams = @{"VMName"="$CustomerCMSrvHostname";"VMCredential"="CMSetupCred-$CustomerNumber CMInstaller Domainaccount";"CMNetworkAccountCredential"="CMSetupCred-$CustomerNumber NetworkAccessAccount";"CMPushInstallAccountCredential"="CMSetupCred-$CustomerNumber PushInstallationAccount";"OULaptops"="OU=Laptops,OU=Computers,$CustomerTCStdAdDn";"OUDesktops"="OU=Desktops,OU=Computers,$CustomerTCStdAdDn";"OUUsers"="OU=Users,$CustomerTCStdAdDn";"OUAppGroups"="OU=Resources,$CustomerTCStdAdDn";"CustomerNumber"="$CustomerNumber"}
	Start-HybridChildRunbook -ChildRunbookName $ChildRunbookName -ChildRunbookInputParams $ChildRunbookInputParams -AzureOrgIdCredential $AzureCredential -AzureSubscriptionName $AzureSubscriptionName -AutomationAccountName $AutomationAccountName -WaitForJobCompletion:$true -ReturnJobOutput:$true -HybridWorkerGroup $HybridWorkerGroup -JobPollingTimeoutInSeconds 1200
	
	$ChildRunbookName = "New-LabClientVM"
	$ChildRunbookInputParams = @{"Sourcefile"="D:\CMSetupSource\OSImage\Windows10Image\011_2015-10-5.wim";"SrvSettingsXMLFile"="Client_settings.xml";"VMName"="$CustomerNumber-WinX01";"VMLocation"='d:\VMs';"VMMemory"="2048";"IPAddress"='DHCP';"DifforCreate"="CREATE";"VMType"="UEFI";"DomainOrWorkGroup"="DOMAIN";"OU"="OU=Desktops,OU=Computers,$CustomerTCStdAdDn";"Force"=$true}
	Start-HybridChildRunbook -ChildRunbookName $ChildRunbookName -ChildRunbookInputParams $ChildRunbookInputParams -AzureOrgIdCredential $AzureCredential -AzureSubscriptionName $AzureSubscriptionName -AutomationAccountName $AutomationAccountName -WaitForJobCompletion:$true -ReturnJobOutput:$true -HybridWorkerGroup $HybridWorkerGroup -JobPollingTimeoutInSeconds 1200
	
	[datetime]$EndRun = Get-Date
	[timespan]$Runtime = New-TimeSpan -Start $StartRun.ToLongTimeString() -End $EndRun.ToLongTimeString()

	Write-Verbose "Labsetup executiontime: $Runtime" -Verbose
}