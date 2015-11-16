workflow Enable-CredSSP {
	Param(
		[Parameter(Mandatory=$true)]
        [string]$VMName,
		[Parameter(Mandatory=$true)]
        [PSCredential]$VMCredential
	)
	# Enable CredSSP Client on Azure Automation Hybrid Worker
	Write-Host "Enabling CredSSP Client * on Azure Automation Hybrid Worker"
	Enable-WSManCredSSP -Role Client -DelegateComputer * -Force
    
	Inlinescript { 
		$VMName = $using:VMName
		# Enable CredSSP Server on Configuration Manager Server
        Write-Verbose "Enabling CredSSP Server on $VMName"
		Enable-WSManCredSSP -Role Server -Force
    } -PSComputerName $VMName -PSCredential $VMCredential

}