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
            if (Test-Path "$SourceFilesParentDir\MDT\MicrosoftDeploymentToolkit2013_x64.msi") {
                $MDT2013U1UnattendArg = @("/qn","/L*v","$env:SystemRoot\Temp\MDT2013U1Install.log","REBOOT=ReallySuppress")
                # Call MicrosoftDeploymentToolkit2013_x64.msi with arguments for unattended installation
                & "$SourceFilesParentDir\MDT\MicrosoftDeploymentToolkit2013_x64.msi" $MDT2013U1UnattendArg
                # Verify MDT 2013 Update 1 installation
                if (select-string -path "$env:SystemRoot\Temp\MDT2013U1Install.log" -pattern "Installation success or error status: 0" -allmatches –simplematch) {
                    Write-Verbose "MDT 2013 Update 1 installed successfully"
                }
                else {
                    Write-Error "MDT 2013 Update 1 installation failed"
                    Throw "MDT 2013 Update 1 installation failed"
                }
            }
            else {
                Write-Error "Could not find $SourceFilesParentDir\MDT\MicrosoftDeploymentToolkit2013_x64.msi , unable to install MDT 2013 Update 1"
                Throw "Unable to locate MicrosoftDeploymentToolkit2013_x64.msi"
            }
        }
        catch {
            Write-Verbose "Failed to install MDT 2013 Update 1"
            Write-Error $_.Exception
        }
    } -PSComputerName $VMName -PSCredential $VMCredential
}