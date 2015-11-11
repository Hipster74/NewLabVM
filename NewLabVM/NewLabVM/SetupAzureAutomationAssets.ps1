# Functions
Function Wait-SMAJob{
# https://sysjam.wordpress.com/2015/03/25/starting-and-waiting-for-an-sma-runbook-from-remote-computers/
param ([string]$strJobID,[string]$strWebserviceEndPoint)
 
    [string]$strRBResult = $null
 
    #Wait for the job to finish
    Do
    {
        Try
        {
            Start-Sleep 1
            $objJob = (Get-SmaJob -WebServiceEndpoint $strWebserviceEndPoint -Id $strJobID)
            $strJobStatus = $objJob.Jobstatus
        }
        Catch [Exception]{
            $strException = $_.Exception.Message
            $strException = "Failed to get sma runbook status...with error ${strException}"
        }
    }
    While (($strJobStatus -notin @("Failed", "Stopped", "Completed", "Suspended")) -and (!($strException)))
         
    #Get the job output....job is finished
    Try
    {
        $JobOutputErrors = Get-SmaJobOutput -WebServiceEndpoint $strWebserviceEndPoint -Stream "Error" -id $strJobID
        $JobOutputWarnings = Get-SmaJobOutput -WebServiceEndpoint $strWebserviceEndPoint -Stream "Warning" -id $strJobID
        $JobOutput = Get-SmaJobOutput -WebServiceEndpoint $strWebserviceEndPoint -Stream "Output" -id $strJobID
        $hashJobProps = @{
            "JobID"=$strJobID;
            "Status"=$strJobStatus;
            "Errors"=$JobOutputErrors;
            "Warnings"=$JobOutputWarnings;
            "Output"=$JobOutput
        }
    }
    Catch [Exception]{
        If ($objJob.JobException)
        {
            $strException = "Exception: " + $objJob.JobException
        }
        else
        {
            $strException = $_.Exception.Message
            $strException = "Failed to get sma runbook output...with error ${strException}"
        }
        $hashJobProps = @{
            "JobID"=$strJobID;
            "Status"=$strJobStatus;
            "Errors"=$strException;
            "Warnings"="";
            "Output"=""
        }
    }
     
    $objJobStatus = New-Object -TypeName PSObject -Property $hashJobProps
    Return $objJobStatus
}
# Setup Azureconnection
if (!(Get-AzureAccount).count -ge 1) {Add-AzureAccount}
#Get-AzureSubscription
#Select-AzureSubscription -SubscriptionName "Visual Studio Premium med MSDN"
$SubscriptionName = (Get-AzureSubscription)[0].SubscriptionName
$SubscriptionID = (Get-AzureSubscription)[0].SubscriptionId

#$AutomationAccountName = (New-AzureAutomationAccount -Name ManagedSystemsAutomation -Location "West Europe").AutomationAccountName
$AutomationAccountName = (Get-AzureAutomationAccount).AutomationAccountName

$CustomerNumber = '149999'
$CustomerName = 'Telecomputing'
$CustomerDomain = 'telecomputing.local'
$CustomerDomainNetBiosName = 'TELECOMPUTING'
$CustomerCMSrvHostname = 'cm01'
$CustomerCMSiteCode = 'P99'
$CustomerTCStdAdDn = "OU=$CustomerNumber,OU=Customers,OU=$CustomerNumber" + 'ARN,OU=ASP'

$SourceFilesShareName = 'CMSetupSource'
$SourceFilesSrvHostname = 'dc01'
$SourceFilesDestination = 'c:\ConfigMgrMedia'

$CMProductCode = 'BXH69-M62YX-QQD6R-3GPWX-8WMFY' # Telecomputings System Center licensekey
$CMSDKServer = $("$CustomerCMSrvHostname.$CustomerDomain").ToUpper() # Computer to install the SMS Provider on for primary site installations and the computer name hosting the SMS Provider for ConfigMgr console installations
$CMManagementPoint = $("$CustomerCMSrvHostname.$CustomerDomain").ToUpper()
$CMDistributionPoint = $("$CustomerCMSrvHostname.$CustomerDomain").ToUpper()
$CMSQLServerName = $("$CustomerCMSrvHostname.$CustomerDomain").ToUpper()
$CMPrerequisitePath = "$SourceFilesDestination\SystemCenter\ConfigMgr2012wSP2PreReqs"
$CMInstallDir = 'c:\ConfigMgr'
$CMSharesParentFolder = 'D:\Shares'
$CMServersADGroup = "_$CustomerNumber-ConfigMgrServers"

$CMSetupInstallerAccountUsername = 'Administrator'
$CMSetupInstallerAccountPassword = 'P@ssw0rd'

$CMNetworkAccountUsername = "__$CustomerNumber-R-NwAAcc"
$CMNetworkAccountPassword = 'P@ssw0rd'

$CMSQLServiceAccountUsername = "__$CustomerNumber" + 'sqlsvc-mirro'
$CMSQLServiceAccountPassword = 'P@ssw0rd'

$CMSQLServerSAAccountUsername = 'SA'
$CMSQLServerSAAccountPassword = 'P@ssw0rd'
 
# Start Creating Azure Automation Assets
# Create Azure Automation Connectionassets to customer CMServer for prereq, SQL and Configuration Manager installation
#New-SmaConnection -WebServiceEndpoint $SMAWebEndPoint -Name "CMSetupConn - $CustomerNumber Configuration Manager" -ConnectionTypeName ConfigurationManager –ConnectionFieldValues @{"ComputerName"="$CustomerCMSrvHostname.$CustomerDomain";"UserName"="$CMSetupInstallerAccountUsername@$CustomerDomain";"Password"="$CMSetupInstallerAccountPassword";"CMSiteCode"="$CustomerCMSiteCode"} -Description "Connection to $CustomerNumber Configuration Manager"
New-AzureAutomationConnection -AutomationAccountName $AutomationAccountName -Name "CMSetupConn - $CustomerNumber Configuration Manager" -ConnectionTypeName ConfigurationManager -ConnectionFieldValues @{"ComputerName"="$CustomerCMSrvHostname.$CustomerDomain";"UserName"="$CMSetupInstallerAccountUsername@$CustomerDomain";"Password"="$CMSetupInstallerAccountPassword";"CMSiteCode"="$CustomerCMSiteCode"} -Description "Connection to $CustomerNumber Configuration Manager"

# Create SMA connection to server hosting SMBShare with sourcefiles(SQL, Configuration Manager etc.)
New-SmaConnection -WebServiceEndpoint $SMAWebEndPoint -Name "CMSetupConn - $CustomerNumber Sourcefiles" -ConnectionTypeName MgmtSvcAdmin –ConnectionFieldValues @{"ComputerName"="$SourceFilesSrvHostname.$CustomerDomain";"UserName"="$CMSetupInstallerAccountUsername@$CustomerDomain";"Password"="$CMSetupInstallerAccountPassword"} -Description "Connection to $CustomerNumber Sourcefilesserver"

# Create SMA Variables for customer environment
New-AzureAutomationVariable -AutomationAccountName $AutomationAccountName -Name "CMSetupVar - $CustomerNumber Customernumber" -Value $CustomerNumber -Encrypted $false
New-AzureAutomationVariable -AutomationAccountName $AutomationAccountName -Name "CMSetupVar - $CustomerNumber Domain" -Value $CustomerDomain -Encrypted $false
New-AzureAutomationVariable -AutomationAccountName $AutomationAccountName -Name "CMSetupVar - $CustomerNumber CMServer Hostname" -Value $CustomerCMSrvHostname -Encrypted $false
New-AzureAutomationVariable -AutomationAccountName $AutomationAccountName -Name "CMSetupVar - $CustomerNumber CMSitecode" -Value $CustomerCMSiteCode -Encrypted $false
New-AzureAutomationVariable -AutomationAccountName $AutomationAccountName -Name "CMSetupVar - $CustomerNumber Sourcefiles SMBSharename" -Value $SourceFilesShareName -Encrypted $false
New-AzureAutomationVariable -AutomationAccountName $AutomationAccountName -Name "CMSetupVar - $CustomerNumber Sourcefiles Destination" -Value $SourceFilesDestination -Encrypted $false
New-AzureAutomationVariable -AutomationAccountName $AutomationAccountName -Name "CMSetupVar - $CustomerNumber Telecomputing Standard CMServersgroup" -Value $CMServersADGroup -Encrypted $false
New-AzureAutomationVariable -AutomationAccountName $AutomationAccountName -Name "CMSetupVar - $CustomerNumber Telecomputing Standard AD Base DN" -Value $CustomerTCStdAdDn -Encrypted $false

# GetFQDN for Active Directory Domain Controller in customer domain
$CustomerDCFQDN = Start-SmaRunbook -WebServiceEndpoint $SMAWebEndPoint -Name 'get-domaincontroller' -Parameters @{"CMConnectionName"="CMSetupConn - $CustomerNumber Configuration Manager"}
$CustomerDCFQDNJobstatus = Wait-SMAJob -strJobID $CustomerDCFQDN -strWebserviceEndPoint $SMAWebEndPoint

if ($CustomerDCFQDNJobstatus.Errors = '0') {
    Set-SmaVariable -WebServiceEndpoint $SMAWebEndPoint -Name "CMSetupVar - $CustomerNumber Domain Controller FQDN" -Value $CustomerDCFQDNJobstatus.Output.StreamText
    New-SmaConnection -WebServiceEndpoint $SMAWebEndPoint -Name "CMSetupConn - $CustomerNumber Domain Controller" -ConnectionTypeName MgmtSvcAdmin –ConnectionFieldValues @{"ComputerName"="$($CustomerDCFQDNJobstatus.Output.StreamText)";"UserName"="$CMSetupInstallerAccountUsername@$CustomerDomain";"Password"="$CMSetupInstallerAccountPassword"} -Description "Connection to $CustomerNumber Domain Controller"
}
else {
    Write-Error "Unable to retreive customer Domain Controller"
    Write-Error $CustomerDCFQDNJobstatus.Error.StreamText
}

# Create SMA Variables for common settings
Set-SmaVariable -WebServiceEndpoint $SMAWebEndPoint -Name "CMSetupVar - $CustomerNumber Shares Parentfolder" -Value $CMSharesParentFolder

# Create credential object to use when starting Runbooks with start-SmaRunbook Asset
$SMAWebEndPointAdminCredPassword = ConvertTo-SecureString $SMAWebEndPointAdminPassword -AsPlainText -Force
$SMAWebEndPointCred = New-Object System.Management.Automation.PSCredential ($SMAWebEndPointAdminUserName, $SMAWebEndPointAdminCredPassword)
#Create Credential Asset in SMA using the newly created credential object
Set-SmaCredential -WebServiceEndpoint $SMAWebEndPoint -Name "CMSetupCred - $CustomerNumber SMA Admin Account" -Value $SMAWebEndPointCred

# Create credential object to use when creating SMA Credential Asset
$CMSetupInstallerCredPassWord = ConvertTo-SecureString $CMSetupInstallerAccountPassword -AsPlainText -Force
$CMSetupInstallerCred = New-Object System.Management.Automation.PSCredential ($CMSetupInstallerAccountUsername, $CMNwAAccCredPassWord)
#Create Credential Asset in SMA using the newly created credential object
Set-SmaCredential -WebServiceEndpoint $SMAWebEndPoint -Name "CMSetupCred - $CustomerNumber SetupInstallerAccount" -Value $CMSetupInstallerCred

# Create credential object to use when creating SMA Credential Asset
$CMNwAAccCredPassWord = ConvertTo-SecureString $CMNetworkAccountPassword -AsPlainText -Force
$CMNwAACCCred = New-Object System.Management.Automation.PSCredential ($CMNetworkAccountUsername, $CMNwAAccCredPassWord)
#Create Credential Asset in SMA using the newly created credential object
Set-SmaCredential -WebServiceEndpoint $SMAWebEndPoint -Name "CMSetupCred - $CustomerNumber NetworkAccessAccount" -Value $CMNwAACCCred

# Create credential object to use when creating SMA Credential Asset
$CMSQLServiceAccountCredPassword = ConvertTo-SecureString $CMSQLServiceAccountPassword -AsPlainText -Force
$CMSQLServiceAccountCred = New-Object System.Management.Automation.PSCredential ($CMSQLServiceAccountUsername, $CMSQLServiceAccountCredPassword)
#Create Credential Asset in SMA using the newly created credential object
Set-SmaCredential -WebServiceEndpoint $SMAWebEndPoint -Name "CMSetupCred - $CustomerNumber SQL Service Account" -Value $CMSQLServiceAccountCred

# Create credential object to use when creating SMA Credential Asset
$CMSQLServerSAAccountCredPassword = ConvertTo-SecureString $CMSQLServerSAAccountPassword -AsPlainText -Force
$CMSQLServerSAAccountCred = New-Object System.Management.Automation.PSCredential ($CMSQLServerSAAccountUsername, $CMSQLServerSAAccountCredPassword)
#Create Credential Asset in SMA using the newly created credential object
Set-SmaCredential -WebServiceEndpoint $SMAWebEndPoint -Name "CMSetupCred - $CustomerNumber SQL SA Account" -Value $CMSQLServerSAAccountCred

$SQLSrv2014Unattend = @"
;SQL Server 2014 Configuration File
[OPTIONS]
IACCEPTSQLSERVERLICENSETERMS="True"
; Specifies a Setup work flow, like INSTALL, UNINSTALL, or UPGRADE. This is a required parameter. 
ACTION="Install"

; Use the /ENU parameter to install the English version of SQL Server on your localized Windows operating system. 
ENU="True"

; Parameter that controls the user interface behavior. Valid values are Normal for the full UI,AutoAdvance for a simplied UI, and EnableUIOnServerCore for bypassing Server Core setup GUI block. 
;UIMODE="Normal"

; Setup will not display any user interface. 
QUIET="True"

; Setup will display progress only, without any user interaction. 
QUIETSIMPLE="False"

; Specify whether SQL Server Setup should discover and include product updates. The valid values are True and False or 1 and 0. By default SQL Server Setup will include updates that are found. 
UpdateEnabled="False"

; Specify if errors can be reported to Microsoft to improve future SQL Server releases. Specify 1 or True to enable and 0 or False to disable this feature. 
ERRORREPORTING="False"

; If this parameter is provided, then this computer will use Microsoft Update to check for updates. 
USEMICROSOFTUPDATE="False"

; Specifies features to install, uninstall, or upgrade. The list of top-level features include SQL, AS, RS, IS, MDS, and Tools. The SQL feature will install the Database Engine, Replication, Full-Text, and Data Quality Services (DQS) server. The Tools feature will install Management Tools, Books online components, SQL Server Data Tools, and other shared components. 
FEATURES=SQLENGINE,RS,Tools

; Specify the location where SQL Server Setup will obtain product updates. The valid values are "MU" to search Microsoft Update, a valid folder path, a relative path such as .\MyUpdates or a UNC share. By default SQL Server Setup will search Microsoft Update or a Windows Update service through the Window Server Update Services. 
UpdateSource="MU"

; Displays the command line parameters usage 
HELP="False"

; Specifies that the detailed Setup log should be piped to the console. 
INDICATEPROGRESS="False"

; Specifies that Setup should install into WOW64. This command line argument is not supported on an IA64 or a 32-bit system. 
X86="False"

; Specify the root installation directory for shared components.  This directory remains unchanged after shared components are already installed. 
INSTALLSHAREDDIR="$env:SystemDrive\Program Files\Microsoft SQL Server"

; Specify the root installation directory for the WOW64 shared components.  This directory remains unchanged after WOW64 shared components are already installed. 
INSTALLSHAREDWOWDIR="$env:SystemDrive\Program Files (x86)\Microsoft SQL Server"

; Specify a default or named instance. MSSQLSERVER is the default instance for non-Express editions and SQLExpress for Express editions. This parameter is required when installing the SQL Server Database Engine (SQL), Analysis Services (AS), or Reporting Services (RS). 
INSTANCENAME="A$CustomerNumber"

; Specify that SQL Server feature usage data can be collected and sent to Microsoft. Specify 1 or True to enable and 0 or False to disable this feature. 
SQMREPORTING="False"

; Specify the Instance ID for the SQL Server features you have specified. SQL Server directory structure, registry structure, and service names will incorporate the instance ID of the SQL Server instance. 
INSTANCEID="A$CustomerNumber"

; RSInputSettings_RSInstallMode_Description 
RSINSTALLMODE="DefaultNativeMode"

; Specify the installation directory. 
INSTANCEDIR="$env:SystemDrive\Program Files\Microsoft SQL Server"

; Agent account name 
AGTSVCACCOUNT="$CustomerDomainNetBiosName\$CMSQLServiceAccountUsername"

; Auto-start service after installation.  
AGTSVCSTARTUPTYPE="Manual"

; CM brick TCP communication port 
COMMFABRICPORT="0"

; How matrix will use private networks 
COMMFABRICNETWORKLEVEL="0"

; How inter brick communication will be protected 
COMMFABRICENCRYPTION="0"

; TCP port used by the CM brick 
MATRIXCMBRICKCOMMPORT="0"

; Startup type for the SQL Server service. 
SQLSVCSTARTUPTYPE="Automatic"

; Level to enable FILESTREAM feature at (0, 1, 2 or 3). 
FILESTREAMLEVEL="0"

; Set to "1" to enable RANU for SQL Server Express. 
ENABLERANU="False"

; Specifies a Windows collation or an SQL collation to use for the Database Engine. 
SQLCOLLATION="SQL_Latin1_General_CP1_CI_AS"

; Account for SQL Server service: Domain\User or system account. 
SQLSVCACCOUNT="$CustomerDomainNetBiosName\$CMSQLServiceAccountUsername"

; Windows account(s) to provision as SQL Server system administrators. 
SQLSYSADMINACCOUNTS="$CustomerDomainNetBiosName\$CMSetupInstallerAccountUsername"

; The default is Windows Authentication. Use "SQL" for Mixed Mode Authentication. 
SECURITYMODE="SQL"

; Default directory for the Database Engine backup files. 
SQLBACKUPDIR="c:\DBBackup\MSSQL12.A149999\MSSQL\Backup"

; Default directory for the Database Engine user databases. 
SQLUSERDBDIR="c:\DB\MSSQL12.A$CustomerNumber\MSSQL\Data"

; Default directory for the Database Engine user database logs. 
SQLUSERDBLOGDIR="c:\DBLog\MSSQL12.A$CustomerNumber\MSSQL\Data"

; Directory for Database Engine TempDB files. 
SQLTEMPDBDIR="c:\TempDB\MSSQL12.A$CustomerNumber\MSSQL\Data"

; Directory for the Database Engine TempDB log files. 
SQLTEMPDBLOGDIR="c:\TempDBLog\MSSQL12.A$CustomerNumber\MSSQL\Data"

; Provision current user as a Database Engine system administrator for %SQL_PRODUCT_SHORT_NAME% Express. 
;ADDCURRENTUSERASSQLADMIN="True"

; Specify 0 to disable or 1 to enable the TCP/IP protocol. 
TCPENABLED="1"

; Specify 0 to disable or 1 to enable the Named Pipes protocol. 
NPENABLED="0"

; Startup type for Browser Service. 
BROWSERSVCSTARTUPTYPE="Automatic"

; Specifies which account the report server NT service should execute under.  When omitted or when the value is empty string, the default built-in account for the current operating system.
; The username part of RSSVCACCOUNT is a maximum of 20 characters long and
; The domain part of RSSVCACCOUNT is a maximum of 254 characters long. 
RSSVCACCOUNT="NT Service\ReportServer`$A$CustomerNumber"

; Specifies how the startup mode of the report server NT service.  When 
; Manual - Service startup is manual mode (default).
; Automatic - Service startup is automatic mode.
; Disabled - Service is disabled 
RSSVCSTARTUPTYPE="Automatic"
"@

Set-SmaVariable -WebServiceEndpoint $SMAWebEndPoint -Name "CMSetupVar - $CustomerNumber SQLserver 2014 Unattend" -Value $SQLSrv2014Unattend

$CM2012SP2Unattend = @"
[Identification]
Action=InstallPrimarySite
[Options]
ProductID=$CMProductCode
SiteCode=$CustomerCMSiteCode
SiteName=$CustomerCMSiteCode - $CustomerName $CustomerNumber Primary Site
SMSInstallDir=$CMInstallDir
SDKServer=$CMSDKServer
RoleCommunicationProtocol=HTTPorHTTPS
ClientsUsePKICertificate=0
PrerequisiteComp=1
PrerequisitePath=$CMPrerequisitePath
JoinCEIP=0
MobileDeviceLanguage=0
ManagementPoint=$CMManagementPoint
ManagementPointProtocol=HTTP
DistributionPoint=$CMDistributionPoint
DistributionPointProtocol=HTTP
DistributionPointInstallIIS=0
AdminConsole=1
[SQLConfigOptions]
SQLServerName=$CMSQLServerName
DatabaseName=A$CustomerNumber\CM_$CustomerCMSiteCode
SQLSSBPort=4022
[HierarchyExpansionOption]
"@

Set-SmaVariable -WebServiceEndpoint $SMAWebEndPoint -Name "CMSetupVar - $CustomerNumber Configuration Manager 2012 Unattend" -Value $CM2012SP2Unattend



