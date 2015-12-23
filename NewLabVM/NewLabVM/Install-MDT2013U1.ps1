workflow Install-MDT2013U1
{
    [OutputType([string])]
    param(
        [Parameter(Mandatory=$true)]
        [string]$VMName,
		[Parameter(Mandatory=$true)]
		[PSCredential] $VMCredential,
        [Parameter(Mandatory=$true,HelpMessage="Default is datadisk on e:\Source")]
        [string]$SourceFilesParentDir
    )    
    
    inlinescript {
        $SourceFilesParentDir = $using:SourceFilesParentDir
                        
        try {
            Write-Verbose "Starting MDT 2013 Update 1 installation"
            if (Test-Path "$SourceFilesParentDir\MDT\2013U1\MicrosoftDeploymentToolkit2013_x64.msi") {
                # Save MDT 2013 Update 1 commandline arguments as array
                $MDT2013U1UnattendArg = @("/qn","/L*v","$env:SystemRoot\Temp\MDT2013U1Install.log","REBOOT=ReallySuppress")
                # Call MDT 2013 Update 1 MSI with arguments for unattended installation
                $MDT2013U1InstallJob = Start-Job -Name 'MDT2013U1Install'  -ScriptBlock {
    		        param(
        		        [parameter(Mandatory=$true)]
        			    $MDT2013U1UnattendArg,
                        [parameter(Mandatory=$true)]
        			    $SourceFilesParentDir
                    )
    			    Start-Process -FilePath "$SourceFilesParentDir\MDT\2013U1\MicrosoftDeploymentToolkit2013_x64.msi" -ArgumentList $MDT2013U1UnattendArg -Wait
			    
                } -ArgumentList $MDT2013U1UnattendArg, $SourceFilesParentDir
			    
                # Wait for installation to finish
                While (($MDT2013U1InstallJob | Get-Job).State -eq 'Running') {
                    Write-Output "Heartbeat from MDT 2013 Update 1 Installation...."
                    Start-Sleep -Seconds 60
                }
				# Verify MDT 2013 Update 1 installation
                if (select-string -Path "$env:SystemRoot\Temp\MDT2013U1Install.log" -Pattern "Installation success or error status: 0" -AllMatches -SimpleMatch) {
                    Write-Output "MDT 2013 Update 1 installed successfully"
                }
                else {
                    Write-Error "MDT 2013 Update 1 installation failed"
                    Throw "MDT 2013 Update 1 installation failed"
                }
            }
            else {
                Write-Error "Could not find $SourceFilesParentDir\MDT\2013U1\MicrosoftDeploymentToolkit2013_x64.msi , unable to install MDT 2013 Update 1"
                Throw "Unable to locate MicrosoftDeploymentToolkit2013_x64.msi"
            }
        }
        catch {
            Write-Verbose "Failed to install MDT 2013 Update 1"
            Write-Error $_.Exception
        }
    } -PSComputerName $VMName -PSCredential $VMCredential
}