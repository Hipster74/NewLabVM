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
#$AzureAccount = "CMSetup"
$RBname = "New-LabSrv"
$Params = @{"Sourcefile"='C:\MDTBuildLab\Captures\REFWS2012R2-001.wim';"SrvSettingsXMLFile"="ad_srv_settings.xml";"VMName"='AD01';"VMLocation"='d:\VMs';"VMMemory"="2048";"IPAddress"='10.96.130.120';"DifforCreate"="CREATE";"VMType"="UEFI";"DomainOrWorkGroup"="WORKGROUP"}

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
$Params = @{"Sourcefile"='C:\MDTBuildLab\Captures\REFWS2012R2-001.wim';"SrvSettingsXMLFile"="cm_srv_settings.xml";"VMName"='CM01';"VMLocation"='d:\VMs';"VMMemory"="16384";"IPAddress"='DHCP';"DifforCreate"="CREATE";"VMType"="UEFI";"DomainOrWorkGroup"="DOMAIN"}

$RBjob = Start-AzureAutomationRunbook -AutomationAccountName $AutomationAccountName -name $RBname -Parameters $Params -RunOn 'CSCLabHost' -Verbose

DO { 
    $RBjobId = Get-AzureAutomationJob -AutomationAccountName $AutomationAccountName -id $RBjob.Id 
    $RBjobstatus = $RBjobId.Status 
    } Until ($RBjobstatus -eq "Completed")

Get-AzureAutomationJobOutput -AutomationAccountName $AutomationAccountName -Id $RBjob.Id -stream Any

#

$RBname = "Create-ADUser"
$Params = @{"NewUserCredentialAsset"="CMSetupCred-149999 NetworkAccessAccount";'FirstName'='Telecomputing';'LastName'='Serviceaccount';'Description'='ConfigurationManager Network Access Account';'CustomerDomainController'="AD01";'AdminRights'=$false;'UserOU'="OU=ServiceAccounts,$(($CustomerTCStdAdDn).Value)";"VMCredential"='CMLabCred-SrvLocalAdmin'}

$RBjob = Start-AzureAutomationRunbook -AutomationAccountName $AutomationAccountName -name $RBname -Parameters $Params -RunOn 'CSCLabHost' -Verbose

DO { 
    $RBjobId = Get-AzureAutomationJob -AutomationAccountName $AutomationAccountName -id $RBjob.Id 
    $RBjobstatus = $RBjobId.Status 
    } Until ($RBjobstatus -eq "Completed")

Get-AzureAutomationJobOutput -AutomationAccountName $AutomationAccountName -Id $RBjob.Id -stream Any

#
$RBname = "Create-ADUser"
$Params = @{"NewUserCredentialAsset"="CMSetupCred-149999 SQL Service Account";'FirstName'='Telecomputing';'LastName'='Serviceaccount';'Description'='ConfigurationManager SQL Server Account';'CustomerDomainController'="AD01";'AdminRights'=$false;'UserOU'="OU=ServiceAccounts,$(($CustomerTCStdAdDn).Value)";"VMCredential"='CMLabCred-SrvLocalAdmin'}

$RBjob = Start-AzureAutomationRunbook -AutomationAccountName $AutomationAccountName -name $RBname -Parameters $Params -RunOn 'CSCLabHost' -Verbose

DO { 
    $RBjobId = Get-AzureAutomationJob -AutomationAccountName $AutomationAccountName -id $RBjob.Id 
    $RBjobstatus = $RBjobId.Status 
    } Until ($RBjobstatus -eq "Completed")

Get-AzureAutomationJobOutput -AutomationAccountName $AutomationAccountName -Id $RBjob.Id -stream Any

#
$RBname = "Create-CMShares"
$Params = @{"VMName"="CM01";'CMNetworkAccountCredentialsName'="CMSetupCred-149999 NetworkAccessAccount";'CMSharesParentFolder'='c:\Shares';"VMCredential"='CMLabCred-SrvLocalAdmin'}

$RBjob = Start-AzureAutomationRunbook -AutomationAccountName $AutomationAccountName -name $RBname -Parameters $Params -RunOn 'CSCLabHost' -Verbose

DO { 
    $RBjobId = Get-AzureAutomationJob -AutomationAccountName $AutomationAccountName -id $RBjob.Id 
    $RBjobstatus = $RBjobId.Status 
    } Until ($RBjobstatus -eq "Completed")

Get-AzureAutomationJobOutput -AutomationAccountName $AutomationAccountName -Id $RBjob.Id -stream Any
#
$RBname = "Install-CMPrimarySiteWinFeatures"
$Params = @{"VMName"="CM01";"VMCredential"='CMLabCred-SrvLocalAdmin';"MacSupport"=$true}

$RBjob = Start-AzureAutomationRunbook -AutomationAccountName $AutomationAccountName -name $RBname -Parameters $Params -RunOn 'CSCLabHost' -Verbose

DO { 
    $RBjobId = Get-AzureAutomationJob -AutomationAccountName $AutomationAccountName -id $RBjob.Id 
    $RBjobstatus = $RBjobId.Status 
    } Until ($RBjobstatus -eq "Completed")

Get-AzureAutomationJobOutput -AutomationAccountName $AutomationAccountName -Id $RBjob.Id -stream Any
#


    
    # Restart CMServer
    try {    
        Inlinescript {
            $CMConnection = $using:CMConnection
            $CMCredential = $using:CMCredential
            Restart-Computer -ComputerName $CMConnection.ComputerName -Protocol WSMan -wait -For Powershell -Timeout 1000 -Delay 5 -Force -ErrorAction Stop -Credential $CMCredential
        }
            Write-Verbose "($CMConnection.ComputerName) restarted sucessefully"        
    }
    catch {
        Write-Error "Something went wrong when restarting ($CMConnection.ComputerName)"
        Throw
    }


