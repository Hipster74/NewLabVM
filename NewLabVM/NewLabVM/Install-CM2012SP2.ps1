workflow Install-CM2012SP2
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
        [string]$CM2012SP2UnattendName
    )    
    
    $ErrorActionPreference = "stop"

    $CM2012SP2Unattend = Get-AutomationVariable $CM2012SP2UnattendName
    
    inlinescript {
        $SourceFilesParentDir = $using:SourceFilesParentDir
        $CM2012SP2Unattend = $using:CM2012SP2Unattend
                
        try {
            Write-Verbose "Starting CM 2012 With SP2 installation"
            if (Test-Path "$SourceFilesParentDir\SystemCenter\ConfigMgr2012wSP2\SMSSETUP\BIN\X64\setup.exe") {
                # Save CM 2012 With SP2 unattendedconfiguration from SMA Asset to answerfile
                $CM2012SP2Unattend | Out-File "$SourceFilesParentDir\SystemCenter\ConfigMgr2012wSP2\ConfigMgr2012Unattend.ini"
                # Save CM 2012 With SP2 commandline arguments as array
                $CM2012SP2UnattendArg = @("/Script","$([char]34)$SourceFilesParentDir\SystemCenter\ConfigMgr2012wSP2\ConfigMgr2012Unattend.ini$([char]34)","/NoUserInput")
                # Call CM 2012 With SP2 Setup.exe with arguments for unattended installation
                $CM2012wSP2InstallJob = Start-Job -Name 'CM2012wSP2Install'  -ScriptBlock {
    		        param(
        		        [parameter(Mandatory=$true)]
        			    $CM2012SP2UnattendArg,
                        [parameter(Mandatory=$true)]
        			    $SourceFilesParentDir
                    )
    			    Start-Process -FilePath "$SourceFilesParentDir\SystemCenter\ConfigMgr2012wSP2\SMSSETUP\BIN\X64\setup.exe" -ArgumentList $CM2012SP2UnattendArg -Wait
			    
                } -ArgumentList $CM2012SP2UnattendArg, $SourceFilesParentDir
			    
                # Wait for installation to finish
                While (($CM2012wSP2InstallJob | get-job).State -eq 'Running') {
                    Write-Output "Heartbeat from Configuration Manager 2012 with SP2 Installation...."
                    Start-Sleep -Seconds 60
                }
                # Verify CM 2012 With SP2 installation
                if (select-string -path "$env:SystemDrive\ConfigMgrAdminUISetupVerbose.log" -pattern "Installation success or error status: 0" -allmatches –simplematch) {
                    Write-Output "Configuration manager 2012 With SP2 installed successfully"
                }
                else {
                    Write-Error "Configuration manager 2012 With SP2 installation failed"
                    Throw "Configuration manager 2012 With SP2 installation failed"
                }
            }
            else {
                Write-Error "Could not find $SourceFilesParentDir\SystemCenter\ConfigMgr2012wSP2\SMSSETUP\BIN\X64\setup.exe , unable to install Configuration manager 2012 With SP2"
                Throw "Unable to locate Configuration manager 2012 With SP2 Setup.exe"
            }
        }
        catch {
            Write-Verbose "Failed to install Configuration manager 2012 With SP2"
            Write-Error $_.Exception
        }
                           
    } -PSComputerName $VMName -PSCredential $VMCredential -PSAuthentication CredSSP # CredSSP required for Configuration Manger Setup to be able to verify Active Directory connection
}