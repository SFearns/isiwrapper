Import-Module SSH-Sessions
#Import-Module Import-Delimited
. 'C:\WorkFolder\3rd Party Scripts\Import-Delimited.ps1'
$SFTempFile = "$env:temp\sftempfile.csv"
if (Test-Path ($SFTempFile)){Remove-Item $SFTempFile}

# Things to include:
#   Get the current status of system varilables, eg. Maximum number of snapshots, etc
#
#   isi status -n
#   isi_hw_status
#

Write-Host "`n`tIsilon Module v1.0"
Write-Host ""
Write-Host "Make a connection to an Isilon Cluster with: " -NoNewline
Write-Host "Connect-IsilonCluster" -ForegroundColor Yellow
Write-Host "Disconnect from an Isilon Cluster with: " -NoNewline
Write-Host "Connect-IsilonCluster" -ForegroundColor Yellow
Write-Host "List all available commands with: " -NoNewline
Write-Host "Get-IsilonCommands" -ForegroundColor Yellow

function Get-IsilonCommands {
    [CmdletBinding()]
    Param ()
    Get-Command *-Isilon* -CommandType Function | Sort-Object Name
}

function Connect-IsilonCluster {
    [CmdletBinding()]
    [OutputType([String])]
    Param([Parameter(Mandatory=$true)] [string]$ClusterName,
          [Parameter(Mandatory=$true)] [string]$Username,
          [Parameter(Mandatory=$true)] [string]$Password)
    $Result = ([string](New-SshSession -ComputerName $ClusterName -Username $UserName -Password $Password).split("`r")).Split("`n")
    Return $Result
}

Function Get-UnixDate {
    Param([Parameter(Mandatory=$true)] [string]$UnixDate)
    [timezone]::CurrentTimeZone.ToLocalTime(([datetime]'1/1/1970').AddSeconds($UnixDate))
}

function Get-IsilonBatteryStatus {
# This function assumes 2 batteries per node
    [CmdletBinding()]
    [OutputType([String])]
    Param([Parameter(Mandatory=$true)] [string]$ClusterName)
    $Temp = (([string](Invoke-SshCommand -ComputerName $ClusterName -Quiet -Command "isi_for_array -s isi batterystatus").split("`r")).Split("`n")).Replace(' ','')
    $Result=@()
    for ($i=0;$i-lt$Temp.count;$i++){
        $Temp2=$Temp[$i].Split(':')
        $Temp2[1] = $Temp2[1].replace('battery','')
        $Element=New-Object -TypeName PSObject
        Add-Member -InputObject $Element -MemberType NoteProperty -Name NodeName -Value ($Temp2[0])
        Add-Member -InputObject $Element -MemberType NoteProperty -Name Battery -Value ($Temp2[1])
        Add-Member -InputObject $Element -MemberType NoteProperty -Name Status -Value ($Temp2[2])
        $Result+=$Element
    }
    Return $Result
}

function Get-IsilonHardwareStatus {
# This function is a WIP
    [CmdletBinding()]
    [OutputType([String])]
    Param([Parameter(Mandatory=$true)] [string]$ClusterName)
    $Temp = (([string](Invoke-SshCommand -ComputerName $ClusterName -Quiet -Command "isi_for_array -s isi_hw_status").split("`r")).Split("`n")).Replace(' ','')
    $Result = $Temp
    # Magic goes here to extra all the information and create objects
<#
    $Result=@()
    for ($i=0;$i-lt$Temp.count;$i++){
        $Temp2=$Temp[$i].Split(':')
        $Temp2[1] = $Temp2[1].replace('battery','')
        $Element=New-Object -TypeName PSObject
        Add-Member -InputObject $Element -MemberType NoteProperty -Name NodeName -Value ($Temp2[0])
        Add-Member -InputObject $Element -MemberType NoteProperty -Name Battery -Value ($Temp2[1])
        Add-Member -InputObject $Element -MemberType NoteProperty -Name Status -Value ($Temp2[2])
        $Result+=$Element
    }
#>
    Return $Result
}

function Get-IsilonDiskUsage {
    [CmdletBinding()]
    [OutputType([String])]
    Param([Parameter(Mandatory=$true)] [string]$ClusterName)
    ([string](Invoke-SshCommand -ComputerName $ClusterName -Quiet -Command "df -i").split("`r")).Split("`n").replace('Mounted on','MountedOn') | Convert-Delimiter " +" "," | Set-Content $SFTempFile
    $Result = Import-Csv $SFTempFile
    Remove-Item -Path $SFTempFile
    Return $Result
}

function Get-IsilonDirectoryQuota {
    [CmdletBinding()]
    [OutputType([String])]
    Param([Parameter(Mandatory=$true)] [string]$ClusterName,
          [Parameter(Mandatory=$true)] [string]$Path)
    $Result = ([string](Invoke-SshCommand -ComputerName $ClusterName -Quiet -Command "isi quota quotas view `'$Path`' directory").split("`r")).Split("`n")
    Return $Result
}

function Get-IsilonFirmwareStatus {
    [CmdletBinding()]
    [OutputType([String])]
    Param([Parameter(Mandatory=$true)] [string]$ClusterName)
    $Temp = ([string](Invoke-SshCommand -ComputerName $ClusterName -Quiet -Command "isi firmware status").split("`r")).Split("`n")
    $Result=@()
    for ($i=2;$i-lt$Temp.count;$i++){
        $Subset1=($Temp[$i].Substring(3,12)).Replace(' ','')
        $Subset2=($Temp[$i].Substring(17,9)).Replace(' ','')
        $Subset3=($Temp[$i].Substring(28,39)).Replace(' ','')
        $Subset4=($Temp[$i].Substring(69)).Replace(' ','')
        $Element=New-Object -TypeName PSObject
        Add-Member -InputObject $Element -MemberType NoteProperty -Name Device -Value $Subset1
        Add-Member -InputObject $Element -MemberType NoteProperty -Name Type -Value $Subset2
        Add-Member -InputObject $Element -MemberType NoteProperty -Name Firmware -Value $Subset3
        Add-Member -InputObject $Element -MemberType NoteProperty -Name Nodes -Value $Subset4
        $Result+=$Element
    }
    Return $Result
}

function Get-IsilonLicenseStatus {
    [CmdletBinding()]
    [OutputType([String])]
    Param([Parameter(Mandatory=$true)] [string]$ClusterName)
    $Temp = ([string](Invoke-SshCommand -ComputerName $ClusterName -Quiet -Command "isi license").split("`r")).Split("`n")
    $Result=@()
    for ($i=2;$i-lt$Temp.count;$i++){
        $Subset1=($Temp[$i].Substring(0,24)).Replace(' ','')
        $Subset2=($Temp[$i].Substring(26,17)).Replace(' ','')
        $Subset3=($Temp[$i].Substring(44,17)).Replace(' ','')
        $Subset4=($Temp[$i].Substring(62)).Replace(' ','')
        $Element=New-Object -TypeName PSObject
        Add-Member -InputObject $Element -MemberType NoteProperty -Name Module -Value $Subset1
        Add-Member -InputObject $Element -MemberType NoteProperty -Name LicenseStatus -Value $Subset2
        Add-Member -InputObject $Element -MemberType NoteProperty -Name Configuration -Value $Subset3
        Add-Member -InputObject $Element -MemberType NoteProperty -Name ExpirationDate -Value $Subset4
        $Result+=$Element
    }
    Return $Result
}

function Get-IsilonListCurrentJobs {
    [CmdletBinding()]
    Param([Parameter(Mandatory=$true)]  [string]$ClusterName,
          [Parameter(Mandatory=$false)] [boolean]$Detailed=$true)
    if ($Detailed){$a=" -v"}else{$a=$null}
    $t = [string](Invoke-SshCommand -ComputerName $ClusterName -Quiet -Command "isi job jobs list --format json$a")
    if ($t){$Result = ConvertFrom-Json -InputObject $t} else {$Result = $null}
    Return $Result
}

function Get-IsilonListEvents {
    [CmdletBinding()]
    Param([Parameter(Mandatory=$true)]  [string]$ClusterName)
    "id,start_time,end_time,severity,lnn,message" | Out-File -FilePath $SFTempFile -Force
    [string](Invoke-SshCommand -ComputerName $ClusterName -Quiet -Command "isi events list --csv").split("`r") | Out-File -FilePath $SFTempFile -Append -NoClobber
    $Result = Import-Csv $SFTempFile
    Remove-Item -Path $SFTempFile
    Return $Result
}

function Get-IsilonListJobs {
    [CmdletBinding()]
    Param([Parameter(Mandatory=$true)]  [string]$ClusterName,
          [Parameter(Mandatory=$false)] [boolean]$Detailed=$true)
    if ($Detailed){$a=" -v"}else{$a=$null}
    $t = [string](Invoke-SshCommand -ComputerName $ClusterName -Quiet -Command "isi job jobs list --format json$a")
    if ($t){$Result = ConvertFrom-Json -InputObject $t} else {$Result = $null}
    Return $Result
}

function Get-IsilonListJobEvents {
    [CmdletBinding()]
    Param([Parameter(Mandatory=$true)]  [string]$ClusterName,
          [Parameter(Mandatory=$false)] [boolean]$Detailed=$true)
    if ($Detailed){$a=" -v"}else{$a=$null}
    $t = [string](Invoke-SshCommand -ComputerName $ClusterName -Quiet -Command "isi job events list --format json$a")
    if ($t){$Result = ConvertFrom-Json -InputObject $t} else {$Result = $null}
    Return $Result
}

function Get-IsilonListJobPolicies {
    [CmdletBinding()]
    Param([Parameter(Mandatory=$true)]  [string]$ClusterName,
          [Parameter(Mandatory=$false)] [boolean]$Detailed=$true)
    if ($Detailed){$a=" -v"}else{$a=$null}
    $t = [string](Invoke-SshCommand -ComputerName $ClusterName -Quiet -Command "isi job policies list --format json$a")
    if ($t){$Result = ConvertFrom-Json -InputObject $t} else {$Result = $null}
    Return $Result
}

function Get-IsilonListJobReports {
    [CmdletBinding()]
    Param([Parameter(Mandatory=$true)]  [string]$ClusterName)
    $t = [string](Invoke-SshCommand -ComputerName $ClusterName -Quiet -Command "isi job reports list --format json")
    if ($t){$Result = ConvertFrom-Json -InputObject $t} else {$Result = $null}
    Return $Result
}

function Get-IsilonListJobTypes {
    [CmdletBinding()]
    Param([Parameter(Mandatory=$true)]  [string]$ClusterName,
          [Parameter(Mandatory=$false)] [boolean]$Detailed=$true,
          [Parameter(Mandatory=$false)] [boolean]$ShowHidden=$false)
    if ($Detailed){$a=" -v"}else{$a=$null}
    if ($ShowHidden){$b=" --all"}else{$b=$null}
    $t = [string](Invoke-SshCommand -ComputerName $ClusterName -Quiet -Command "isi job types list --format json$a$b")
    if ($t){$Result = ConvertFrom-Json -InputObject $t} else {$Result = $null}
    Return $Result
}

function Get-IsilonListNFSShares {
    [CmdletBinding()]
    Param([Parameter(Mandatory=$true)]  [string]$ClusterName,
          [Parameter(Mandatory=$false)] [boolean]$Detailed=$true)
    if ($Detailed){$a=" -v"}else{$a=$null}
    $t = [string](Invoke-SshCommand -ComputerName $ClusterName -Quiet -Command "isi nfs exports list --format json$a")
    if ($t){$Result = ConvertFrom-Json -InputObject $t} else {$Result = $null}
    Return $Result
}

function Get-IsilonListSMBShares {
    [CmdletBinding()]
    Param([Parameter(Mandatory=$true)]  [string]$ClusterName,
          [Parameter(Mandatory=$false)] [boolean]$Detailed=$true)
    if ($Detailed){$a=" -v"}else{$a=$null}
    $t = [string](Invoke-SshCommand -ComputerName $ClusterName -Quiet -Command "isi smb share list --format json$a")
    if ($t){$Result = ConvertFrom-Json -InputObject $t} else {$Result = $null}
    Return $Result
}

function Get-IsilonListSyncPolicies {
    [CmdletBinding()]
    Param([Parameter(Mandatory=$true)]  [string]$ClusterName,
          [Parameter(Mandatory=$false)] [boolean]$Detailed=$true)
    if ($Detailed){$a=" -v"}else{$a=$null}
    $t = [string](Invoke-SshCommand -ComputerName $ClusterName -Quiet -Command "isi sync policies list --sort name --format json$a")
    # Can timeout so attempt a 2nd time if no results
    if (!$t) {$t = [string](Invoke-SshCommand -ComputerName $ClusterName -Quiet -Command "isi sync policies list --sort name --format json$a")}
    if ($t){$Result = ConvertFrom-Json -InputObject $t} else {$Result = $null}
    Return ($Result)
}

function Get-IsilonListSyncReports {
    [CmdletBinding()]
    Param([Parameter(Mandatory=$true)]  [string]$ClusterName,
          [Parameter(Mandatory=$false)] [boolean]$Detailed=$true)
    if ($Detailed){$a=" -v"}else{$a=$null}
    $t = [string](Invoke-SshCommand -ComputerName $ClusterName -Quiet -Command "isi sync reports list --sort start_time --descending --reports-per-policy 1 --format json$a")
    if ($t){$Result = ConvertFrom-Json -InputObject $t} else {$Result = $null}
    Return $Result
}

function Get-IsilonListSnapshots {
    [CmdletBinding()]
    Param([Parameter(Mandatory=$true)]  [string]$ClusterName,
          [Parameter(Mandatory=$false)] [boolean]$Detailed=$true)
    if ($Detailed){$a=" -v"}else{$a=$null}
    $t = [string](Invoke-SshCommand -ComputerName $ClusterName -Quiet -Command "isi snapshot snapshots list --format json$a")
    # Command can timeout
    if (!$t) {$t = [string](Invoke-SshCommand -ComputerName $ClusterName -Quiet -Command "isi snapshot snapshots list --format json$a")}
    if ($t){$Result = ConvertFrom-Json -InputObject $t} else {$Result = $null}
    Return $Result
}

function Get-IsilonListQuotas {
    [CmdletBinding()]
    Param([Parameter(Mandatory=$true)]  [string]$ClusterName,
          [Parameter(Mandatory=$false)] [boolean]$Detailed=$true)
    if ($Detailed){$a=" -v"}else{$a=$null}
    $t = [string](Invoke-SshCommand -ComputerName $ClusterName -Quiet -Command "isi quota quotas list --format json$a")
    if ($t){$Result = ConvertFrom-Json -InputObject $t} else {$Result = $null}
    Return $Result
}

function Get-IsilonNodeTime {
    [CmdletBinding()]
    [OutputType([String])]
    Param([Parameter(Mandatory=$true)]  [string]$ClusterName)
    $Result = ([string](Invoke-SshCommand -ComputerName $ClusterName -Quiet -Command "isi_for_array -s date").split("`r")).Split("`n")
    Return $Result
}

function Get-IsilonReadWriteStatus {
    [CmdletBinding()]
    [OutputType([String])]
    Param([Parameter(Mandatory=$true)] [string]$ClusterName)
    $Temp = ([string](Invoke-SshCommand -ComputerName $ClusterName -Quiet -Command "isi readonly show").split("`r")).Split("`n")
    $Result=@()
    for ($i=2;$i-lt$Temp.count;$i++){
        $Subset1=($Temp[$i].Substring(0,4)).Replace(' ','')
        if ($Temp[$i].Length-ge20){
            $Subset2=($Temp[$i].Substring(6,12)).Replace(' ','')
            $Subset3=($Temp[$i].Substring(20)).Replace(' ','')
        } else {
            $Subset2=($Temp[$i].Substring(6)).Replace(' ','')
            $Subset3=$null
        }
        $Element=New-Object -TypeName PSObject
        Add-Member -InputObject $Element -MemberType NoteProperty -Name Node -Value $Subset1
        Add-Member -InputObject $Element -MemberType NoteProperty -Name Mode -Value $Subset2
        Add-Member -InputObject $Element -MemberType NoteProperty -Name Status -Value $Subset3
        $Result+=$Element
    }
    Return $Result
}

function Get-IsilonStatus {
    [CmdletBinding()]
    [OutputType([String])]
    Param([Parameter(Mandatory=$true)] [string]$ClusterName)
    $Result = ([string](Invoke-SshCommand -ComputerName $ClusterName -Quiet -Command "isi status").split("`r")).Split("`n")
    Return $Result
}

function Get-IsilonAppliedPatches {
    [CmdletBinding()]
    Param([Parameter(Mandatory=$true)]  [string]$ClusterName,
          [Parameter(Mandatory=$false)] [string]$PatchID=$null)
    $Result = ([string](Invoke-SshCommand -ComputerName $ClusterName -Quiet -Command "isi pkg info $PatchID").split("`r")).Split("`n")
    if (($Result[0]-like"patch-*")-and ($PatchID.length-eq0)) {
        $Result=(($Result.replace(':','        Installed.')) | Select-String -Pattern 'patch-')
    }
    Return $Result
}

function Get-IsilonNodeStatus {
    [CmdletBinding()]
    [OutputType([String])]
    Param([Parameter(Mandatory=$true)] [string]$ClusterName)

    $t = ([string](Invoke-SshCommand -ComputerName $ClusterName -Quiet -Command "isi status").split("`r")).Split("`n")
    for ($i=0;$i-lt$t.count;$i++){if ($t[$i].Contains('ID |IP Address')) {$NodeStartBlock=$i+2;break}}
    for (;$i-lt$t.count;$i++){if ($t[$i].Contains('Cluster Totals')) {$NodeEndBlock=$i-1;break}}
    $NodeBlock=@{}
    for ($i=$NodeStartBlock;$i-lt$NodeEndBlock;$i++) {
        $NodeBlock[($i-$NodeStartBlock)]=($ifsStatus[$i].Replace(' ','').Replace('(NoSSDs)','0,0,0').Replace('(',',').Replace('%)',''))
    }
    $t[($NodeStartBlock-2)].Replace(' ','').Replace('InOut','In|Out|').Replace('al|Used/Size','al|HDD_Used,HDD_Size,HDD_Percent').Replace('Used/Size','SSD_Used,SSD_Size,SSD_Percent') | Convert-Delimiter '\|' "," | Set-Content $SFTempFile

    $NodeBlock.Values | Convert-Delimiter '\|' "," | Convert-Delimiter '\/' "," | Add-Content $SFTempFile

    $Result = Import-Csv $SFTempFile
    Remove-Item -Path $SFTempFile
    Return $Result
}

function Get-IsilonUserQuota {
    [CmdletBinding()]
    [OutputType([String])]
    Param([Parameter(Mandatory=$true)]  [string]$ClusterName,
          [Parameter(Mandatory=$true)]  [string]$Path,
          [Parameter(Mandatory=$false)] [string]$User)
    Write-Output "This function is under development and may not work"
    $Command = "isi quota quotas view `'$Path`' user"
    if ($User){$Command += " --user $User"}
    [string](Invoke-SshCommand -ComputerName $ClusterName -Quiet -Command $Command).split("`r") | Out-File -FilePath $SFTempFile -Force
    $Result = Import-Csv $SFTempFile
    Remove-Item -Path $SFTempFile
    Return $Result
}

function Get-IsilonVersion {
    [CmdletBinding()]
    [OutputType([String])]
    Param([Parameter(Mandatory=$true)] [string]$ClusterName)
    $Result = ([string](Invoke-SshCommand -ComputerName $ClusterName -Quiet -Command "isi version").split("`r")).Split("`n")
    Return $Result
}

function New-IsilonQuota {
    [CmdletBinding()]
    [OutputType([String])]
    Param([Parameter(Mandatory=$true)]  [string]$ClusterName,
          [Parameter(Mandatory=$true)]  [string]$Path,
          [Parameter(Mandatory=$true)]  [string]$HardThreshold,
          [Parameter(Mandatory=$false)] [string]$AdviseThreshold,
          [Parameter(Mandatory=$false)] [string]$SoftThreshold,
          [Parameter(Mandatory=$false)] [string]$SoftGrace,
          [Parameter(Mandatory=$false)] [boolean]$Container=$true,
          [Parameter(Mandatory=$false)] [boolean]$Snapshots=$false,
          [Parameter(Mandatory=$false)] [boolean]$Overhead=$false,
          [Parameter(Mandatory=$false)] [boolean]$Enforced=$false,
          [Parameter(Mandatory=$false)] [boolean]$Detailed=$false)
    if ($Detailed){$a=" -v"}else{$a=$null}
    $Command = "isi quota quotas create `'$Path`' directory$a --hard-threshold $HardThreshold --container $Container --include-snapshots $Snapshots --thresholds-include-overhead $Overhead --enforced $Enforced"
    if ($AdviseThreshold) {$Command += " --advisory-threshold $AdviseThreshold"}
    if ($SoftThreshold) {$Command += " --soft-threshold $SoftThreshold"}
    if ($SoftGrace) {$Command += " --soft-grace $SoftGrace"}
    $Result = ([string](Invoke-SshCommand -ComputerName $ClusterName -Quiet -Command $Command).split("`r")).Split("`n")
    Return $Result
}

function Remove-IsilonSMBShare {
    [CmdletBinding()]
    [OutputType([String])]
    Param([Parameter(Mandatory=$true)]  [string]$ClusterName,
          [Parameter(Mandatory=$true)]  [string]$Share,
          [Parameter(Mandatory=$false)] [boolean]$Detailed=$false)
    if ($Detailed){$a=" -v"}else{$a=$null}
    $Result = ([string](Invoke-SshCommand -ComputerName $ClusterName -Quiet -Command "isi smb shares delete `'$Share`' --force $a").split("`r")).Split("`n")
    Return $Result
}

function Remove-IsilonQuota {
    [CmdletBinding()]
    [OutputType([String])]
    Param([Parameter(Mandatory=$true)]  [string]$ClusterName,
          [Parameter(Mandatory=$true)]  [string]$Path,
          [Parameter(Mandatory=$false)] [boolean]$Detailed=$false)
    if ($Detailed){$a=" -v"}else{$a=$null}
    $Result = ([string](Invoke-SshCommand -ComputerName $ClusterName -Quiet -Command "isi quota quotas delete `'$Path`' directory$a").split("`r")).Split("`n")
    Return $Result
}

function Set-IsilonSyncTimeWithDomain {
    [CmdletBinding()]
    [OutputType([String])]
    Param([Parameter(Mandatory=$true)]  [string]$ClusterName,
          [Parameter(Mandatory=$true)]  [string]$Domain)
    $Result = ([string](Invoke-SshCommand -ComputerName $ClusterName -Quiet -Command "isi_for_array -s isi_classic auth ads time --sync --domain=$Domain --force").split("`r")).Split("`n")
    Return $Result
}

function Disconnect-IsilonCluster {
    [CmdletBinding()]
    [OutputType([String])]
    Param([Parameter(Mandatory=$true)] [string]$ClusterName)
    $Result = ([string](Remove-SshSession -ComputerName $ClusterName).split("`r")).Split("`n")
    Return $Result
}





