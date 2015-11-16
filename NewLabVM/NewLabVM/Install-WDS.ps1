workflow Install-WDS {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$VMName,
		[Parameter(Mandatory=$true)]
		[PSCredential]$VMCredential
    )
   
    inlinescript {
   
        $CMWDSWinFeatures = @("WDS","WDS-Deployment","WDS-Transport")
        $FeatureFail = 0
        $FeatureRestart = 0
        $FeatureSkipped = 0
        
        foreach ($Feature in $CMWDSWinFeatures) {
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
			    Wait-Job -Name $Feature | Out-Null
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
                
                Remove-Job -Name $Feature | Out-Null
            }
            else {
                Write-Verbose "Feature $CurrentFeatureDisplayName already installed, skipping" -Verbose
                $FeatureSkipped++
            }
        }
        
        Write-Output "Windows Features already installed $FeatureSkipped"

        if ($FeatureFail -gt 0) {
            Write-Error "Installation failed for $FeatureFail WDS Features"
            Write-Output "Failed installing WDS Feature($FeatureFail)"
        }
        elseif (($FeatureFail -eq 0) -and ($FeatureRestart -gt 0)) {
            Write-Verbose "Installation of Windows Features successful, restart needed" -Verbose
            Write-Output "SuccessRestartNeeded for WDS Features"
        }
        else {
            Write-Verbose "Installation of Windows Features successful" -Verbose
            Write-Output "Successfully installed required Windows Features for WDS"
        }
        
    } -PSComputerName $VMName -PSCredential $VMCredential

	Write-Verbose "Restarting computer $VMName to complete Active Directory installation"
	Restart-Computer -PSComputerName $VMName -PSCredential $VMCredential -Wait -For WinRM -Force

    inlinescript {
		$VMName = $using:VMName
		try {    
			$WdsutilInitArg = @("/initialize-server","/server:$VMName","/reminst:$env:SystemDrive\RemoteInstall")
			Write-Verbose "Initializing WDSServer with arguments $WdsutilInitArg"
			& "wdsutil" $WdsutilInitArg
		
			$WdsutilConfigArg = @("/Set-Server","/AnswerClients:All")
			Write-Verbose "Configuring WDSServer with arguments $WdsutilConfigArg"
			& "wdsutil" $WdsutilConfigArg
		} catch {
			$ErrorMessage = $_.Exception.Message
			Write-Verbose "Failed when configuring WDS: $ErrorMessage"
			Write-Error $ErrorMessage
			Break
		}
    } -PSComputerName $VMName -PSCredential $VMCredential -PSAuthentication CredSSP # CredSSP required for WDSUtil
    
    
}