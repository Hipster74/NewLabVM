workflow Config-CMShares{
 
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory=$true)]
        [string]$VMName,
        [Parameter(Mandatory=$true)]
        [PSCredential]$CMNetworkAccountCredential,
        [Parameter(Mandatory=$false)]
        [string]$CMSharesParentFolder = 'D:\Shares',
		[Parameter(Mandatory=$true)]
        [PSCredential] $VMCredential
    )    
    
    #$CMNetworkAccountCredentials = Get-AutomationPSCredential -Name $CMNetworkAccountCredentialsName

    Inlinescript {

        #Set the Following Parameters
        $Source = $using:CMSharesParentFolder
        $ShareNamePackages = 'Packages$'
        $ShareNameLogs = 'Logs$'
        $ShareNameImages = 'Images$'
        $ShareNameMedia = 'Media$'
        $ShareNamePublicMedia = 'PublicMedia$'
        $NetworkAccount = $using:CMNetworkAccountCredential.UserName

        Write-Verbose "Given Network Access Account - $NetworkAccount"
    
        #Create Source Directory
        New-Item -ItemType Directory -Path "$Source"
    
        #Create Application Directory Structure Windows
        Write-Verbose "Create Application Directory Structure for Windows"
        New-Item -ItemType Directory -Path "$Source\Packages\Adobe" -Force
        New-Item -ItemType Directory -Path "$Source\Packages\Citrix"
        New-Item -ItemType Directory -Path "$Source\Packages\Sun"
        New-Item -ItemType Directory -Path "$Source\Packages\Microsoft"
        New-Item -ItemType Directory -Path "$Source\Packages\OSD - Bootimages"
        New-Item -ItemType Directory -Path "$Source\Packages\OSD - JoinDomain"
        New-Item -ItemType Directory -Path "$Source\Packages\OSD - MDT"
        New-Item -ItemType Directory -Path "$Source\Packages\OSD - Settings"

        #Create Application Directory Structure Mac
        Write-Verbose "Create Application Directory Structure for Mac"
        New-Item -ItemType Directory -Path "$Source\Packages\Applications\MacOS\Adobe" -Force
        New-Item -ItemType Directory -Path "$Source\Packages\Applications\MacOS\Apple"
        New-Item -ItemType Directory -Path "$Source\Packages\Applications\MacOS\Citrix"
        New-Item -ItemType Directory -Path "$Source\Packages\Applications\MacOS\Microsoft"
        New-Item -ItemType Directory -Path "$Source\Packages\Applications\MacOS\Telecomputing"
    
        #Create Publicmedia Directory Structure
        New-Item -ItemType Directory -Path "$Source\PublicMedia\Telecomputing\CMEnroll" -Force

        #Create Hardware Application Directory Structure
        Write-Verbose "Create Hardware Application Directory Structure"
        New-Item -ItemType Directory -Path "$Source\Packages\HardwareApps"
        New-Item -ItemType Directory -Path "$Source\Packages\HardwareApps\Dell"
        New-Item -ItemType Directory -Path "$Source\Packages\HardwareApps\HP"
        New-Item -ItemType Directory -Path "$Source\Packages\HardwareApps\Lenovo"
    
        #Create Media Directory Structure
        Write-Verbose "Create Media Directory Structure"
        New-Item -ItemType Directory -Path "$Source\Media\OS\Windows 7 SP1 Enterprise Eng X64" -Force
        New-Item -ItemType Directory -Path "$Source\Media\OS\Windows 7 SP1 Enterprise Eng X86"
        New-Item -ItemType Directory -Path "$Source\Media\OS\Windows 8 Enterprise Eng X64"
        New-Item -ItemType Directory -Path "$Source\Media\OS\Windows 10 Enterprise Eng X64"
        New-Item -ItemType Directory -Path "$Source\Media\Drivers\Dell\Win7\x64" -Force
        New-Item -ItemType Directory -Path "$Source\Media\Drivers\Dell\Win7\x86"
        New-Item -ItemType Directory -Path "$Source\Media\Drivers\Dell\Win8\x64" -Force
        New-Item -ItemType Directory -Path "$Source\Media\Drivers\Dell\Win10\x64" -Force
        New-Item -ItemType Directory -Path "$Source\Media\Drivers\HP\Win7\x64" -Force
        New-Item -ItemType Directory -Path "$Source\Media\Drivers\HP\Win7\x86"
        New-Item -ItemType Directory -Path "$Source\Media\Drivers\HP\Win8\x64" -Force
        New-Item -ItemType Directory -Path "$Source\Media\Drivers\HP\Win10\x64" -Force
        New-Item -ItemType Directory -Path "$Source\Media\Drivers\Lenovo\Win7\x64" -Force
        New-Item -ItemType Directory -Path "$Source\Media\Drivers\Lenovo\Win7\x86"
        New-Item -ItemType Directory -Path "$Source\Media\Drivers\Lenovo\Win8\x64" -Force
        New-Item -ItemType Directory -Path "$Source\Media\Drivers\Lenovo\Win10\x64" -Force
        New-Item -ItemType Directory -Path "$Source\Media\Drivers\WinPE 4.0 x64"
        New-Item -ItemType Directory -Path "$Source\Media\Drivers\WinPE 5.0 x64"
        New-Item -ItemType Directory -Path "$Source\Media\Drivers\WinPE 6.0 x64"
    
        #Create Log Directory Structure
        Write-Verbose "Create Log Directory Structure"
        New-Item -ItemType Directory -Path "$Source\Logs"
    
        #Create Images Directory Structure
        Write-Verbose "Create Images Directory Structure"
        New-Item -ItemType Directory -Path "$Source\Images"
    
        #Create Configmanager Backupfolder
        Write-Verbose "Create Configmanager Backupfolder"
        New-Item -ItemType Directory -Path "$Source\ConfigMgrBackup"
    
        #Create Migration Data folder
        Write-Verbose "Create Migration Data folder"
        New-Item -ItemType Directory -Path "$Source\Migdata"
    
        #Create the Share and Permissions, delete first to make sure sharename is not in use
        Write-Verbose "Create the Share and Permissions"
        Remove-SmbShare -Name "$ShareNamePackages" -Force
        Remove-SmbShare -Name "$ShareNameLogs" -Force
        Remove-SmbShare -Name "$ShareNameImages" -Force
        Remove-SmbShare -Name "$ShareNameMedia" -Force
        Remove-SmbShare -Name "$ShareNamePublicMedia" -Force
        New-SmbShare -Name "$ShareNamePackages" -Path "$Source\Packages" -CachingMode None -ChangeAccess Everyone -Description 'ConfigMgr Sourcefiles'
        New-SmbShare -Name "$ShareNameLogs" -Path "$Source\Logs" -CachingMode None -ChangeAccess Everyone -Description 'ConfigMgr Task Sequence Logfiles'
        New-SmbShare -Name "$ShareNameImages" -Path "$Source\Images" -CachingMode None -ChangeAccess Everyone -Description 'ConfigMgr OS Images'
        New-SmbShare -Name "$ShareNameMedia" -Path "$Source\Media" -CachingMode None -ChangeAccess Everyone -Description 'ConfigMgr OS Media'
        New-SmbShare -Name "$ShareNamePublicMedia" -Path "$Source\PublicMedia" -CachingMode None -ReadAccess Everyone -Description 'ConfigMgr Public Media'
    
        #Set Security Permissions on folders
        Write-Verbose "Set Security Permissions on folders"
        $Acl = Get-Acl "$Source\Packages"
        $Ar = New-Object System.Security.AccessControl.FileSystemAccessRule("Everyone","Modify", "ContainerInherit, ObjectInherit", "None", "Allow")
        $Acl.SetAccessRule($Ar)
        Set-Acl "$Source\Packages" $Acl
    
        $Acl = Get-Acl "$Source\Logs"
        $Ar = New-Object System.Security.AccessControl.FileSystemAccessRule("$NetworkAccount","Modify", "ContainerInherit, ObjectInherit", "None", "Allow")
        $Acl.SetAccessRule($Ar)
        Set-Acl "$Source\Logs" $Acl
    
        $Acl = Get-Acl "$Source\Images"
        $Ar = New-Object System.Security.AccessControl.FileSystemAccessRule("$NetworkAccount","Modify", "ContainerInherit, ObjectInherit", "None", "Allow")
        $Acl.SetAccessRule($Ar)
        Set-Acl "$Source\Images" $Acl
    
        $Acl = Get-Acl "$Source\Media"
        $Ar = New-Object System.Security.AccessControl.FileSystemAccessRule("Everyone","Modify", "ContainerInherit, ObjectInherit", "None", "Allow")
        $Acl.SetAccessRule($Ar)
        Set-Acl "$Source\Media" $Acl

        $Acl = Get-Acl "$Source\PublicMedia"
        $Ar = New-Object System.Security.AccessControl.FileSystemAccessRule("Everyone","Read", "ContainerInherit, ObjectInherit", "None", "Allow")
        $Acl.SetAccessRule($Ar)
        Set-Acl "$Source\PublicMedia" $Acl
    
        Write-Verbose "Done creating folderstructure"
    
        #Create NO_SMS_ON_DRIVE file in all partitionroots except D:
        Write-Verbose "Create NO_SMS_ON_DRIVE file in all partitionroots except D:"
        Get-PSDrive -PSProvider FileSystem | ForEach-Object {if (!($_.Name -eq "D")) {New-Item -ItemType File -Path "$($_.Root)NO_SMS_ON_DRIVE"}} | Out-Null

    } -PSComputerName $VMName -PSCredential $VMCredential


}