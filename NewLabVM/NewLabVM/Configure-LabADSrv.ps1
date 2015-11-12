Workflow Configure-LabADSrv {
param(
    [string] $VMName,
    [int] $VMPort = 80,
    [boolean] $VMUseSSL
)

$VMCredential = Get-AutomationPSCredential -Name "CMLabCred-SrvLocalAdmin"

Inlinescript{ 
	Function Logit{
		$TextBlock1 = $args[0]
		$TextBlock2 = $args[1]
		$TextBlock3 = $args[2]
		$Stamp = Get-Date -Format o
		Write-Output "[$Stamp] [$Section - $TextBlock1]"
	}       
    $Section = "$env:COMPUTERNAME"
	Logit ("Successfully remoted to " + $env:COMPUTERNAME)

	try {
		Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
	}
	Catch {
		$ErrorMessage = $_.Exception.Message
		Logit "Failed to install AD-Domain-Services: $ErrorMessage"
		Write-Error $ErrorMessage
		Break
	}
	Logit "Importing Powershell ActiveDirectory module"
	Import-Module ActiveDirectory

	# Get settingsfile from github
	if (Test-Path "$env:SystemRoot\Temp\ad_srv_settings.xml") {Remove-Item "$env:SystemRoot\Temp\ad_srv_settings.xml"}
	try{
		Logit "Attempting to download settings XMLFile from github (https://raw.github.com/Hipster74/NewLabVM/master/NewLabVM/NewLabVM/ad_srv_settings.xml)"
		Invoke-WebRequest -Uri 'https://raw.github.com/Hipster74/NewLabVM/master/NewLabVM/NewLabVM/ad_srv_settings.xml' -OutFile "$env:SystemRoot\Temp\ad_srv_settings.xml"
	}
	Catch {
		$ErrorMessage = $_.Exception.Message
		Logit "Failed to download .xml from github: $ErrorMessage"
		Write-Error $ErrorMessage
		Break
	}
	sleep -Seconds 2
	[xml]$AdSrvSettings = Get-Content "$env:SystemRoot\Temp\ad_srv_settings.xml"
	Logit "Getting settings from XMLFile into variables"

	#Setting MachineDefaults
	$AdminPassword = $AdSrvSettings.Telecomputing.MachineDefaults.AdminPassword
	$OrgName = $AdSrvSettings.Telecomputing.MachineDefaults.OrgName
	$Fullname = $AdSrvSettings.Telecomputing.MachineDefaults.FullName
	$TimeZoneName = $AdSrvSettings.Telecomputing.MachineDefaults.TimeZoneName
	$InputLocale = $AdSrvSettings.Telecomputing.MachineDefaults.InputLocale
	$SystemLocale = $AdSrvSettings.Telecomputing.MachineDefaults.SystemLocale
	$UILanguage = $AdSrvSettings.Telecomputing.MachineDefaults.UILanguage
	$UserLocale = $AdSrvSettings.Telecomputing.MachineDefaults.UserLocale
	$OSDAdapter0Gateways = $AdSrvSettings.Telecomputing.MachineDefaults.OSDAdapter0Gateways
	$OSDAdapter0DNS1 = $AdSrvSettings.Telecomputing.MachineDefaults.OSDAdapter0DNSServerList[0]
	$OSDAdapter0DNS2 = $AdSrvSettings.Telecomputing.MachineDefaults.OSDAdapter0DNSServerList[1]
	$OSDAdapter0SubnetMaskPrefix = $AdSrvSettings.Telecomputing.MachineDefaults.OSDAdapter0SubnetMaskPrefix
	$ProductKey = $AdSrvSettings.Telecomputing.MachineDefaults.ProductKey
	$VMSwitchName = $AdSrvSettings.Telecomputing.MachineDefaults.VMSwitchName

	#Setting DomainCreateDefaults
	$ADDomainName = $AdSrvSettings.Telecomputing.DomainCreateDefaults.DomainName
	$ADDomainMode = $AdSrvSettings.Telecomputing.DomainCreateDefaults.DomainMode
	$ADForestMode = $AdSrvSettings.Telecomputing.DomainCreateDefaults.ForestMode
	$ADSafeModeAdministratorPassword = $AdSrvSettings.Telecomputing.DomainCreateDefaults.SafeModeAdministratorPassword
	$ADDatabasePath = $AdSrvSettings.Telecomputing.DomainCreateDefaults.DatabasePath
	$ADSysvolPath = $AdSrvSettings.Telecomputing.DomainCreateDefaults.SysvolPath
	$ADLogPath = $AdSrvSettings.Telecomputing.DomainCreateDefaults.LogPath

	#Setting DomainDefaults
	$DNSDomain = $AdSrvSettings.Telecomputing.DomainDefaults.DNSDomain
	$DomainNetBios = $AdSrvSettings.Telecomputing.DomainDefaults.DomainNetBios
	$DomainAdmin = $AdSrvSettings.Telecomputing.DomainDefaults.DomainAdmin
	$DomainAdminPassword = $AdSrvSettings.Telecomputing.DomainDefaults.DomainAdminPassword
	$DomainAdminDomain = $AdSrvSettings.Telecomputing.DomainDefaults.DomainAdminDomain
	$MachienObjectOU = $AdSrvSettings.Telecomputing.DomainDefaults.MachienObjectOU

	#Settings WorkgroupDefaults
	$JoinWorkgroup = $AdSrvSettings.Telecomputing.WorkgroupDefaults.WorkgroupName

	$ADSafeModeAdministratorPasswordSecure = ConvertTo-SecureString -String $ADSafeModeAdministratorPassword -AsPlainText -Force
	
	# Configure Active Directory and DNS
	Logit "Configura AD DS and DNS"
	Install-ADDSForest `
	-CreateDnsDelegation:$false `
	-DatabasePath "$ADDatabasePath" `
	-DomainMode "$ADDomainMode" `
	-DomainName $ADDomainName `
	-DomainNetbiosName $DomainNetBios `
	-ForestMode $ADForestMode `
	-InstallDns:$true `
	-SafeModeAdministratorPassword $SecurePassword `
	-LogPath "$ADLogPath" `
	-NoRebootOnCompletion:$true `
	-SysvolPath "$ADSysvolPath" `
	-Force:$true

} -PSComputerName $VMName -PSCredential $VMCredential

Write-Output "Restarting computer $VMName to complete Active Directory installation"
Restart-Computer -Wait -PSComputerName $VMName -PSCredential $VMCredential

}
