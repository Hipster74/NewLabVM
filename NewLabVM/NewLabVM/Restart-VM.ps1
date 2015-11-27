Workflow Restart-VM {
	[OutputType([string])]
    param(
        [Parameter(Mandatory=$true)]
        [string]$VMName,
		[Parameter(Mandatory=$true)]
		[PSCredential] $VMCredential
    )    

	Write-Verbose "Restarting computer $VMName" -Verbose
	Restart-Computer -PSComputerName $VMName -PSCredential $VMCredential -Wait -For Wmi -Force
	Write-Output "$VMName Restarted"
}