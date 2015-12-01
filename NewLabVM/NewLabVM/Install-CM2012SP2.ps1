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
                $CM2012SP2Unattend | Out-File "$SourceFilesParentDir\SystemCenter\ConfigMgr2012wSP2\ConfigMgr2012Unattend.ini" -Encoding unicode
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
		# Integrate MDT with Configuration Manager
		# Get Configuration Manager sitecode from WMI
		$CMSiteCode = (Get-WmiObject -ComputerName $env:COMPUTERNAME -Namespace "root\SMS" -Class "SMS_ProviderLocation").SiteCode

		# Get Configuration Manager 2012 Console installation path from registry
		$CM12Path = (Get-ItemProperty "HKLM:\Software\Microsoft\ConfigMgr10\Setup" -Name "UI Installation Directory" -ErrorAction SilentlyContinue).'UI Installation Directory'

		if ($CM12Path -ne $null) {
			Write-Verbose "Found Configuration Manager 2012 Console installation at $CM12Path"

		} else {
			$CM12Path = (Get-ItemProperty "HKLM:\Software\wow6432node\Microsoft\ConfigMgr10\Setup" -Name "UI Installation Directory" -ErrorAction SilentlyContinue).'UI Installation Directory'
    
			if ($CM12Path -ne $null){
				Write-Verbose "Found Configuration Manager 2012 Console(32-bit) installation at $CM12Path"
    
			} else {
				Write-Error "Unable to locate Configuration Manager 2012 Console installation path from registry, aborting MDT integration"
				Throw "Unable to locate Configuration Manager 2012 Console installation path from registry"  
			}
		}

		# Get MDT Installation path from registry
		$MDTPath = (Get-ItemProperty "HKLM:\Software\Microsoft\Deployment 4" -name Install_Dir -ErrorAction SilentlyContinue).Install_Dir
		if ($MDTPath -ne $null) {
			Write-Verbose "Found MDT installation path $MDTPath"

		} else {
			Write-Error "Unable to locate MDT installation path from registry, aborting MDT integration"
			Throw "Unable to locate MDT installation path from registry"  
		}

		# Integrating MDT into the ConfigMgr 2012 console
		Write-Verbose "Integrating MDT into the Configuration Manager 2012 console"
		Copy-Item -Path "$MDTPath\Bin\Microsoft.BDD.CM12Actions.dll" -Destination "$CM12Path\Bin\Microsoft.BDD.CM12Actions.dll" -Force
		Copy-Item -Path "$MDTPath\Bin\Microsoft.BDD.Workbench.dll" -Destination "$CM12Path\Bin\Microsoft.BDD.Workbench.dll" -Force
		Copy-Item -Path "$MDTPath\Bin\Microsoft.BDD.ConfigManager.dll" -Destination "$CM12Path\Bin\Microsoft.BDD.ConfigManager.dll" -Force
		Copy-Item -Path "$MDTPath\Bin\Microsoft.BDD.CM12Wizards.dll" -Destination "$CM12Path\Bin\Microsoft.BDD.CM12Wizards.dll" -Force
		Copy-Item -Path "$MDTPath\Bin\Microsoft.BDD.PSSnapIn.dll" -Destination "$CM12Path\Bin\Microsoft.BDD.PSSnapIn.dll" -Force
		Copy-Item -Path "$MDTPath\Bin\Microsoft.BDD.Core.dll" -Destination "$CM12Path\Bin\Microsoft.BDD.Core.dll" -Force
		Copy-Item -Path "$MDTPath\Templates\CM12Extensions\*" -Destination "$CM12Path\XmlStorage\Extensions" -Force -Recurse

		# Edit MOFFile with settings for our CMSite
		Write-Verbose "Edit MOFFile with settings for our CMSite"
		(Get-Content "$MDTPath\SCCM\Microsoft.BDD.CM12Actions.mof").replace('%SMSSERVER%', "$env:COMPUTERNAME") | Set-Content "$env:SystemRoot\temp\Microsoft.BDD.CM12Actions.mof"
		(Get-Content "$env:SystemRoot\temp\Microsoft.BDD.CM12Actions.mof").replace('%SMSSITECODE%', "$CMSiteCode") | Set-Content "$env:SystemRoot\temp\Microsoft.BDD.CM12Actions.mof"

		# Running mofcomp to compile new MOFFile, this must be done to be able to create MDT Task sequences etc. in CM console
		Write-Verbose "Compiling MOFFile $env:SystemRoot\temp\Microsoft.BDD.CM12Actions.mof with MOFComp.exe"
		& mofcomp.exe "$env:SystemRoot\temp\Microsoft.BDD.CM12Actions.mof"
                           
    } -PSComputerName $VMName -PSCredential $VMCredential -PSAuthentication CredSSP # CredSSP required for Configuration Manger Setup to be able to verify Active Directory connection
}