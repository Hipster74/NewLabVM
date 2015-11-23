workflow Create-ADOU {

    [OutputType([string[]])]
    param(
        [Parameter(Mandatory=$true)]
		[string] $CustomerDomainController,
        [Parameter(Mandatory=$true)]
        [string] $OU,
        [Parameter(Mandatory=$true)]
        [PSCredential] $VMCredential
    )
		Inlinescript {
            $OU = $using:OU

            try {
                Import-Module ActiveDirectory

                $OUFullDn = $OU + ',' + (Get-ADDomain).DistinguishedName
                if (!(Test-Path "AD:\$OUFullDn")) {
					Write-Verbose "$OUFullDn not found, creating it now recursively" -Verbose
                    [array]$OUReverse = $OU.Split(',')
                    [array]::Reverse($OUReverse)

                    ForEach ($ou in $OUReverse) {
						if(!(Test-Path "AD:\$ou,$OUPath$((Get-ADDomain).distinguishedname)")) {
							Write-Verbose "Creating $ou in path $OUPath$((Get-ADDomain).distinguishedname)"-Verbose
                            New-ADOrganizationalUnit -Name $ou.TrimStart('OU=') -Path "$OUPath$((Get-ADDomain).distinguishedname)" -ProtectedFromAccidentalDeletion $true
                        }
                        $OUPath = $ou + ',' + $OUPath
                    }
                } else {Write-Verbose "$OUFullDn found, no need to recreate it"-Verbose}
				Write-Verbose "$OU successfully created/verified" -Verbose
            }
            catch {
                Write-Verbose "Failed to create Organizational Unit" -Verbose
                Write-Error $_.Exception
            }
        } -PSComputerName $CustomerDomainController -PSCredential $VMCredential        

}
