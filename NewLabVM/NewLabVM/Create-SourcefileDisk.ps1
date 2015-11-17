Workflow Create-SourcefileDisk {
	param(
		[Parameter(Mandatory=$True)]
		[string] $VMName,
		[parameter(mandatory=$True)]
		[string]$SourcefilesDir,
		[parameter(mandatory=$True)]
		[int]$DiskSizeInGB
	)
	function CreateVHD ($VHDPath, $Size) {
		$drive = (New-VHD -path $VHDPath -SizeBytes $Size -Dynamic .\1033| `
        Mount-VHD -Passthru | `
        Get-Disk -number {$_.DiskNumber} | `
        Initialize-Disk -PartitionStyle MBR -PassThru | `
        New-Partition -UseMaximumSize -AssignDriveLetter:$False -MbrType IFS | `
        Format-Volume -Confirm:$false -FileSystem NTFS -force | `
        Get-Partition | `
        Add-PartitionAccessPath -AssignDriveLetter -PassThru | `
        get-volume).DriveLetter

		Dismount-VHD $VHDPath
	}
	function MountVHD ($VHDPath) {
		Mount-VHD $VHDPath
		$drive = (Get-DiskImage -ImagePath $VHDPath | `
        Get-Disk | `
        Get-Partition).DriveLetter
		"$($drive):\"
		Get-PSDrive | Out-Null # Work around. some times the drive is not mounted
	}
  
	function DismountVHD ($VHDPath) {
		Dismount-VHD $VHDPath
	}
	
	# Main
	$VM = Get-VM -Name $VMName
	$VMLocation = $VM.Path
	$VMDiskLocation = $VM.HardDrives.path | Split-Path
	# Create a VHDX file c:\temp\x.vhdx
	CreateVHD -VHDPath "$VMDiskLocation\$VMName-DataDisk.vhdx" -Size $DiskSizeInGB`GB
 
	# Mount the VHD, copy c:\data to it and finally dismount it.
	$VHDXPath = MountVHD -VHDPath "$VMDiskLocation\$VMName-DataDisk.vhdx"
 
	Copy $SourcefilesDir $VHDXPath -Recurse
 
	DismountVHD -VHDPath "$VMDiskLocation\$VMName-DataDisk.vhdx"

	#Attach Disk
	Add-VMHardDiskDrive -VM $VM -Path "$VMDiskLocation\$VMName-DataDisk.vhdx" -ControllerType SCSI

}