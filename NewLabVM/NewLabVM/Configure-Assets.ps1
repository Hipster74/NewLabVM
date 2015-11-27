Workflow Configure-Assets {
	[OutputType([string])]
	param (
        [Parameter(Mandatory=$true)]
        [string] 
        $CustomerNumber,

		[Parameter(Mandatory=$true)]
        [string] 
        $CustomerName,

		[parameter(Mandatory=$true)]
        [PSCredential]
        $AzureOrgIdCredential,
        
        [Parameter(Mandatory=$true)]
        [string] 
        $AzureSubscriptionName,

        [Parameter(Mandatory=$true)]
        [string] 
        $AutomationAccountName,

		[parameter(Mandatory=$true)]
        [PSCredential]
        $CMSetupInstallerCred,

		[parameter(Mandatory=$true)]
        [PSCredential]
        $CMNwAACCCred,

		[parameter(Mandatory=$true)]
        [PSCredential]
        $CMSQLServiceAccountCred,

		[parameter(Mandatory=$true)]
        [PSCredential]
        $CMSQLServerSAAccountCred,

		[Parameter(Mandatory=$true)]
        [string] 
        $CMProductCode,

		[Parameter(Mandatory=$true)]
        [string] 
        $CustomerCMSiteCode,

		[Parameter(Mandatory=$true)]
        [string] 
        $CustomerCMSrvHostname,

		[Parameter(Mandatory=$true)]
        [string] 
        $CustomerDomain,

		[Parameter(Mandatory=$true)]
        [string] 
        $CMInstallDir,

		[Parameter(Mandatory=$true)]
        [string] 
        $CMPrerequisitePath
     
    )

	$CMSQLServiceAccountUsername = $CMSQLServiceAccountCred.UserName
	$CMSetupInstallerAccountUsername = $CMSetupInstallerCred.UserName

	$CMSDKServer = $("$CustomerCMSrvHostname.$CustomerDomain").ToUpper() # Computer to install the SMS Provider on for primary site installations and the computer name hosting the SMS Provider for ConfigMgr console installations
	$CMManagementPoint = $("$CustomerCMSrvHostname.$CustomerDomain").ToUpper()
	$CMDistributionPoint = $("$CustomerCMSrvHostname.$CustomerDomain").ToUpper()
	$CMSQLServerName = $("$CustomerCMSrvHostname.$CustomerDomain").ToUpper()

	# Connect to Azure so that this runbook can call the Azure cmdlets
    Add-AzureAccount -Credential $AzureOrgIdCredential | Write-Verbose

    # Select the Azure subscription we will be working against
    Select-AzureSubscription -SubscriptionName $AzureSubscriptionName | Write-Verbose

	# Create Credential Asset in Azure Automation for Domainaccount used when installing products and extending AD schema
	New-AzureAutomationCredential -AutomationAccountName $AutomationAccountName -Name "CMSetupCred-$CustomerNumber CMInstaller Domainaccount" -Value $CMSetupInstallerCred

	# Create Credential Asset in Azure Automation for Configuration Manager Network access account
	New-AzureAutomationCredential -AutomationAccountName $AutomationAccountName -Name "CMSetupCred-$CustomerNumber NetworkAccessAccount" -Value $CMNwAACCCred

	# Create Credential Asset in Azure Automation for SQL Service Account
	New-AzureAutomationCredential -AutomationAccountName $AutomationAccountName -Name "CMSetupCred-$CustomerNumber SQL Service Account" -Value $CMSQLServiceAccountCred

	# Create Credential Asset in Azure Automation for SQL SA Account
	New-AzureAutomationCredential -AutomationAccountName $AutomationAccountName -Name "CMSetupCred-$CustomerNumber SQL SA Account" -Value $CMSQLServerSAAccountCred

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
AGTSVCACCOUNT="$CMSQLServiceAccountUsername"

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
SQLSVCACCOUNT="$CMSQLServiceAccountUsername"

; Windows account(s) to provision as SQL Server system administrators. 
SQLSYSADMINACCOUNTS="$CMSetupInstallerAccountUsername"

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

	New-AzureAutomationVariable -AutomationAccountName $AutomationAccountName -Name "CMSetupVar-$CustomerNumber SQLserver 2014 Unattend" -Value $SQLSrv2014Unattend -Encrypted $false

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

	New-AzureAutomationVariable -AutomationAccountName $AutomationAccountName -Name "CMSetupVar-$CustomerNumber Configuration Manager 2012 Unattend" -Value $CM2012SP2Unattend -Encrypted $false

}