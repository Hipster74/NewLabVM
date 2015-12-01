workflow Install-ADK10
{
    [OutputType([string])]
    param(
        [Parameter(Mandatory=$true)]
        [string]$VMName,
		[Parameter(Mandatory=$true)]
		[PSCredential] $VMCredential,
        [Parameter(Mandatory=$true,HelpMessage="Default is datadisk on d:\Source")]
        [string]$SourceFilesParentDir
    )    
    $UserName = $VMCredential.UserName

    inlinescript {
        $UserName = $using:UserName
		$SourceFilesParentDir = $using:SourceFilesParentDir
                        
        # Check if Username in credential contains \ for domain login, remove domainpart if so
		if ($UserName.Contains('\')) {
			$UserName = ($UserName.Split('\'))[1]
		}
		
		try {
            Write-Verbose "Starting ADK10 installation"
            if (Test-Path "$SourceFilesParentDir\ADK\ADK10\adksetup.exe") {
                # Save ADK 10 commandline arguments as array
				$ADK10UnattendArg = @("/Features OptionId.WindowsPreinstallationEnvironment OptionId.UserStateMigrationTool OptionId.DeploymentTools /norestart /quiet /ceip off")
				# Call adksetup.exe with arguments for unattended installation
				$ADK10InstallJob = Start-Job -Name 'ADK10Install'  -ScriptBlock {
    				param(
        		        [parameter(Mandatory=$true)]
        			    $ADK10UnattendArg,
                        [parameter(Mandatory=$true)]
        			    $SourceFilesParentDir
                    )
    			    Start-Process -FilePath "$SourceFilesParentDir\ADK\ADK10\adksetup.exe" -ArgumentList $ADK10UnattendArg -Wait
			    
                } -ArgumentList $ADK10UnattendArg, $SourceFilesParentDir
			    
               # Wait for installation to finish
               While (($ADK10InstallJob | Get-Job).State -eq 'Running') {
                   Write-Output "Heartbeat from ADK 10 Installation...."
                   Start-Sleep -Seconds 60
               }
				# Verify ADK 10 installation
                $USMTTrue = (Select-String -Path $(Get-ChildItem "$env:SystemDrive\users\$UserName\appdata\local\temp\adk" -Filter '*UserStateMigrationTool*.log') -Pattern "Installation success or error status: 0" -AllMatches -SimpleMatch)
				$WinPETrue = (Select-String -Path $(Get-ChildItem "$env:SystemDrive\users\$UserName\appdata\local\temp\adk" -Filter '*WindowsPEx86x64wims*.log') -Pattern "Installation success or error status: 0" -AllMatches -SimpleMatch)
				if ($USMTTrue -and $WinPETrue) {
                    Write-Output "ADK 10 installed successfully"
                }
                else {
                    Write-Error "ADK 10 installation failed"
                    Throw "ADK 10 installation failed"
                }
            }
            
            else {
                Write-Error "Could not find $SourceFilesParentDir\ADK\ADK10\adksetup.exe , unable to install ADK10"
                Throw "Unable to locate ADK10 adksetup.exe"
            }
        }
        catch {
            Write-Verbose "Failed to install ADK10"
            Write-Error $_.Exception
        }
    } -PSComputerName $VMName -PSCredential $VMCredential
}