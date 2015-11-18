workflow Install-CMSQLSrv
{
    [OutputType([string])]
    param(
        [Parameter(Mandatory=$true)]
        [string]$VMName,
		[Parameter(Mandatory=$true)]
		[PSCredential] $VMCredential,
        [Parameter(Mandatory=$true,HelpMessage="Default is datadisk on d:\Source")]
        [string]$SourceFilesParentDir,
        [Parameter(Mandatory=$true)]
        [string]$SQLSrvUnattendName,
        [Parameter(Mandatory=$true)]
        [PSCredential]$CMSQLServiceAccountCredential,
        [Parameter(Mandatory=$true)]
        [PSCredential]$CMSQLServerSAAccountCredential
    )    
    
    $ErrorActionPreference = "stop"
    
    $SQLSrvUnattend = Get-AutomationVariable $SQLSrvUnattendName

    $CMSQLServiceAccountCredentialPassword = $CMSQLServiceAccountCredential.GetNetworkCredential().Password # GetNetworkCredential().Password used to retreive password in clear text
    $CMSQLServerSAAccountCredentialPassword = $CMSQLServerSAAccountCredential.GetNetworkCredential().Password # GetNetworkCredential().Password used to retreive password in clear text
   
    inlinescript {
        $SourceFilesParentDir = $using:SourceFilesParentDir
        $SQLSrvUnattend = $using:SQLSrvUnattend
        $CMSQLServiceAccountCredentialPassword = $using:CMSQLServiceAccountCredentialPassword
        $CMSQLServerSAAccountCredentialPassword = $using:CMSQLServerSAAccountCredentialPassword
        $SQLSrvHostname = $using:VMName
        [int]$SQLSrvInstanceTcpPort = 1433 # Default SQL TCP port that must be used for CM instance
        [int]$SQLServerMinMemory = 1024 # Recommendend MinMemory for CM SQLserver is 8GB(8192MB)
                
        try {
            Write-Verbose "Starting SQLserver installation"
            if (Test-Path "$SourceFilesParentDir\SQL\SQL2014\Setup.exe") {
                # Save SQL unattendedconfiguration from SMA Asset to answerfile
                $SQLSrvUnattend | Out-File "$SourceFilesParentDir\SQL\SQL2014\ConfigurationFile.ini" -Encoding utf8
                # Save SQL commandline arguments as array
                $SQLSrvUnattendArg = @("/ConfigurationFile=$([char]34)$SourceFilesParentDir\SQL\SQL2014\ConfigurationFile.ini$([char]34)","/SQLSVCPASSWORD=$([char]34)$CMSQLServiceAccountCredentialPassword$([char]34)","/AGTSVCPASSWORD=$([char]34)$CMSQLServiceAccountCredentialPassword$([char]34)","/SAPWD=$([char]34)$CMSQLServerSAAccountCredentialPassword$([char]34)")
                # Call SQL Setup.exe with arguments for unattended installation
                $SQLSrvInstallJob = Start-Job -Name 'SQLSrvInstall'  -ScriptBlock {
    		        param(
        		        [parameter(Mandatory=$true)]
        			    $SQLSrvUnattendArg,
                        [parameter(Mandatory=$true)]
        			    $SourceFilesParentDir
                    )
    			    Start-Process -FilePath "$SourceFilesParentDir\SQL\SQL2014\Setup.exe" -ArgumentList $SQLSrvUnattendArg -Wait
			    
                } -ArgumentList $SQLSrvUnattendArg, $SourceFilesParentDir
			    
                # Wait for installation to finish
                While (($SQLSrvInstallJob | get-job).State -eq 'Running') {
                    Write-Output "Heartbeat from SQLServer Installation...."
                    Start-Sleep -Seconds 60
                }
                # Verify SQL installation
                if (($LASTEXITCODE = '0') -or ($LASTEXITCODE = '3010')) {
                    Write-Output "SQLServer installed successfully"
                }
                else {
                    Write-Error "SQLServer installation failed"
                    Throw "SQLServer installation failed"
                }
            }
            else {
                Write-Error "Could not find $SourceFilesParentDir\SQL\SQL2014\Setup.exe , unable to install SQLServer"
                Throw "Unable to locate SQLServer Setup.exe"
            }
        }
        catch {
            Write-Verbose "Failed to install SQLServer"
            Write-Error $_.Exception
        }
        try {
            # Configure SQLServer TCP/IP Ports(Set static 1433 port), Windows Firewall and Memory
            Write-Verbose "Starting postinstall SQL Configuration" 
            # Add Assemblies from SQLServer .dll's(Version 12.0.0.0 equals SQLServer 2014)
            Add-Type -AssemblyName "Microsoft.SqlServer.ConnectionInfo, Version=12.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -ErrorAction Stop

            Add-Type -AssemblyName "Microsoft.SqlServer.Smo, Version=12.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -ErrorAction Stop

            Add-Type -AssemblyName "Microsoft.SqlServer.SMOExtended, Version=12.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -ErrorAction Stop

            Add-Type -AssemblyName "Microsoft.SqlServer.SqlEnum, Version=12.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -ErrorAction Stop

            Add-Type -AssemblyName "Microsoft.SqlServer.Management.Sdk.Sfc, Version=12.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -ErrorAction Stop

            Add-Type -AssemblyName "Microsoft.SqlServer.SqlWmiManagement, Version=12.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -ErrorAction Stop

            # Create SQL Server objects
            [array]$SQLSrvInstanceName = (select-string -path "$SourceFilesParentDir\SQL\SQL2014\ConfigurationFile.ini" -pattern "INSTANCENAME=" -allmatches –simplematch).Line.Split('"')
            $SQLServerSMO = New-Object Microsoft.SqlServer.Management.Smo.Server("cm01\$($SQLSrvInstanceName[1])")
            $SQLServerWMI= New-Object ("Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer") $env:COMPUTERNAME

            # Set Named Instance TCP port and disable TCP Dynamic Ports
            Write-Verbose "Setting Named Instance TCP port and disable TCP Dynamic Ports"
            $SQLServerWMI.ServerInstances["$($SQLSrvInstanceName[1])"].ServerProtocols["Tcp"].IPAddresses["IPAll"].IPAddressProperties["TcpPort"].value = "$SQLSrvInstanceTcpPort"
            $SQLServerWMI.ServerInstances["$($SQLSrvInstanceName[1])"].ServerProtocols["Tcp"].IPAddresses["IPAll"].IPAddressProperties["TcpDynamicPorts"].value = [System.String]::Empty

            # Commit the changes by calling the Alter method
            $SQLServerWMI.ServerInstances["$($SQLSrvInstanceName[1])"].ServerProtocols["Tcp"].Alter()

            # Set Min and Max SQLServer memory
            Write-Verbose "Setting Min and Max SQLServer memory"
            [int]$SQLServerMaxMemory = ($SQLServerSMO.PhysicalMemory) / 2 # Recommended MaxMemory for CM SQLServers is half och the installed RAM
            
            $SQLServerSMO.Configuration.MinServerMemory.ConfigValue = $SQLServerMinMemory # 8192 (MB) recommended for CM, make sure you have minimum 16GB RAM total
            $SQLServerSMO.Configuration.MaxServerMemory.ConfigValue = $SQLServerMaxMemory

            # Commit the changes by calling the Alter method
            $SQLServerSMO.Alter()

            # Set Firewall inbound rules for SQL
            Write-Verbose "Setting Firewall inbound rules for SQL"            
            # New-NetFirewallRule -DisplayName "SQL Admin Connection" -Direction Inbound –Protocol TCP –LocalPort 1434 -Action allow
            # New-NetFirewallRule -DisplayName "SQL Debugger/RPC" -Direction Inbound –Protocol TCP –LocalPort 135 -Action allow
            New-NetFirewallRule -DisplayName "SQL Server" -Direction Inbound –Protocol TCP –LocalPort 1433 -Action allow
            New-NetFirewallRule -DisplayName "SQL Service Broker" -Direction Inbound –Protocol TCP –LocalPort 4022 -Action allow
            
            Write-Output "Successfully configured SQLserver(TCPPort, MinMax Memory and Windows Firewall)"                 
        }
        catch {
            Write-Verbose "Failed to configure SQLServer TCPPorts and Memory"
            Write-Error $_.Exception
        }
                    
    } -PSComputerName $VMName -PSCredential $VMCredential -PSAuthentication CredSSP # CredSSP required for SQLsetup to be able to verify password on ADAccount
	
	Write-Verbose "Restarting computer $VMName to complete SQLServer installation"
	Restart-Computer -PSComputerName $VMName -PSCredential $VMCredential -Wait -For WinRM -Force
}