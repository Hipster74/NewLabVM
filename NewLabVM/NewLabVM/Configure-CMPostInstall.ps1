Workflow Configure-CMPostinstall {
	Param(
		[Parameter(Mandatory=$true)]
        [string]$VMName,
		[Parameter(Mandatory=$true)]
		[PSCredential] $VMCredential,
		[Parameter(Mandatory=$true)]
		[PSCredential] $CMNetworkAccountCredential,
		[Parameter(Mandatory=$true)]
        [string]$OULaptops,
		[Parameter(Mandatory=$true)]
        [string]$OUDesktops,
		[Parameter(Mandatory=$true)]
        [string]$OUUsers,
		[Parameter(Mandatory=$true)]
        [string]$OUAppGroups

	)
	
	Inlinescript {
		$CMNetworkAccountCredential = $using:CMNetworkAccountCredential
		$OULaptops = $using:OULaptops 
		$OUDesktops = $using:OUDesktops
		$OUUsers = $using:OUUsers
		$OUAppGroups = $using:OUAppGroups
		
		# Due to strange problems when running Configuration Manager CMDlets in remote inlinescript we have to use Invoke-Command?
		$InvokeCommandOptions = New-PSSessionOption -SkipCACheck
        Invoke-Command -ComputerName $Using:VMName `
                       -Credential $Using:VMCredential `
					   -ArgumentList $CMNetworkAccountCredential,$OULaptops,$OUDesktops,$OUUsers,$OUAppGroups `
                       -SessionOption $InvokeCommandOptions `
                       -ScriptBlock {
			Param (
				[PSCredential]$CMNetworkAccountCredential,
				[string]$OULaptops,
				[string]$OUDesktops,
				[string]$OUUsers,
				[string]$OUAppGroups
			)
			# Appending Domain to AD OU Paths
			$Domain = $env:USERDNSDOMAIN.Split('.')
			$OULaptops = 'LDAP://' + $OULaptops + ",DC=$($Domain[0]),DC=$($Domain[1])"
			$OUDesktops = 'LDAP://' + $OUDesktops + ",DC=$($Domain[0]),DC=$($Domain[1])"
			$OUUsers = 'LDAP://' + $OUUsers + ",DC=$($Domain[0]),DC=$($Domain[1])"
			$OUAppGroups = 'LDAP://' + $OUAppGroups + ",DC=$($Domain[0]),DC=$($Domain[1])"
						   
			# Importing Configuration Manager Powershell module
			try {
				Write-Verbose "Importing Configuration Manager Powershell module" -Verbose
				Import-Module $env:SMS_ADMIN_UI_PATH.Replace("\bin\i386","\bin\configurationmanager.psd1")
				$SiteCode = Get-PSDrive -PSProvider CMSITE
				Set-Location "$($SiteCode.Name):\"
			} catch {
				Write-Verbose "Failed to load Configuration Manager Powershell module" -Verbose
				Write-Error $_.Exception
				Throw
			}
			# Configure Forest Discovery
			Write-Verbose "Configuring Forest Discovery" -Verbose
			Set-CMDiscoveryMethod -ActiveDirectoryForestDiscovery `
				-EnableActiveDirectorySiteBoundaryCreation $true `
				-EnableSubnetBoundaryCreation $false `
				-Enabled $true
			
			# Configure System Discovery
			Write-Verbose "Configuring System Discovery on OU $OULaptops and OU $OUDesktops" -Verbose
			$SystemDiscoverySchedule = New-CMSchedule -Start '2015/01/01 00:00:00' -RecurInterval Days -RecurCount 1

			Set-CMDiscoveryMethod -ActiveDirectorySystemDiscovery `
			  -EnableDeltaDiscovery $true `
			  -DeltaDiscoveryIntervalMinutes 5 `
			  -EnableFilteringExpiredLogon $true `
			  -TimeSinceLastLogonDays 90 `
			  -EnableFilteringExpiredPassword $true `
			  -TimeSinceLastPasswordUpdateDays 90 `
			  -PollingSchedule $SystemDiscoverySchedule `
			  -Enabled $true

			$SystemDiscovery = Get-CimInstance `
				-Namespace "root/sms/site_$sitecode" `
				-ClassName SMS_SCI_Component `
				-Filter 'ComponentName = "SMS_AD_SYSTEM_DISCOVERY_AGENT"'

			$SystemDiscoveryProps = $SystemDiscovery.PropLists | Where-Object {$_.PropertyListName -eq 'AD Containers'}

			# 0 = recursive, 1 = do not include groups
			$SystemDiscoveryProps.Values  = $OULaptops, 0, 1
			$SystemDiscoveryProps.Values += $OUDesktops, 0, 1

			$SystemDiscovery | Set-CimInstance -Property @{PropLists = $SystemDiscovery.PropLists}

			# Configure Group Discovery
			Write-Verbose "Configuring Group Discovery on OU $OUAppGroups" -Verbose
			$GroupDiscoverySchedule = New-CMSchedule -Start '2015/01/01 00:00:00' -RecurInterval Days -RecurCount 7

			Set-CMDiscoveryMethod -ActiveDirectoryGroupDiscovery `
			  -EnableDeltaDiscovery $true `
			  -DeltaDiscoveryIntervalMinutes 5 `
			  -EnableFilteringExpiredLogon $true `
			  -TimeSinceLastLogonDays 90 `
			  -EnableFilteringExpiredPassword $true `
			  -TimeSinceLastPasswordUpdateDays 90 `
			  -PollingSchedule $GroupDiscoverySchedule `
			  -Enabled $true

			$GroupDiscovery = Get-CimInstance `
			  -Namespace "root/sms/site_$SiteCode" `
			  -ClassName SMS_SCI_Component `
			  -Filter 'ComponentName = "SMS_AD_SECURITY_GROUP_DISCOVERY_AGENT"'

			$GroupDiscoveryProps = $GroupDiscovery.PropLists | Where-Object {$_.PropertyListName -eq 'AD Containers'}

			# 0 = location (not group), 0 = recursive, 1 = not used
			$GroupDiscoveryProps.Values = "Application ADgroups", 0, 0, 1
			$NewGroupProp = New-CimInstance `
			  -ClientOnly `
			  -Namespace "root/sms/site_$SiteCode" `
			  -ClassName SMS_EmbeddedPropertyList `
			  -Property @{PropertyListName='Search Bases:Groups';Values=[string[]]$OUAppGroups}

			$GroupDiscovery.PropLists += $NewGroupProp
			$GroupDiscovery | Set-CimInstance -Property @{PropLists = $GroupDiscovery.PropLists}

			# Configure User Discovery
			Write-Verbose "Configuring User Discovery on OU $OUUsers" -Verbose
			$UserDiscoverySchedule = New-CMSchedule -Start '2015/01/01 00:00:00' -RecurInterval Days -RecurCount 1

			Set-CMDiscoveryMethod -ActiveDirectoryUserDiscovery `
			  -EnableDeltaDiscovery $true `
			  -DeltaDiscoveryIntervalMinutes 5 `
			  -PollingSchedule $UserDiscoverySchedule `
			  -Enabled $true

			$UserDiscovery = Get-CimInstance `
			  -Namespace "root/sms/site_$SiteCode" `
			  -ClassName SMS_SCI_Component `
			  -Filter 'ComponentName = "SMS_AD_USER_DISCOVERY_AGENT"'

			$UserDiscoveryProps = $UserDiscovery.PropLists | Where-Object {$_.PropertyListName -eq 'AD Containers'}
			$UserDiscoveryProps.Values = $OUUsers, 0, 1
			$UserDiscovery | Set-CimInstance -Property @{PropLists = $UserDiscovery.PropLists}

			# Restart SMS_SITE_COMPONENT_MANAGER Service
			Write-Verbose "Restarting SMS_SITE_COMPONENT_MANAGER Service" -Verbose
			Get-Service -Name SMS_SITE_COMPONENT_MANAGER | Restart-Service

			# Create LAB Boundary
			New-CMBoundary -Type ADSite -DisplayName LAB -Value LAB  
			New-CMBoundaryGroup -Name LAB -DefaultSiteCode LAB  
			Add-CMBoundaryToGroup -BoundaryGroupName LAB -BoundaryName LAB  
		
			# Configure Distributionpoint to respond to PXErequests and enable unknown computersupport
			Get-CMDistributionPoint | Set-CMDistributionPoint -EnablePXESupport $true -AllowRespondIncomingPxeRequest $true -EnableUnknownComputerSupport $true -EnableValidateContent $true -AddBoundaryGroupName LAB -ClientCommunicationType HTTP			   
		
			# Configure Network Access Account
			New-CMAccount -Name $CMNetworkAccountCredential.UserName -Password $CMNetworkAccountCredential.Password -SiteCode $SiteCode  
			Set-CMSoftwareDistributionComponent -NetworkAccessAccount $CMNetworkAccountCredential.UserName -SiteCode $SiteCode  
		}
	} 
}