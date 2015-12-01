Workflow Install-CMPrimarySiteWinFeatures 
{
    Param (
        [Parameter(Mandatory=$true)]
        [string]$VMName,
		[Parameter(Mandatory=$true)]
        [PSCredential]$VMCredential,
        [Parameter(Mandatory=$false)]
        [switch]$MacSupport
    )
    
    inlinescript {
        $MacSupport = $using:MacSupport

        $CMPrimarySiteWinFeatures = @("NET-Framework-Core","BITS","BITS-IIS-Ext","BITS-Compact-Server","RDC","WAS-Process-Model","WAS-Config-APIs","WAS-Net-Environment","Web-Server","Web-ISAPI-Ext","Web-ISAPI-Filter","Web-Net-Ext","Web-Net-Ext45","Web-ASP-Net","Web-ASP-Net45","Web-ASP","Web-Windows-Auth","Web-Basic-Auth","Web-URL-Auth","Web-IP-Security","Web-Scripting-Tools","Web-Mgmt-Service","Web-Stat-Compression","Web-Dyn-Compression","Web-Metabase","Web-WMI","Web-HTTP-Redirect","Web-Log-Libraries","Web-HTTP-Tracing","UpdateServices-RSAT","UpdateServices-API","UpdateServices-UI")
        $CMMacSupportWinFeatures = @("Web-Server","Web-WebServer","Web-Default-Doc","Web-Dir-Browsing","Web-Http-Errors","Web-Static-Content","Web-Http-Logging","Web-Stat-Compression","Web-Filtering","Web-Windows-Auth","Web-Net-Ext","Web-Net-Ext45","Web-Asp-Net","Web-Asp-Net45","Web-ISAPI-Ext","Web-ISAPI-Filter","Web-Mgmt-Console","Web-Metabase","NET-HTTP-Activation","NET-Framework-Core","NET-Framework-Features","NET-Framework-45-Features","NET-Framework-45-Core","NET-Framework-45-ASPNET","NET-WCF-Services45","NET-WCF-TCP-PortSharing45")
        if ($MacSupport) {
            Write-Verbose "Features requierd for installing Macsupport in CM requested"
            $CMPrimarySiteWinFeatures = $CMPrimarySiteWinFeatures + $CMMacSupportWinFeatures
        }
           
        $FeatureFail = 0
        $FeatureRestart = 0
        $FeatureSkipped = 0
        
        foreach ($Feature in $CMPrimarySiteWinFeatures) {
            $CurrentFeatureDisplayName = (Get-WindowsFeature -Name $Feature).DisplayName
            Write-Verbose "Starting installation of Windows Feature $CurrentFeatureDisplayName" -Verbose
            if (!(Get-WindowsFeature -Name $Feature).installed) {
                Write-Verbose "Windows Feature $CurrentFeatureDisplayName not installed, installing now" -Verbose
                Start-Job -Name $Feature -ScriptBlock {
    		        param(
        		        [parameter(Mandatory=$true)]
        			    $Feature
    			    )
    			        Add-WindowsFeature $Feature
			    } -ArgumentList $Feature | Out-Null
			    Wait-Job -Name $Feature
                $FeatureJob = Receive-Job -Name $Feature -Keep
                Write-Verbose "Exit Code from Windows Feature $CurrentFeatureDisplayName installation was $($FeatureJob.ExitCode)" -Verbose
                if ($FeatureJob.ExitCode -eq 'Success') {
                    Write-Verbose "Installation of Windows Feature $CurrentFeatureDisplayName was successful" -Verbose
                }
                elseif ($FeatureJob.ExitCode -eq 'SuccessRestartRequired') {
                    Write-Verbose "Installation of Windows Feature $CurrentFeatureDisplayName requires a Restart" -Verbose
                    $FeatureRestart++
                }
                else {
                    Write-Verbose "Installation of Windows Feature $CurrentFeatureDisplayName failed" -Verbose
                    $FeatureFail++    
                }
                
                Remove-Job -Name $Feature
            }
            else {
                Write-Verbose "Feature $CurrentFeatureDisplayName already installed, skipping" -Verbose
                $FeatureSkipped++
            }
        }
        
        Write-Output "Windows Features already installed $FeatureSkipped"

        if ($FeatureFail -gt 0) {
            Write-Error "Installation failed for $FeatureFail Windows Features"
            Write-Output "Failed($FeatureFail)"
        }
        elseif (($FeatureFail -eq 0) -and ($FeatureRestart -gt 0)) {
            Write-Verbose "Installation of Windows Features successful, restart needed" -Verbose
            Write-Output "SuccessRestartNeeded"
        }
        else {
            Write-Verbose "Installation of Windows Features successful" -Verbose
            Write-Output "Successfully installed required Windows Features"
        }
        
    } -PSComputerName $VMName -PSCredential $VMCredential
	Write-Verbose "Restarting computer $VMName to complete Windows Features installation"
	Restart-Computer -PSComputerName $VMName -PSCredential $VMCredential -Wait -For WinRM -Force
}