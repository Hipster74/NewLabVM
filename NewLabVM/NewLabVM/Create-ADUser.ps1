workflow Create-ADuser {

    [OutputType([string[]])]
    param(
            [Parameter(Mandatory=$true)]
            [PSCredential] $NewUserCredentialAsset,
            [Parameter(Mandatory=$true)]
            [string] $FirstName,
            [Parameter(Mandatory=$true)]
            [string] $LastName,
            [Parameter(Mandatory=$true)]
            [string] $Description,
            [Parameter(Mandatory=$true)]
            [string] $CustomerDomainController,
            [Parameter(Mandatory=$true)]
            [bool] $AdminRights,
			[Parameter(Mandatory=$true)]
            [bool] $SchemaAdminRights,
            [Parameter(Mandatory=$false)]
            [string] $UserOU,
            [Parameter(Mandatory=$true)]
            [PSCredential] $VMCredential
      
        )
		$UserName = $NewUserCredentialAsset.UserName
		$UserPassword = $NewUserCredentialAsset.Password

        Inlinescript {
            $UserName = $using:UserName
            $UserPassword = $using:UserPassword
            $FirstName = $using:FirstName
            $LastName = $using:LastName
            $Description = $using:Description
            $CustomerDomainController = $using:CustomerDomainController
            $AdminRights = $using:AdminRights

            try {
                Import-Module ActiveDirectory

                # Create OU path from parameter or set to default if empty
                if ($using:UserOU -eq $null) {
                    $UserOUFullDn = (get-addomain).UsersContainer
                }
                else {
                    $UserOUFullDn = $using:UserOU + ',' + (Get-ADDomain).DistinguishedName
                    $UserOU = $using:UserOU
                    if (!(Test-Path "AD:\$UserOUFullDn")) {
                        Write-Warning "$UserOUFullDn not found, creating it now recursively"
                        [array]$UserOUReverse = $UserOU.Split(',')
                        [array]::Reverse($UserOUReverse)

                        foreach ($ou in $UserOUReverse) {
                            if(!(Test-Path "AD:\$ou,$OUPath$((Get-ADDomain).distinguishedname)")) {
                                New-ADOrganizationalUnit -Name $ou.TrimStart('OU=') -Path "$OUPath" + "$((Get-ADDomain).distinguishedname)" -ProtectedFromAccidentalDeletion $true
                            }
                            $OUPath = $ou + ',' + $OUPath
                            Write-Verbose "Creating OU $OUPath"
                        }
                    }
                    else {Write-Verbose "$UserOUFullDn found"}
                    
                }
                Write-Verbose "Useraccount will be created in OU $UserOUFullDn"

                # Create Useraccount if it does not already exist
                if (!(Get-ADUser -Filter "samaccountname -eq '$UserName'")) {
                    Write-Verbose "User does not exist"
                    Write-Verbose "Creating user on domaincontroller $CustomerDomainController"
                    $UserObject = New-ADUser -Name $UserName -DisplayName "$FirstName $LastName" -GivenName $FirstName -Surname $LastName -UserPrincipalName "$UserName@$((Get-ADDomain).Forest)" -enabled $true -ChangePasswordAtLogon $false -PasswordNeverExpires $true -AccountPassword $UserPassword -Path $UserOUFullDn -OtherAttributes @{description="$Description";} -PassThru
                    Write-Verbose "Created User $UserObject"
                    if ($AdminRights) {
                        Write-Verbose "Adding $UserName to Domain Administrators"
                        Add-ADGroupMember -Identity 'Domain Admins' -Members $UserName
                    }
					if ($SchemaAdminRights) {
                        Write-Verbose "Adding $UserName to Schema Administrators(needed when extending Schema in Active Directory)"
                        Add-ADGroupMember -Identity 'Schema Admins' -Members $UserName
                    }
					
                }
                else {
                    Write-Warning "User already exists, doing nothing"
                    
                }

            }
            catch {
                Write-Verbose "Failed to create domainuser"
                Write-Error $_.Exception
            }
        } -PSComputerName $CustomerDomainController -PSCredential $VMCredential        

}
