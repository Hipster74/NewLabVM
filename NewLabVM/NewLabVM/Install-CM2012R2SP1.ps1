workflow Install-CM2012R2SP1
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
    
    $ErrorActionPreference = "stop"
    inlinescript {
        $SourceFilesParentDir = $using:SourceFilesParentDir
                        
        try {
            Write-Verbose "Verifying Configuration Manager is installed"
            # Verifying Configuration Manager is installed
			if (Test-Path HKLM:\SOFTWARE\Microsoft\SMS\Setup) {
                Write-Verbose "Configuration Manager version $((Get-ItemProperty HKLM:\SOFTWARE\Microsoft\SMS\Setup)."Full Version") with CULevel $((Get-ItemProperty HKLM:\SOFTWARE\Microsoft\SMS\Setup).CULevel) installed, proceeding"
            }
            else {
                Write-Error "Configuration Manager installation not found, aborting"
                Throw "Configuration Manager installation not found, aborting"
            }

            if (Test-Path "$SourceFilesParentDir\SystemCenter\ConfigMgr2012R2wSP1\SMSSETUP\BIN\X64\Configmgr2012R2SP1.msi") {
                $CM2012R2SP1UnattendArg = @("/qn","/L*v","$env:SystemRoot\Temp\CM2012R2SP1Install.log","REBOOT=ReallySuppress")
                # Call MicrosoftDeploymentToolkit2013_x64.msi with arguments for unattended installation
                & "$SourceFilesParentDir\SystemCenter\ConfigMgr2012R2wSP1\SMSSETUP\BIN\X64\Configmgr2012R2SP1.msi" $CM2012R2SP1UnattendArg
                # Verify CM 2012 R2 with SP1 installation
                if (($LASTEXITCODE = '0') -or ($LASTEXITCODE = '3010')) {
                    Write-Output "Configuration Manager 2012 R2 with SP1 installed successfully"
                }
                else {
                    Write-Error "Configuration Manager 2012 R2 with SP1 installation failed"
                    Throw "CM 2012 R2 with SP1 installation failed"
                }
            }
            else {
                Write-Error "Could not find $SourceFilesParentDir\SystemCenter\ConfigMgr2012R2wSP1\SMSSETUP\BIN\X64\Configmgr2012R2SP1.msi , unable to install CM 2012 R2 with SP1"
                Throw "Unable to locate MicrosoftDeploymentToolkit2013_x64.msi"
            }
        }
        catch {
            Write-Verbose "Failed to install CM 2012 R2 with SP1"
            Write-Error $_.Exception
        }
    } -PSComputerName $VMName -PSCredential $VMCredential
}