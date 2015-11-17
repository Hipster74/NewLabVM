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
    
    inlinescript {
        $SourceFilesParentDir = $using:SourceFilesParentDir
                        
        try {
            Write-Verbose "Starting ADK10 installation"
            if (Test-Path "$SourceFilesParentDir\ADK\ADK10\adksetup.exe") {
                $ADK10UnattendArg = @("/Features","OptionId.DeploymentTools","OptionId.WindowsPreinstallationEnvironment","OptionId.UserStateMigrationTool","/norestart","/quiet","/ceip","off")
                # Call adksetup.exe with arguments for unattended installation
                & "$SourceFilesParentDir\ADK\ADK10\adksetup.exe" $ADK10UnattendArg
                # Verify ADK10 installation
                if (($LASTEXITCODE = '0') -or ($LASTEXITCODE = '3010')) {
                    Write-Output "ADK10 installed successfully"
                }
                else {
                    Write-Error "SQLServer installation failed"
                    Throw "ADK10 installation failed"
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