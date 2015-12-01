workflow Extend-ADSchema
{
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory=$true)]
        [string]$VMName,
		[Parameter(Mandatory=$true)]
		[PSCredential] $VMCredential,
        [Parameter(Mandatory=$true,HelpMessage="Default is datadisk on d:\Source")]
        [string]$SourceFilesParentDir
    )    
    Inlinescript {
        $SourceFilesParentDir = $using:SourceFilesParentDir
        try {
            Write-Verbose "Starting Active Directory Schema Extension"
            if (Test-Path "$SourceFilesParentDir\SystemCenter\ConfigMgr2012wSP2\SMSSETUP\BIN\X64\extadsch.exe") {
                & "$SourceFilesParentDir\SystemCenter\ConfigMgr2012wSP2\SMSSETUP\BIN\X64\extadsch.exe"
                # Verify Schema Extension
                if (select-string -path "$env:SystemDrive\ExtADSch.log" -pattern "Successfully extended the Active Directory schema" -allmatches –simplematch) {
                    Write-Verbose "Active Directory Schema succesfully extended"
                }
                else {
                    Write-Error "Unable to determine if Active Directory Schema Extension succeded"
                    Throw "Unable to determine if Active Directory Schema Extension succeded"
                }
            }
            else {
                Write-Error "Could not find $SourceFilesParentDir\SystemCenter\ConfigMgr2012wSP2\SMSSETUP\BIN\X64\extadsch.exe , unable to extend Active Directory Schema"
                Throw "Unable to locate extadsch.exe"
            }
        }
        catch {
            Write-Verbose "Failed to extend Active Directory Schema"
            Write-Error $_.Exception
        }            
    } -PSComputerName $VMName -PSCredential $VMCredential -PSAuthentication CredSSP
}