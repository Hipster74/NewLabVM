﻿Param(
	[parameter(mandatory=$False,HelpMessage="Path and name of WIM file.")]
	[ValidateNotNullOrEmpty()]
	[string]$SourceFile,

	[parameter(mandatory=$True,HelpMessage="Name of XML file with serversettings.")]
	[ValidateNotNullOrEmpty()]
	[string]$SrvSettingsXMLFile,

	[parameter(mandatory=$true,HelpMessage="Name of VM.")]
	[ValidateLength(1,14)]
	$VMName,

	[parameter(mandatory=$true,HelpMessage="VM Location path")]
	[ValidateNotNullOrEmpty()]
	$VMLocation,

	[parameter(mandatory=$true,HelpMessage="Memory in megabytes")]
	[ValidateSet("1024","2048","4096","6144","8192","12288","14336","16384","24576","32768")]
	$VMMemory,

	[parameter(mandatory=$true,HelpMessage="type IP address or type DHCP")]
	[ValidateNotNullOrEmpty()]
	$IPAddress,

	[parameter(mandatory=$false,HelpMessage="VLANID (leave blank for 0")]
	[ValidateNotNullOrEmpty()]
	$VLANID,

	[parameter(mandatory=$true,HelpMessage="Build Based on DIFF disk or CREATE a disk")]
	[ValidateSet("DIFF","CREATE")]
	$DifforCreate,

	[parameter(mandatory=$true,HelpMessage="BIOS or UEFI")]
	[ValidateSet("BIOS","UEFI")]
	$VMType,

	[parameter(mandatory=$false,HelpMessage="ISO image to mount")]
	[ValidateNotNullOrEmpty()]
	$ISO,

	[parameter(mandatory=$false,HelpMessage="Add extra datadisk (size)")]
	[ValidateNotNullOrEmpty()]
	$AddDataDisk="NoDisk",

	[parameter(mandatory=$false,HelpMessage="Join DOMAIN or WORKGROUP")]
	[ValidateSet("DOMAIN","WORKGROUP")]
	$DomainOrWorkGroup,

	[parameter(mandatory=$false,HelpMessage="If VM already exists, delete it")]
	[bool]$Force

)

Function Logit{
$TextBlock1 = $args[0]
$TextBlock2 = $args[1]
$TextBlock3 = $args[2]
$Stamp = Get-Date -Format o
Write-Verbose "[$Stamp] [$Section - $TextBlock1]" -Verbose
}
Function CheckVHDXFile($VHDXFile){
	# Check if VHDX exists
	Logit "Check if $VHDXFile exists"
	$FileExist = Test-Path $VHDXFile

	If ($FileExist -like 'True') {
		Logit "VHDXfile already exists , exit"
		Return $True
	} else {
		Logit "VHDXFile Not yet created"
		Return $False
	}
}
Function CheckWIMFile($SourceFile){
	# Check if WIMFile exists
	Logit "Check if $SourceFile exists"
	If($SourceFile -like "") {
		Logit "No WIM file specified, will create blank disk and set to PXE"
		$SourceFile = 'NoFile'
		Return $true
	} else {
		Logit "Testing $SourceFile"
		If(Test-Path $SourceFile) {
			Logit "$SourceFile found"
			Return $True
		
		} else {
			Logit "Could not find the WIM file, return false"
			Return $False
		}
	}
}
Function CheckVM($VMName) {
	# Check if VM exists
	Logit "Check if $VMName exists"
	$VMexist = Get-VM -Name $VMName -ErrorAction SilentlyContinue
	Logit "$($VMexist.Name)"
	If($VMexist.Name -like $VMName) {
		Logit "VM with name $VMName already exists"
		Return $True
	
	} else {
		Logit "Not yet created"
		Return $False
	}

}
Function DiskPartTextFile($VHDXDiskNumber){
    if ( Test-Path "diskpart.txt" ) {
      del .\diskpart.txt -Force
    }
    Logit "Creating diskpart.txt for disk " $VHDXDiskNumber
    $DiskPartTextFile = New-Item "diskpart.txt" -type File
    set-Content $DiskPartTextFile "select disk $VHDXDiskNumber"
    Add-Content $DiskPartTextFile "Select Partition 2"
    Add-Content $DiskPartTextFile "Set ID=c12a7328-f81f-11d2-ba4b-00a0c93ec93b OVERRIDE"
    Add-Content $DiskPartTextFile "GPT Attributes=0x8000000000000000"
    $DiskPartTextFile 
}
Function CreateUnattendFile($VMName,$JoinWorkgroup,$ProductKey,$OrgName,$Fullname,$TimeZoneName,$InputLocale,$SystemLocale,$UILanguage,$UserLocale,$OSDAdapter0DNS1,$OSDAdapter0DNS2,$DNSDomain,$OSDAdapter0IPAddressList,$OSDAdapter0Gateways,$OSDAdapter0SubnetMaskPrefix,$AdminPassword,$ADDomainName,$ADDomainMode,$ADForestMode,$ADSafeModeAdministratorPassword,$ADDatabasePath,$ADSysvolPath,$ADLogPath){
Logit "Start"
Logit "IP is $OSDAdapter0IPAddressList"
    if ( Test-Path "Unattend.xml" ) {
      del .\Unattend.xml
    }
    $unattendFile = New-Item "Unattend.xml" -type File
    set-Content $unattendFile '<?xml version="1.0" encoding="utf-8"?>'
    add-Content $unattendFile '<unattend xmlns="urn:schemas-microsoft-com:unattend">'
    add-Content $unattendFile '    <settings pass="specialize">'

Switch ($DomainOrWorkGroup){
DOMAIN{
Logit "Configure unattend.xml for domain mode mode"
    add-Content $unattendFile '        <component name="Microsoft-Windows-UnattendedJoin" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">'
    add-Content $unattendFile '            <Identification>'
    add-Content $unattendFile '                <Credentials>'
    add-Content $unattendFile "                    <Username>$DomainAdmin</Username>"
    add-Content $unattendFile "                    <Domain>$DomainAdminDomain</Domain>"
    add-Content $unattendFile "                    <Password>$DomainAdminPassword</Password>"
    add-Content $unattendFile '                </Credentials>'
    add-Content $unattendFile "                <JoinDomain>$DNSDomain</JoinDomain>"
    add-Content $unattendFile "                <MachineObjectOU>$MachienObjectOU</MachineObjectOU>"
    add-Content $unattendFile '            </Identification>'
    add-Content $unattendFile '        </component>'
}
WORKGROUP{
Logit "Configure unattend.xml for workgroup mode"
    add-Content $unattendFile '        <component name="Microsoft-Windows-UnattendedJoin" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">'
    add-Content $unattendFile '            <Identification>'
    add-Content $unattendFile "                <JoinWorkgroup>$JoinWorkgroup</JoinWorkgroup>"
    add-Content $unattendFile '            </Identification>'
    add-Content $unattendFile '        </component>'
}
default{
Logit "Epic fail, exit"
Exit
}
}
    add-Content $unattendFile '        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">'
    add-Content $unattendFile "            <ComputerName>$VMName</ComputerName>"
if ($ProductKey -eq "")
{
Logit "No Productkey"
}else{
Logit "Adding Productkey $ProductKey"
    add-Content $unattendFile "            <ProductKey>$ProductKey</ProductKey>"
}
    add-Content $unattendFile "            <RegisteredOrganization>$OrgName</RegisteredOrganization>"
    add-Content $unattendFile "            <RegisteredOwner>$Fullname</RegisteredOwner>"
    add-Content $unattendFile '            <DoNotCleanTaskBar>true</DoNotCleanTaskBar>'
    add-Content $unattendFile "            <TimeZone>$TimeZoneName</TimeZone>"
    add-Content $unattendFile '        </component>'
    add-Content $unattendFile '        <component name="Microsoft-Windows-IE-InternetExplorer" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'
    add-Content $unattendFile '            <DisableFirstRunWizard>true</DisableFirstRunWizard>'
    add-Content $unattendFile '            <DisableOOBAccelerators>true</DisableOOBAccelerators>'
    add-Content $unattendFile '            <DisableDevTools>true</DisableDevTools>'
    add-Content $unattendFile '            <Home_Page>about:blank</Home_Page>'
    add-Content $unattendFile '        </component>'
    add-Content $unattendFile '        <component name="Microsoft-Windows-International-Core" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'
    add-Content $unattendFile "            <InputLocale>$InputLocale</InputLocale>"
    add-Content $unattendFile "            <SystemLocale>$SystemLocale</SystemLocale>"
    add-Content $unattendFile "            <UILanguage>$UILanguage</UILanguage>"
    add-Content $unattendFile "            <UserLocale>$UserLocale</UserLocale>"
    add-Content $unattendFile '        </component>'
    add-Content $unattendFile '        <component name="Microsoft-Windows-IE-ESC" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'
    add-Content $unattendFile '            <IEHardenAdmin>false</IEHardenAdmin>'
    add-Content $unattendFile '            <IEHardenUser>false</IEHardenUser>'
    add-Content $unattendFile '        </component>'
if ($OSDAdapter0IPAddressList -contains "DHCP")
{
Logit "IP is $OSDAdapter0IPAddressList so we prep for DHCP"
}else{
Logit "IP is $OSDAdapter0IPAddressList so we prep for Static IP"
    add-Content $unattendFile '        <component name="Microsoft-Windows-DNS-Client" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'
    add-Content $unattendFile '            <Interfaces>'
    add-Content $unattendFile '                <Interface wcm:action="add">'
    add-Content $unattendFile '                    <DNSServerSearchOrder>'
    add-Content $unattendFile "                        <IpAddress wcm:action=`"add`" wcm:keyValue=`"1`">$OSDAdapter0DNS1</IpAddress>"
    add-Content $unattendFile "                        <IpAddress wcm:action=`"add`" wcm:keyValue=`"2`">$OSDAdapter0DNS2</IpAddress>"
    add-Content $unattendFile '                    </DNSServerSearchOrder>'
    add-Content $unattendFile '                    <Identifier>Ethernet</Identifier>'
    add-Content $unattendFile '                </Interface>'
    add-Content $unattendFile '            </Interfaces>'
    add-Content $unattendFile '        </component>'
    add-Content $unattendFile '        <component name="Microsoft-Windows-TCPIP" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'
    add-Content $unattendFile '            <Interfaces>'
    add-Content $unattendFile '                <Interface wcm:action="add">'
    add-Content $unattendFile '                    <Ipv4Settings>'
    add-Content $unattendFile '                        <DhcpEnabled>false</DhcpEnabled>'
    add-Content $unattendFile '                    </Ipv4Settings>'
    add-Content $unattendFile '                    <Identifier>Ethernet</Identifier>'
    add-Content $unattendFile '                    <UnicastIpAddresses>'
    add-Content $unattendFile "                       <IpAddress wcm:action=`"add`" wcm:keyValue=`"1`">$OSDAdapter0IPAddressList/$OSDAdapter0SubnetMaskPrefix</IpAddress>"
    add-Content $unattendFile '                    </UnicastIpAddresses>'
    add-Content $unattendFile '                    <Routes>'
    add-Content $unattendFile '                        <Route wcm:action="add">'
    add-Content $unattendFile '                            <Identifier>0</Identifier>'
    add-Content $unattendFile "                            <NextHopAddress>$OSDAdapter0Gateways</NextHopAddress>"
    add-Content $unattendFile "                            <Prefix>0.0.0.0/0</Prefix>"
    add-Content $unattendFile '                        </Route>'
    add-Content $unattendFile '                    </Routes>'
    add-Content $unattendFile '                </Interface>'
    add-Content $unattendFile '            </Interfaces>'
    add-Content $unattendFile '        </component>'
    
}
    ################RunSynchronous in Specialise pass, will run as system##################
    add-Content $unattendFile '<component name="Microsoft-Windows-Deployment" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'
    add-Content $unattendFile '<RunSynchronous>'
    add-Content $unattendFile '<RunSynchronousCommand wcm:action="add">'
    add-Content $unattendFile '  <Description>Enable-PSRemoting with -SkipNetworkProfileCheck for remoting in workgroup</Description>'
    add-Content $unattendFile '  <Order>1</Order>'
    add-Content $unattendFile '  <Path>Powershell -NoLogo -Command &quot;Enable-PSRemoting -SkipNetworkProfileCheck -Force&quot;</Path>'
    add-Content $unattendFile '  <WillReboot>Never</WillReboot>'
    add-Content $unattendFile '</RunSynchronousCommand>'
    add-Content $unattendFile '</RunSynchronous>'
    add-Content $unattendFile '        </component>'
    ################RunSynchronous in Specialise pass, will run as system##################

    add-Content $unattendFile '    </settings>'
    add-Content $unattendFile '    <settings pass="oobeSystem">'
    add-Content $unattendFile '        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">'
    add-Content $unattendFile '            <UserAccounts>'
    add-Content $unattendFile '                <AdministratorPassword>'
    add-Content $unattendFile "                    <Value>$AdminPassword</Value>"
    add-Content $unattendFile '                    <PlainText>True</PlainText>'
    add-Content $unattendFile '                </AdministratorPassword>'
    add-Content $unattendFile '            </UserAccounts>'
    add-Content $unattendFile '            <OOBE>'
    add-Content $unattendFile '                <HideEULAPage>true</HideEULAPage>'
    add-Content $unattendFile '                <NetworkLocation>Work</NetworkLocation>'
    add-Content $unattendFile '                <ProtectYourPC>1</ProtectYourPC>'
    add-Content $unattendFile '            </OOBE>'
    add-Content $unattendFile "            <RegisteredOrganization>$Orgname</RegisteredOrganization>"
    add-Content $unattendFile "            <RegisteredOwner>$FullName</RegisteredOwner>"
    add-Content $unattendFile "            <TimeZone>$TimeZoneName</TimeZone>"
    add-Content $unattendFile '        </component>'
    add-Content $unattendFile '        <component name="Microsoft-Windows-International-Core" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'
    add-Content $unattendFile "            <InputLocale>$InputLocale</InputLocale>"
    add-Content $unattendFile "            <SystemLocale>$SystemLocale</SystemLocale>"
    add-Content $unattendFile "            <UILanguage>$UILanguage</UILanguage>"
    add-Content $unattendFile "            <UserLocale>$UserLocale</UserLocale>"
    add-Content $unattendFile '        </component>'
    add-Content $unattendFile '    </settings>'
    add-Content $unattendFile '</unattend>'
    $unattendFile | Out-Null
Logit "Done"
}
Function CreateVHDXBlank($VHDXFile,$SizeinGB,$VMName,$VMLocation){
# Create, Mount VHDx and get driveletter
$Size = $SizeinGB *1024*1024*1024
Logit "Creating $VHDXFile"
Logit "Size is $SizeinGB GB"

New-VHD -Path $VHDXFile -Dynamic -SizeBytes $size
Mount-DiskImage -ImagePath $VHDXFile
$VHDXDisk = Get-DiskImage -ImagePath $VHDXFile | Get-Disk
$VHDXDiskNumber = [string]$VHDXDisk.Number
Logit "Disknumber is now $VHDXDiskNumber"

# Format VHDx
Initialize-Disk -Number $VHDXDiskNumber -PartitionStyle MBR
Logit "Initialize disk as MBR"
$VHDXDrive = New-Partition -DiskNumber $VHDXDiskNumber -UseMaximumSize -AssignDriveLetter -IsActive | Format-Volume -Confirm:$false
$VHDXVolume = [string]$VHDXDrive.DriveLetter+":"
Logit "Driveletter is now = $VHDXVolume"
}
Function CreateVHDXDiff($VHDXFile,$SizeinGB,$VMName,$VMLocation){
# Create, Mount VHDx and get driveletter
Logit "Creating $VHDXFile"

New-VHD -Path $VHDXFile -ParentPath 'C:\Setup\Ref\RWS2012R2.vhdx'
Mount-DiskImage -ImagePath $VHDXFile
$VHDXDisk = Get-DiskImage -ImagePath $VHDXFile | Get-Disk
$VHDXDiskNumber = [string]$VHDXDisk.Number
Logit "Disknumber is now $VHDXDiskNumber"

# Format VHDx
$VHDXDrive = Get-Partition -DiskNumber $VHDXDiskNumber | Where-Object -Property Type -like 'Basic'
$VHDXVolume = [string]$VHDXDrive.DriveLetter+":"
Logit "Driveletter is now = $VHDXVolume"
}
Function CreateVHDXForBios($SourceFile,$VHDXFile,$SizeinGB,$VMName,$VMLocation){
# Create, Mount VHDx and get driveletter
$Size = $SizeinGB*1024*1024*1024
logit "Creating $VHDXFile"
logit "Size is $SizeinGB GB"
logit "WIMfile is $SourceFile"

New-VHD -Path $VHDXFile -Dynamic -SizeBytes $size
Mount-DiskImage -ImagePath $VHDXFile
$VHDXDisk = Get-DiskImage -ImagePath $VHDXFile | Get-Disk
$VHDXDiskNumber = [string]$VHDXDisk.Number
Logit "Disknumber is now $VHDXDiskNumber"

# Format VHDx
Initialize-Disk -Number $VHDXDiskNumber -PartitionStyle MBR
Logit "Initialize disk as MBR"
$VHDXDrive = New-Partition -DiskNumber $VHDXDiskNumber -UseMaximumSize -AssignDriveLetter -IsActive | Format-Volume -Confirm:$false
$VHDXVolume = [string]$VHDXDrive.DriveLetter+":"
Logit "Driveletter is now = $VHDXVolume"

#Apply Image
Logit "Applying $SourceFile to $VHDXVolume\"
sleep 5
Logit "This will take a while..."
Try{Expand-WindowsImage -ImagePath "$SourceFile" -Index 1 -ApplyPath $VHDXVolume\ -Verbose -ErrorAction Stop
}Catch{$ErrorMessage = $_.Exception.Message
Logit "Fail: $ErrorMessage"
Break
}

#Copy unattend.xml
Copy .\Unattend.xml $VHDXVolume

#Old Style for 8.0
#& $env:SystemRoot\System32\dism.exe /apply-Image /ImageFile:$ISODrive\Sources\install.wim /index:$Index /ApplyDir:$VHDVolume\

Logit "About to fix BCD using BCDBoot.exe from $VHDXVolume\Windows"
cmd /c "$VHDXVolume\Windows\system32\bcdboot $VHDXVolume\Windows /f ALL /s $VHDXVolume"
}
Function CreateVHDXForUEFI($SourceFile,$VHDXFile,$SizeinGB,$VMName,$VMLocation){
# Create, Mount VHDx and get driveletter
$Size = $SizeinGB*1024*1024*1024
logit "Creating $VHDXFile"
logit "Size is $SizeinGB GB"
logit "WIMfile is $SourceFile"

New-VHD -Path $VHDXFile -Dynamic -SizeBytes $size
Mount-DiskImage -ImagePath $VHDXFile
$VHDXDisk = Get-DiskImage -ImagePath $VHDXFile | Get-Disk
$VHDXDiskNumber = [string]$VHDXDisk.Number
Logit "Disknumber is now $VHDXDiskNumber"

# Format VHDx
Initialize-Disk -Number $VHDXDiskNumber –PartitionStyle GPT -Verbose
$VHDXDrive1 = New-Partition -DiskNumber $VHDXDiskNumber -GptType '{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}' -Size 499MB -Verbose 
$VHDXDrive1 | Format-Volume -FileSystem FAT32 -NewFileSystemLabel System -Confirm:$false -Verbose
$VHDXDrive2 = New-Partition -DiskNumber $VHDXDiskNumber -GptType '{e3c9e316-0b5c-4db8-817d-f92df00215ae}' -Size 128MB
$VHDXDrive3 = New-Partition -DiskNumber $VHDXDiskNumber -GptType '{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}' -UseMaximumSize -Verbose
$VHDXDrive3 | Format-Volume -FileSystem NTFS -NewFileSystemLabel OSDisk -Confirm:$false -Verbose
Add-PartitionAccessPath -DiskNumber $VHDXDiskNumber -PartitionNumber $VHDXDrive1.PartitionNumber -AssignDriveLetter
$VHDXDrive1 = Get-Partition -DiskNumber $VHDXDiskNumber -PartitionNumber $VHDXDrive1.PartitionNumber
Add-PartitionAccessPath -DiskNumber $VHDXDiskNumber -PartitionNumber $VHDXDrive3.PartitionNumber -AssignDriveLetter
$VHDXDrive3 = Get-Partition -DiskNumber $VHDXDiskNumber -PartitionNumber $VHDXDrive3.PartitionNumber
$VHDXVolume1 = [string]$VHDXDrive1.DriveLetter+":"
$VHDXVolume3 = [string]$VHDXDrive3.DriveLetter+":"
Logit "Driveletter for the FAT32 volume is now = $VHDXVolume1"
Logit "Driveletter for the NTFS volume is now = $VHDXVolume3"

#Apply Image
Logit "Applying $SourceFile to $VHDXVolume3\"
sleep 5
Logit "This will take a while..."
Try{Expand-WindowsImage -ImagePath "$SourceFile" -Index 1 -ApplyPath $VHDXVolume3\ -Verbose -ErrorAction Stop -LogPath "C:\Setup\Scripts\applyimage.log"
}Catch{$ErrorMessage = $_.Exception.Message
Logit "Fail: $ErrorMessage"
Break
}

#Apply BootFiles
Logit "About to fix BCD using BCDBoot.exe from $VHDXVolume3\Windows"
cmd /c "$VHDXVolume3\Windows\system32\bcdboot $VHDXVolume3\Windows /s $VHDXVolume1 /f UEFI"

#Apply unattend.xml
Logit "About to apply Unattend.xml"
copy .\Unattend.xml "$VHDXVolume3\Windows\system32\Sysprep"
#Use-WindowsUnattend -Path $VHDXVolume3\ -UnattendPath .\Unattend.xml -SystemDrive $VHDXVolume1 -Verbose

#Set ID for GPT
DiskPartTextFile $VHDXDiskNumber
& diskpart.exe /s .\diskpart.txt | Out-Null
}
Function Cleanup($VHDXFile){
	$Section = "CleanUp"
	Logit "Dismount $VHDXFile"
	Dismount-DiskImage -ImagePath $VHDXFile
}
Function CreateVMForBios($VMName,$VMLocation,$VHDXFile){
	Logit "Creating $VMName"
	$VM = New-VM –Name $VMname –MemoryStartupBytes ([int64]$VMMemory*1024*1024) -Generation 1 –VHDPath $VHDXFile -SwitchName $VMSwitchName -Path $VMLocation
	Add-VMDvdDrive -VM $VM
	Set-VMProcessor -CompatibilityForMigrationEnabled $True -VM $VM
}
Function CreateVMForUEFI($VMName,$VMLocation,$VHDXFile){
	Logit "Creating $VMName"
	$VM = New-VM –Name $VMname –MemoryStartupBytes ([int64]$VMMemory*1024*1024)  -Generation 2 –VHDPath $VHDXFile -SwitchName $VMSwitchName -Path $VMLocation
	Add-VMDvdDrive -VM $VM
	Set-VMProcessor -CompatibilityForMigrationEnabled $True -VM $VM
}
Function MountISO($VMName,$ISO){
	Logit "Mounting $ISO on $VMName"
}
Function EnablePXEBoot($VMName){
	Logit "Enable PXE on $VMName"
}
Function SetVLANID($VMName,$VLANID){
	Get-VM -Name $VMName | Get-VMNetworkAdapter | Set-VMNetworkAdapterVlan -Access -VlanId $VLANID
}

# Main
$Section = "Main"
$SizeinGB = 60
# Get settingsfile from github
if (Test-Path "$env:SystemRoot\Temp\$SrvSettingsXMLFile") {Remove-Item "$env:SystemRoot\Temp\$SrvSettingsXMLFile"}

$WebRequest = $false
$i = 1
do {
	if ($i -ge 10) {Write-Error "Failed to download XMLFile from GitHub after $i retries"; Throw "Failed to download XMLFile from GitHub after $i retries"}

    Logit "Attempt $i to download XML settingsfile from https://raw.github.com/Hipster74/NewLabVM/master/NewLabVM/NewLabVM/$SrvSettingsXMLFile"
	$WebRequest = Invoke-WebRequest -Uri "https://raw.github.com/Hipster74/NewLabVM/master/NewLabVM/NewLabVM/$SrvSettingsXMLFile" -UseBasicParsing -OutFile "$env:SystemRoot\Temp\$SrvSettingsXMLFile" -PassThru
	if (($WebRequest).statuscode -eq '200' -and (Test-Path "$env:SystemRoot\Temp\$SrvSettingsXMLFile")){
	    Logit "Successfully downloaded XMLFile from GitHub"
        $WebRequest = $true
    } 
    sleep 3
	$i++
} until($WebRequest)

sleep -Seconds 2
[xml]$SrvSettings = Get-Content "$env:SystemRoot\Temp\$SrvSettingsXMLFile"
$JoinWorkgroup = $DomainOrWorkGroupName
$OSDAdapter0IPAddressList = $IPAddress
#Set values for VM creation
$VHDXFile = "$VMLocation\$VMName\Virtual Hard Disks\$VMName-OSDisk.vhdx"

# Setting MachineDefaults
$AdminPassword = $SrvSettings.Telecomputing.MachineDefaults.AdminPassword
$OrgName = $SrvSettings.Telecomputing.MachineDefaults.OrgName
$Fullname = $SrvSettings.Telecomputing.MachineDefaults.FullName
$TimeZoneName = $SrvSettings.Telecomputing.MachineDefaults.TimeZoneName
$InputLocale = $SrvSettings.Telecomputing.MachineDefaults.InputLocale
$SystemLocale = $SrvSettings.Telecomputing.MachineDefaults.SystemLocale
$UILanguage = $SrvSettings.Telecomputing.MachineDefaults.UILanguage
$UserLocale = $SrvSettings.Telecomputing.MachineDefaults.UserLocale
$OSDAdapter0Gateways = $SrvSettings.Telecomputing.MachineDefaults.OSDAdapter0Gateways
$OSDAdapter0DNS1 = $SrvSettings.Telecomputing.MachineDefaults.OSDAdapter0DNSServerList[0]
$OSDAdapter0DNS2 = $SrvSettings.Telecomputing.MachineDefaults.OSDAdapter0DNSServerList[1]
$OSDAdapter0SubnetMaskPrefix = $SrvSettings.Telecomputing.MachineDefaults.OSDAdapter0SubnetMaskPrefix
$ProductKey = $SrvSettings.Telecomputing.MachineDefaults.ProductKey
$VMSwitchName = $SrvSettings.Telecomputing.MachineDefaults.VMSwitchName

#Setting DomainDefaults
$DNSDomain = $SrvSettings.Telecomputing.DomainDefaults.DNSDomain
$DomainNetBios = $SrvSettings.Telecomputing.DomainDefaults.DomainNetBios
$DomainAdmin = $SrvSettings.Telecomputing.DomainDefaults.DomainAdmin
$DomainAdminPassword = $SrvSettings.Telecomputing.DomainDefaults.DomainAdminPassword
$DomainAdminDomain = $SrvSettings.Telecomputing.DomainDefaults.DomainAdminDomain
$MachienObjectOU = $SrvSettings.Telecomputing.DomainDefaults.MachienObjectOU

#Settings WorkgroupDefaults
$JoinWorkgroup = $SrvSettings.Telecomputing.WorkgroupDefaults.WorkgroupName

Logit "Starting"
Logit "WIM File is $SourceFile"
Logit "VHDX file is $VHDXFile"
Logit "Extrafolder to include is $ExtraFolder"
Logit "VHDX File size is set to $SizeinGB GB"
Logit "VMType set to $VMType"
Logit "IP set to $OSDAdapter0IPAddressList"

# Check to see if the Virtual Machine already exists
$Section = "CheckVM"
if ((CheckVM $VMName)) {
	if ($Force) {
		Logit "VM $VMName found and Forceparameter set, shutdown and delete VM"
		Logit "Getting path to $VMName harddrives"
		$VM = Get-VM -Name $VMName
		$VMFolder = $VM.ConfigurationLocation
		Logit "Path to $VMName is $VMFolder"
	
		Logit "Shutting down VM $VMName"
		Get-VM -Name $VMName | Stop-VM -Force
		Logit "Removing VM $VMName"
		Get-VM $VMName | Remove-VM -Force
	
		Logit "Renaming VMFolder to $VMName" + "Bak as backup"
		Sleep -Seconds 5
		Rename-Item -Path $VMFolder -NewName "BCK-$($VM.name)-$(Get-Date -Format yyyy-MM-dd-mm)" -Force

	} else {
		Logit "VM $VMName found and Forceparameter NOT set, aborting to avoid dataloss"
		Write-Output "VM $VMName already exists, specify Force parameter to delete and create new VM, exiting"
		Throw "VM $VMName already exists, specify Force parameter to delete and create new VM, exiting"
	}

} else {
	Logit "VM $VMName not found, proceeding"

}

# Check to see if the VHDXfile already exist
$Section = "CheckVHDXFile"
CheckVHDXFile $VHDXFile

# Check to see if the OS WIMFile already exist
$Section = "CheckWIMFile"
$CheckWIMFileResult = CheckWIMFile $SourceFile
if (!($CheckWIMFileResult)) {
	Logit "Failed to verify that WIMFile exists!"
	Break
}
Logit "The WIMfile is set to $SourceFile"

# Create unattend.xml
If ($DifforCreate -like 'Diff'){
} else {
	If ($SourceFile -like 'NoFile'){
		Logit "No need for any unattend.xml"
	} else {
		$Section = "Create Unattend XML"
		Logit "CreateUnattendFile $VMName $JoinWorkgroup $ProductKey $OrgName $Fullname $TimeZoneName $InputLocale $SystemLocale $UILanguage $UserLocale $OSDAdapter0DNS1 $OSDAdapter0DNS2 $DNSDomain $OSDAdapter0IPAddressList $OSDAdapter0Gateways $OSDAdapter0SubnetMaskPrefix $AdminPassword $ADDomainName $ADDomainMode $ADForestMode $ADSafeModeAdministratorPassword $ADDatabasePath $ADSysvolPath $ADLogPath"
		CreateUnattendFile $VMName $JoinWorkgroup $ProductKey $OrgName $Fullname $TimeZoneName $InputLocale $SystemLocale $UILanguage $UserLocale $OSDAdapter0DNS1 $OSDAdapter0DNS2 $DNSDomain $OSDAdapter0IPAddressList $OSDAdapter0Gateways $OSDAdapter0SubnetMaskPrefix $AdminPassword $ADDomainName $ADDomainMode $ADForestMode $ADSafeModeAdministratorPassword $ADDatabasePath $ADSysvolPath $ADLogPath
	}
}

#Create VHDx file
If ($DifforCreate -like 'Diff') {
	CreateVHDXDiff $VHDXFile $VMName $VMLocation
} else {
	If ($SourceFile -like 'NoFile') {
		CreateVHDXBlank $VHDXFile $SizeinGB $VMName $VMLocation
	} else {
		Switch ($VMType){
			BIOS {
				$Section = "CreateVHDX"
				CreateVHDXForBIOS $SourceFile $VHDXFile $SizeinGB
			}
			UEFI {
				$Section = "CreateVHDX"
				CreateVHDXForUEFI $SourceFile $VHDXFile $SizeinGB
			}
			default {
				Logit "You must either specify either BIOS or UEFI, exit"
				Exit
			}
		}
	}
}

# Clean up
Logit "Cleanup"
Cleanup $VHDXFile

#Create VM
Switch ($VMType) {
	BIOS {
		$Section = "CreateVMForBios"
		CreateVMForBIOS $VMName $VMLocation $VHDXFile

	}
	UEFI {
		$Section = "CreateVMForUEFI"
		CreateVMForUEFI $VMName $VMLocation $VHDXFile

	}
		default {
		Logit "Epic Fail, exit"
		Exit
	}
}

#Add Datadisk if $AddDataDisks = True
if($AddDataDisk -ne "NoDisk") {
	Logit "adding Datadisk"
	$VM = Get-VM -Name $VMName
	$VMDiskSize = $AddDataDisk
	$VMDiskName = "DataDisk01.vhdx"
	$VMLocation = $VM.Path
	$VMDiskLocation = $VM.HardDrives.path | Split-Path

	# Create VHDx
	Logit "Creating $VMDiskLocation\$VMName-$VMDiskName"
	$VMDisk02 = New-VHD –Path $VMDiskLocation\$VMName-$VMDiskName -SizeBytes $VMDiskSize

	#Attach Disk
	Add-VMHardDiskDrive -VM $VM -Path $VMDisk02.Path -ControllerType SCSI
} 

#Set VLAN
If ($VLANID -notlike ""){SetVLANID $VMName $VLANID}

#Wait for VM to get ready
$Section = 'VM minisetup'
if (Get-VM -Name $VMName){
	#Start VM
	Logit "Starting VM $VMName"
	Start-VM $VMName

	$i = 1
	while((Get-VM -Name $VMName).HeartBeat -ne  'OkApplicationsHealthy') {
		if ($i -ge 30) {Write-Error "Timeout when waiting for VM $VMName to start"; Throw "Timeout when waiting for VM $VMName to start"}
		Logit "Waiting for $VMName to start"
		Start-Sleep -Seconds 10
		$i++
	}
	# Updating Hostsfile to enable name resolution when remoting from Hyper-v host to Hyper-v guest
	# Remove any old entries for this VM in Hostsfile
	$i = 1
	while ((Get-VMNetworkAdapter $VMName | select -ExpandProperty ipaddresses) -eq $null) { 
		if ($i -ge 60) {Write-Error "Timeout when waiting for $VMName ipaddress"; Throw "Timeout when waiting for $VMName ipaddress"}
		Logit "Waiting for $VMName ipaddress before editing Hostsfile"
		Start-Sleep -Seconds 10
		$i++
	}
	
	Logit "Updating Hostfile with ip and hostname for VM $VMName"
	$ReplaceStr = ""
	$HostsFile = "$env:SystemRoot\System32\drivers\etc\hosts"
	$HostsMatches = Get-Content $HostsFile | Select-String $VMName
	ForEach ( $item in $HostsMatches) {
		(Get-Content $HostsFile) -replace $item, $ReplaceStr | Set-Content $HostsFile -Encoding Ascii
	}
	# Set new entry in Hostsfile
	Add-Content $HostsFile "`n$((get-vm $VMName).networkadapters.ipaddresses[0])            $VMName            # Hyper-v Guestserver"
	$i = 1
	do {
		if ($i -ge 30) {Write-Error "Timeout when trying to contact WINRM on $VMName"; Throw "Timeout when trying to contact WINRM on $VMName"}
		Logit "Waiting for VM $VMName to become accessible from VMHost"
		sleep 10
		$i++ 
	} until(Test-NetConnection $VMName -CommonTCPPort WINRM | Where-Object {$_.TcpTestSucceeded} )

} else {Logit "Unable to start VM $VMName because it does not exist?"}
#Notify
Logit "Done"

#Connect using VMConnect
# & vmconnect.exe localhost $VMname