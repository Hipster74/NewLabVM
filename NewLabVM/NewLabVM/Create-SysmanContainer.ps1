workflow Create-SysManContainer {

    [OutputType([string])]
    param(
            [Parameter(Mandatory=$true)]
            [string] $VMName,
            [Parameter(Mandatory=$true)]
            [PSCredential] $VMCredential,
			[Parameter(Mandatory=$true)]
            [string] $CMServersADGroup,
            [Parameter(Mandatory=$true)]
            [string] $CMServersADGroupOU,
            [Parameter(Mandatory=$true)]
            [string] $CustomerCMSrvHostname
            
        )

        Inlinescript {
            $CMServersADGroup = $using:CMServersADGroup
            $CMServersADGroupOU = $using:CMServersADGroupOU
            $CustomerCMSrvHostname = $using:CustomerCMSrvHostname
            
            try {
                Import-Module ActiveDirectory
                $ActiveDirectoryDN = (Get-ADDomain).DistinguishedName
                # Create CMServers Active Directorygroup OU path if missing
                $CMServersADGroupOUFullDn = $CMServersADGroupOU + ',' + $ActiveDirectoryDN
                if (!(Test-Path "AD:\$CMServersADGroupOUFullDn")) {
                    Write-Warning "$CMServersADGroupOUFullDn not found, creating it now recursively"
                    [array]$CMServersADGroupOUReverse = $CMServersADGroupOU.Split(',')
                    [array]::Reverse($CMServersADGroupOUReverse)

                    foreach ($ou in $CMServersADGroupOUReverse) {
                        if(!(Test-Path "AD:\$ou,$OUPath$((Get-ADDomain).distinguishedname)")) {
                            New-ADOrganizationalUnit -Name $ou.TrimStart('OU=') -Path "$OUPath$((Get-ADDomain).distinguishedname)" -ProtectedFromAccidentalDeletion $true
                        }
                        $OUPath = $ou + ',' + $OUPath
                        Write-Verbose "Creating OU $OUPath"
                    }
                }
                else {Write-Verbose "$CMServersADGroupOUFullDn found"}
                
                # Create Active Directorygroup for CMServers
                if (!(Test-Path "AD:\CN=$CMServersADGroup,$CMServersADGroupOU,$ActiveDirectoryDN")) {
                    Write-Verbose "CN=$CMServersADGroup,$CMServersADGroupOU,$ActiveDirectoryDN not found, creating it now"
                    $ADGroup = New-ADGroup -Name $CMServersADGroup -DisplayName $CMServersADGroup -GroupScope global -Path "$CMServersADGroupOU,$ActiveDirectoryDN" -Description "Configuration Manager Servers" -OtherAttributes @{'Member'="$((Get-ADComputer $CustomerCMSrvHostname).distinguishedname)"} -PassThru
                }
                else {Write-Warning "CN=$CMServersADGroup,$CMServersADGroupOU,$ActiveDirectoryDN already exists, continuing"}
                
                if (!(Test-Path "AD:\CN=System Management,CN=System,$ActiveDirectoryDN")) {
                    Write-Verbose "CN=System Management,CN=System,$ActiveDirectoryDN not found, creating it now"
                    $SystemManagementContainer = New-ADObject -Name "System Management" -Type container -Path "CN=System,$ActiveDirectoryDN" –passthru 
                    $SystemManagementContainerACL = Get-Acl "AD:\$SystemManagementContainer"

                    # Create an ACE to give the CMServers Active Directorygroup Full access to the Container "System Management" and the child Objects
                    $All = [System.DirectoryServices.ActiveDirectorySecurityInheritance]::SelfAndChildren
                    $ACE = New-Object System.DirectoryServices.ActiveDirectoryAccessRule $ADGroup.SID, "GenericAll", "Allow", $All

                    # Add the ACE to the ACL
                    $SystemManagementContainerACL.AddAccessRule($ACE)

                    #Set the modified ACL back to the Container "System Management" 
                    Set-acl -aclobject $SystemManagementContainerACL "AD:\CN=System Management,CN=System,$ActiveDirectoryDN"
                    Write-Output "System Management container and CMservers Active Directorygroup created"
                     
                }
                else {
                    Write-Warning "CN=System Management,CN=System,$ActiveDirectoryDN already exists, doing nothing"
                    Write-Output "CN=System Management,CN=System,$ActiveDirectoryDN already exists, doing nothing"
                }
                
            }    
            catch {
                Write-Verbose "Failed to create CN=System Management,CN=System,$ActiveDirectoryDN in Active Directory"
                Write-Error $_.Exception
            }
            
        } -PSComputerName $VMName -PSCredential $VMCredential        

}