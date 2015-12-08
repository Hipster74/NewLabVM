Workflow Import-ADGPO {
	[OutputType([string[]])]
    param (
        [Parameter(Mandatory=$true)]
		[string] $CustomerDomainController,
		[Parameter(Mandatory=$true)]
        [PSCredential] $VMCredential,
        [Parameter(Mandatory=$true)]
        [string] $GPOLinkOU,
		[Parameter(Mandatory=$true)]
        [string] $GPOName,
		[Parameter(Mandatory=$true)]
        [string] $GPOGuid,
		[parameter(mandatory=$True)]
		[string]$SourceFilesParentDir
        
    )
	
	Inlinescript {
		$GPOLinkOU = $using:GPOLinkOU
		$GPOName = $using:GPOName
		$GPOGuid = $using:GPOGuid
		$SourceFilesParentDir = $using:SourceFilesParentDir

		try {
            Import-Module GroupPolicy
			Import-Module ActiveDirectory

			$GPOLinkOUFullDn = $GPOLinkOU + ',' + (Get-ADDomain).DistinguishedName
			
			# Create new blank GPO, import GPO from backupfolder, link GPO to OU
			New-GPO -Name $GPOName
			Import-GPO -Path "$SourceFilesParentDir\GPO" -BackupId $GPOGuid -TargetName $GPOName
			New-GPLink -Name $GPOName -Target $GPOLinkOUFullDn
                
		} catch {
                Write-Verbose "Failed to import GPO" -Verbose
                Write-Error $_.Exception
				Throw "Failed to import GPO"
        }
        
		
	} -PSComputerName $CustomerDomainController -PSCredential $VMCredential        

}