Workflow Configure-LabADSrv {
param(
    [Parameter(Mandatory=$true)]
	[string] $VMName,
	[Parameter(Mandatory=$true)]
    [PSCredential] $VMCredential,
	[parameter(mandatory=$True,HelpMessage="Name of XML file with serversettings.")]
	[string]$SrvSettingsXMLFile
)

Inlinescript{ 
	$SrvSettingsXMLFile = $using:SrvSettingsXMLFile
	Function Logit{
		$TextBlock1 = $args[0]
		$TextBlock2 = $args[1]
		$TextBlock3 = $args[2]
		$Stamp = Get-Date -Format o
		Write-Verbose "[$Stamp] [$Section - $TextBlock1]"
	}       
    $Section = "$env:COMPUTERNAME"
	Logit ("Successfully remoted to " + $env:COMPUTERNAME)

	$Section = "Install WindowsFeatures"
	try {
		Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
	}
	Catch {
		$ErrorMessage = $_.Exception.Message
		Logit "Failed to install AD-Domain-Services: $ErrorMessage"
		Write-Error $ErrorMessage
		Break
	}
	try {
		Install-WindowsFeature -Name DHCP -IncludeManagementTools
	}
	Catch {
		$ErrorMessage = $_.Exception.Message
		Logit "Failed to install DHCP: $ErrorMessage"
		Write-Error $ErrorMessage
		Break
	}
	Logit "Importing Powershell ActiveDirectory module"
	Import-Module ActiveDirectory
	
	# Get settingsfile from github
	$Section = "Get XMLFile"
	if (Test-Path "$env:SystemRoot\Temp\$SrvSettingsXMLFile") {
		Logit "Found $env:SystemRoot\Temp\$SrvSettingsXMLFile , deleting it before downloading latest version"
		Remove-Item "$env:SystemRoot\Temp\$SrvSettingsXMLFile" -Force
	}
	$WebRequest = $false
	$i = 1
	do {
		if ($i -ge 10) {Write-Error "Failed to download XMLFile from GitHub after $i retries"; Throw "Failed to download XMLFile from GitHub after $i retries"}

        Logit "Attempt $i to download XML settingsfile from https://raw.github.com/Hipster74/NewLabVM/master/NewLabVM/NewLabVM/$SrvSettingsXMLFile"
		$WebRequest = Invoke-WebRequest -Uri "https://raw.github.com/Hipster74/NewLabVM/master/NewLabVM/NewLabVM/$SrvSettingsXMLFile" -UseBasicParsing -OutFile "$env:SystemRoot\Temp\$SrvSettingsXMLFile" -PassThru
		if (($WebRequest).statuscode -eq '200' -and (Test-Path "$env:SystemRoot\Temp\$SrvSettingsXMLFile")){
            Logit "Successfully downloaded XMLFile from GitHub"
            $WebRequest = $true
        } 
        sleep 3
		$i++
    } until($WebRequest)
	
	[xml]$AdSrvSettings = Get-Content "$env:SystemRoot\Temp\$SrvSettingsXMLFile"
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

	# Create securestring password for Install-ADDSForest
	$ADSafeModeAdministratorPasswordSecure = ConvertTo-SecureString -String $ADSafeModeAdministratorPassword -AsPlainText -Force
	
	$Section = "Configure Active Directory"
	# Configure Active Directory and DNS
	Logit "Configure AD DS and DNS"
	try {
		Install-ADDSForest `
		-CreateDnsDelegation:$false `
		-DatabasePath "$ADDatabasePath" `
		-DomainMode "$ADDomainMode" `
		-DomainName $ADDomainName `
		-DomainNetbiosName $DomainNetBios `
		-ForestMode $ADForestMode `
		-InstallDns:$true `
		-SafeModeAdministratorPassword $ADSafeModeAdministratorPasswordSecure `
		-LogPath "$ADLogPath" `
		-NoRebootOnCompletion:$true `
		-SysvolPath "$ADSysvolPath" `
		-Force:$true
	} catch {
		$ErrorMessage = $_.Exception.Message
		Logit "Failed to run Install-ADDSForest: $ErrorMessage"
		Write-Error $ErrorMessage
		Break
	}

} -PSComputerName $VMName -PSCredential $VMCredential

Write-Verbose "Restarting computer $VMName to complete Active Directory installation"
Restart-Computer -PSComputerName $VMName -PSCredential $VMCredential -Wait -For Wmi -Force

Inlinescript {
	$SrvSettingsXMLFile = $using:SrvSettingsXMLFile
	Function Logit{
		$TextBlock1 = $args[0]
		$TextBlock2 = $args[1]
		$TextBlock3 = $args[2]
		$Stamp = Get-Date -Format o
		Write-Verbose "[$Stamp] [$Section - $TextBlock1]"
	}       
    $Section = "$env:COMPUTERNAME"
	Logit ("Successfully remoted to " + $env:COMPUTERNAME)
	
	$Section = "Get XMLFile"
	[xml]$AdSrvSettings = Get-Content "$env:SystemRoot\Temp\$SrvSettingsXMLFile"
	Logit "Getting settings from XMLFile into variables"

	# Settings DHCPServerDefaults
	$DHCPScopeName = $AdSrvSettings.Telecomputing.DHCPServerDefaults.DHCPScopeName
	$DHCPScopeStart = $AdSrvSettings.Telecomputing.DHCPServerDefaults.DHCPScopeStart
	$DHCPScopeEnd = $AdSrvSettings.Telecomputing.DHCPServerDefaults.DHCPScopeEnd
	$DHCPScopeSubnetMask = $AdSrvSettings.Telecomputing.DHCPServerDefaults.DHCPScopeSubnetMask
	$DHCPScopeFQDN = $AdSrvSettings.Telecomputing.DHCPServerDefaults.DHCPScopeFQDN
	$DHCPScopeDNS = $AdSrvSettings.Telecomputing.DHCPServerDefaults.DHCPScopeDNS
	$DHCPScopeRouter = $AdSrvSettings.Telecomputing.DHCPServerDefaults.DHCPScopeRouter
	
	$Section = "Configure DHCP Server"
	# Authorize the DHCP Server in Active Directory
	try {
		Logit "Authorize the DHCP Server in Active Directory"
		Add-DhcpServerInDC -Verbose

		# Add Scope to DHCP Server
		Logit "Add Scope to DHCP Server"
		Add-DhcpServerv4Scope `
		-Name $DHCPScopeName `
		-StartRange $DHCPScopeStart `
		-EndRange $DHCPScopeEnd `
		-SubnetMask $DHCPScopeSubnetMask `
		-Verbose

		# Set Options on scope
		Logit "Set Options on scope"
		$ScopeID = Get-DhcpServerv4Scope | Where-Object -Property Name -Like -Value "$DHCPScopeName"
		Set-DhcpServerv4OptionValue `
		-ScopeId $ScopeID.ScopeId `
		-DnsDomain $DHCPScopeFQDN `
		-DnsServer $DHCPScopeDNS `
		-Router $DHCPScopeRouter `
		-Verbose

		# Add Security Groups
		Logit "Add Security Groups"
		Add-DhcpServerSecurityGroup -Verbose

		# Flag DHCP as configured
		Logit "Flag DHCP as configured in registry"
		Set-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\ServerManager\Roles\12 -Name ConfigurationState -Value 2 -Force -Verbose

		# Restart DHCP Server
		Logit "Restart DHCP Server"
		Restart-Service "DHCP Server" -Force -Verbose
	} catch {
		$ErrorMessage = $_.Exception.Message
		Logit "Failed when configuring DHCP: $ErrorMessage"
		Write-Error $ErrorMessage
		Break
	}

} -PSComputerName $VMName -PSCredential $VMCredential
	Write-Verbose "Done"
}
