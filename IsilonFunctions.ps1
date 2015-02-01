Import-Module SSH-Sessions
# Made the temporary file more unique based on the datetime the script is executed
$Today=Get-Date
$SFTempFile = "$env:temp\sftempfile-{0:D4}{1:D2}{2:D2}-{3:D2}{4:D2}{5:D2}.csv" -F $Today.Year,$Today.Month,$Today.Day,$Today.Hour,$Today.Minute,$Today.Second
if (Test-Path ($SFTempFile)){Remove-Item $SFTempFile}

# Things to include:
#   Get the current status of system varilables, eg. Maximum number of snapshots, etc
#
#   isi status -n
#   isi_hw_status
#

Write-Host "`n`tIsilon Module v1.0.4"
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
    Write-Verbose 'This command executed the following:'
    Write-Verbose 'Get-Command *-Isilon* -CommandType Function | Sort-Object Name'
    Get-Command *-Isilon* -CommandType Function | Sort-Object Name
}

function Connect-IsilonCluster {
    [CmdletBinding()]
    [OutputType([String])]
    Param([Parameter(Mandatory=$true)] [string]$ClusterName,
          [Parameter(Mandatory=$true)] [string]$Username,
          [Parameter(Mandatory=$true)] [string]$Password)
    Write-Verbose 'Attempting to establish an SSH session'
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
    Write-Verbose 'Gather information on the battery status'
    $Temp = (([string](Invoke-SshCommand -ComputerName $ClusterName -Quiet -Command "isi_for_array -s isi batterystatus").split("`r")).Split("`n")).Replace(' ','')
    if ($Temp-like"*Batterystatusnotsupportedonthishardware*") {Write-Verbose "Battery Status not supported on this hardware"; $Temp=$null}

    $Result=@()
    Write-Verbose 'Create the array of objects'

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
    Write-Verbose "This command is still a Work in Progress"
    $Temp = (([string](Invoke-SshCommand -ComputerName $ClusterName -Quiet -Command "isi_for_array -s isi_hw_status").split("`r")).Split("`n")).Replace(' ','')
    $Result = $Temp
    # Magic goes here to extract all the information and create objects
    Return $Result
}

function Get-IsilonClusterHealth {
    [CmdletBinding()]
    [OutputType([String])]
    Param([Parameter(Mandatory=$true)] [string]$ClusterName)
    "Node,Health" | Set-Content $SFTempFile
    $Temp = (([string](Invoke-SshCommand -ComputerName $ClusterName -Quiet -Command "isi_for_array -Q -s 'isi devices | grep Node'").split("`r")).Split("`n")).Replace(' ','').Replace('[','').Replace(']','').Replace('42;30m','').Replace('0m','').Replace('43;3','').Replace('41;37m','') | Add-Content $SFTempFile
    $Result = Import-Csv $SFTempFile
    Remove-Item -Path $SFTempFile
    Return $Result
}

function Get-IsilonSystemIdentification {
    [CmdletBinding()]
    [OutputType([String])]
    Param([Parameter(Mandatory=$true)] [string]$ClusterName)
    "Node,SerialNumber,SystemConfig,FamilyCode,ChassisCode,GenerationCode,Product" | Set-Content $SFTempFile
    $Temp = (([string](Invoke-SshCommand -ComputerName $ClusterName -Quiet -Command "isi_for_array -s isi_hw_status -THi").split("`r")).Split("`n")).Replace(':',' ') | Convert-Delimiter " +" "," | Add-Content $SFTempFile
    $Result = Import-Csv $SFTempFile
    Remove-Item -Path $SFTempFile
    Return $Result
}

function Get-IsilonUptime {
# This function is a WIP
# Need to format the output into [PSObject] not just [string[]]
    [CmdletBinding()]
    [OutputType([String])]
    Param([Parameter(Mandatory=$true)] [string]$ClusterName)
    Write-Verbose "This command is still a Work in Progress"
    $Temp = (([string](Invoke-SshCommand -ComputerName $ClusterName -Quiet -Command 'isi_for_array -s "uptime"').split("`r")).Split("`n"))
    $Result = $Temp
    Return $Result
}

function Restart-IsilonNode {
    [CmdletBinding()]
    [OutputType([String])]
    Param([Parameter(Mandatory=$true)] [string]$ClusterName,
          [Parameter(Mandatory=$true)] [int]$Node)
    $Temp = (([string](Invoke-SshCommand -ComputerName $ClusterName -Quiet -Command "isi_for_array -n $Node 'shutdown -r now'").split("`r")).Split("`n"))
    $Result = $Temp
    Return $Result
}

function Get-IsilonNodeIFSversion {
    [CmdletBinding()]
    [OutputType([String])]
    Param([Parameter(Mandatory=$true)] [string]$ClusterName)
    "Node,Version" | Set-Content $SFTempFile
    $Temp = (([string](Invoke-SshCommand -ComputerName $ClusterName -Quiet -Command 'isi_for_array -s uname -r').split("`r")).Split("`n")).Replace(' v','').Replace(':',' ') | Convert-Delimiter " +" "," | Add-Content $SFTempFile
    $Result = Import-Csv $SFTempFile
    Remove-Item -Path $SFTempFile
    Return $Result
}

function Get-IsilonNICs {
    [CmdletBinding()]
    [OutputType([String])]
    Param([Parameter(Mandatory=$true)] [string]$ClusterName)
    $Temp = (([string](Invoke-SshCommand -ComputerName $ClusterName -Quiet -Command 'isi networks list interfaces -w').Replace('-','').Replace(',','/').Replace('no carrier','no_carrier').split("`r")).Split("`n"))  | Convert-Delimiter " +" "," | Add-Content $SFTempFile
    $Result = Import-Csv $SFTempFile
    Remove-Item -Path $SFTempFile
    Return $Result
}

function Get-IsilonSubnets {
    [CmdletBinding()]
    [OutputType([PSObject])]
    Param([Parameter(Mandatory=$true)] [string]$ClusterName)
    $t = (([string](Invoke-SshCommand -ComputerName $ClusterName -Quiet -Command "isi networks list subnets").Replace('-','').Replace('Gateway:Prio','GatewayPrio').Replace('SC Service','SCService').split("`r")).Split("`n")) | Convert-Delimiter " +" "," | Set-Content $SFTempFile
    $t = Import-Csv $SFTempFile
    Write-Verbose 'Create an array of objects'
    $Result=@()
    for ($i=0;$i -lt $t.Count;$i++) {
        $t2=(([string](Invoke-SshCommand -ComputerName $ClusterName -Quiet -Command "isi networks list subnets -v -n $($t[$i].Name)").split("`r")).Split("`n"))
        if ($t2) {
            $Element=New-Object -TypeName PSObject
            Add-Member -InputObject $Element -MemberType NoteProperty -Name Name -Value ($t[$i].Name)
            for ($i2=0;$i2 -lt $t2.Count;$i2++) {
                Switch ($t2[$i2].Trim()) 
                {
                    {$PSItem.Contains('Address Family: ')} {Add-Member -InputObject $Element -MemberType NoteProperty -Name AddressFamily -Value ($t2[$i2].Replace('Address Family: ','').Trim()); break}
                    {$PSItem.Contains('Netmask: ')} {Add-Member -InputObject $Element -MemberType NoteProperty -Name Netmask -Value ($t2[$i2].Replace('Netmask: ','').Trim()); break}
                    {$PSItem.Contains('Subnet: ')} {Add-Member -InputObject $Element -MemberType NoteProperty -Name Subnet -Value ($t2[$i2].Replace('Subnet: ','').Trim()); break}
                    {$PSItem.Contains('Gateway ')} {Add-Member -InputObject $Element -MemberType NoteProperty -Name Gateway -Value ($t2[$i2].Replace('Gateway ','').Trim()); break}
                    {$PSItem.Contains('MTU: ')} {Add-Member -InputObject $Element -MemberType NoteProperty -Name MTU -Value ($t2[$i2].Replace('MTU: ','').Trim()); break}
                    {$PSItem.Contains('SC Service Address: ')} {Add-Member -InputObject $Element -MemberType NoteProperty -Name SCServiceAddress -Value ($t2[$i2].Replace('SC Service Address: ','').Trim()); break}
                    {$PSItem.Contains('VLAN Tagging: ')} {Add-Member -InputObject $Element -MemberType NoteProperty -Name VLANTagging -Value ($t2[$i2].Replace('VLAN Tagging: ','').Trim()); break}
                    {$PSItem.Contains('VLAN ID: ')} {Add-Member -InputObject $Element -MemberType NoteProperty -Name VLANID -Value ($t2[$i2].Replace('VLAN ID: ','').Trim()); break}
                    {$PSItem.Contains('DSR Addresses: ')} {Add-Member -InputObject $Element -MemberType NoteProperty -Name DSRAddresses -Value ($t2[$i2].Replace('DSR Addresses: ','').Trim()); break}
                    {$PSItem.Contains('Pools: ')} {
                        $Count = [int]$t2[$i2].Replace('Pools: ','').Trim()
                        if ($Count -gt 0) {
                            $SubElement=@()
                            for ($i2++;$i2 -lt $t2.Count;$i2++) {
                                $SubElement+=$t2[$i2].Trim()
                            }
                            Add-Member -InputObject $Element -MemberType NoteProperty -Name Pools -Value $SubElement
                        }
                    }
                }
            }
            $Result+=$Element
        }
    }
    Return $Result
}

function Get-IsilonPools {
# This function is not yet finished.  At the moment it just gets
# the basic information.  Needs to be enhanced to include verbose
# information which contains more information.
    [CmdletBinding()]
    [OutputType([String])]
    Param([Parameter(Mandatory=$true)] [string]$ClusterName)
    $Result = (([string](Invoke-SshCommand -ComputerName $ClusterName -Quiet -Command "isi networks list pools -v").split("`r")).Split("`n"))
#    $Temp = (([string](Invoke-SshCommand -ComputerName $ClusterName -Quiet -Command "isi networks list pools").Replace('-','').Replace('SmartConnect Zone','SmartConnectZone').split("`r")).Split("`n")) | Convert-Delimiter " +" "," | Add-Content $SFTempFile
#    $Result = Import-Csv $SFTempFile
#    Remove-Item -Path $SFTempFile
    Return $Result
}

function Get-IsilonRules {
# This function is not yet finished.  At the moment it just gets
# the basic information.  Needs to be enhanced to include verbose
# information which contains more information.
    [CmdletBinding()]
    [OutputType([String])]
    Param([Parameter(Mandatory=$true)] [string]$ClusterName)
    $Temp = (([string](Invoke-SshCommand -ComputerName $ClusterName -Quiet -Command "isi networks list rules").Replace('-','').Replace('SmartConnect Zone','SmartConnectZone').split("`r")).Split("`n")) | Convert-Delimiter " +" "," | Add-Content $SFTempFile
    $Result = Import-Csv $SFTempFile
    Remove-Item -Path $SFTempFile
    Return $Result
}

function Get-IsilonAdvancedStatus {
# This function is a WIP
# Need to format the output into [PSObject] not just [string[]]
    [CmdletBinding()]
    [OutputType([String])]
    Param([Parameter(Mandatory=$true)] [string]$ClusterName)
    Write-Verbose "This command is still a Work in Progress"
    $Temp = (([string](Invoke-SshCommand -ComputerName $ClusterName -Quiet -Command 'echo "status advanced" | isi config').split("`r")).Split("`n"))
    $Result = $Temp
    Return $Result
}

function Get-IsilonBootDriveStatus {
# This function is a WIP
# Need to format the output into [PSObject] not just [string[]]
    [CmdletBinding()]
    [OutputType([String])]
    Param([Parameter(Mandatory=$true)] [string]$ClusterName)
    Write-Verbose "This command is still a Work in Progress"
    $Temp = (([string](Invoke-SshCommand -ComputerName $ClusterName -Quiet -Command 'isi_for_array -s "gmirror status"').split("`r")).Split("`n"))
    $Result = $Temp
    Return $Result
}

function Get-IsilonDMILog {
# This function is a WIP
# Need to format the output into [PSObject] not just [string[]]
    [CmdletBinding()]
    [OutputType([String])]
    Param([Parameter(Mandatory=$true)] [string]$ClusterName)
    Write-Verbose "This command is still a Work in Progress"
    $Temp = (([string](Invoke-SshCommand -ComputerName $ClusterName -Quiet -Command 'isi_for_array -s "isi_dmilog"').split("`r")).Split("`n"))
    $Result = $Temp
    Return $Result
}

function Get-IsilonOpenSMMaster {
# This function is a WIP
# Need to format the output into [PSObject] not just [string[]]
    [CmdletBinding()]
    [OutputType([String])]
    Param([Parameter(Mandatory=$true)] [string]$ClusterName)
    Write-Verbose "This command is still a Work in Progress"
    $Temp = (([string](Invoke-SshCommand -ComputerName $ClusterName -Quiet -Command 'isi_for_array "ps auxww | grep opensm" | grep master').split("`r")).Split("`n"))
    $Result = $Temp
    Return $Result
}

function Get-IsilonUpdateCheck {
# This function is a WIP
# Need to format the output into [PSObject] not just [string[]]
    [CmdletBinding()]
    [OutputType([String])]
    Param([Parameter(Mandatory=$true)] [string]$ClusterName,
          [Parameter(Mandatory=$true)] [string]$Path)
    Write-Verbose "This command is still a Work in Progress"
    $Temp = (([string](Invoke-SshCommand -ComputerName $ClusterName -Quiet -Command "echo `"$Path`" | isi update --check-only").split("`r")).Split("`n"))
    $Result = $Temp
    Return $Result
}

function Get-IsilonGatherInfo {
# This function is a WIP
    [CmdletBinding()]
    [OutputType([String])]
    Param([Parameter(Mandatory=$true)] [string]$ClusterName)
    Write-Verbose "This command is still a Work in Progress"
    Write-Output "The 'Get-IsilonGatherInfo' command can take a long time depending on the size of the log file that is generated"
    $Temp = (([string](Invoke-SshCommand -ComputerName $ClusterName -Quiet -Command 'isi_gather_info').split("`r")).Split("`n"))
    $Result = $Temp
    Return $Result
}

function Get-IsilonDiskUsage {
    [CmdletBinding()]
    [OutputType([String])]
    Param([Parameter(Mandatory=$true)] [string]$ClusterName)
    Write-Verbose "Collecting disk usage information"
#    "node," | Set-Content $SFTempFile
# When run against all nodes the out for 'df -i' changes compaired to a single node.
#    ([string](Invoke-SshCommand -ComputerName $ClusterName -Quiet -Command "isi_for_array -s df -i").split("`r")).Split("`n").replace(':','').replace('Mounted on','MountedOn').replace('1K-blocks','K_blocks') | Convert-Delimiter " +" "," | Add-Content $SFTempFile
    ([string](Invoke-SshCommand -ComputerName $ClusterName -Quiet -Command "df -i").split("`r")).Split("`n").replace('Mounted on','MountedOn').replace('1K-blocks','K_blocks') | Convert-Delimiter " +" "," | Set-Content $SFTempFile
    $Result = Import-Csv $SFTempFile
    Remove-Item -Path $SFTempFile
    Return $Result
}

function Get-IsilonDirectoryQuota {
    [CmdletBinding()]
    [OutputType([String])]
    Param([Parameter(Mandatory=$true)] [string]$ClusterName,
          [Parameter(Mandatory=$true)] [string]$Path)
    Write-Verbose 'Gather information on Directory Quotas as an array of objects'
    $Result = ([string](Invoke-SshCommand -ComputerName $ClusterName -Quiet -Command "isi quota quotas view `'$Path`' directory").split("`r")).Split("`n")
    Return $Result
}

function Get-IsilonFirmwareStatus {
    [CmdletBinding()]
    [OutputType([String])]
    Param([Parameter(Mandatory=$true)] [string]$ClusterName)
    Write-Verbose 'Gather information on the Firmware Status'
    $Temp = ([string](Invoke-SshCommand -ComputerName $ClusterName -Quiet -Command "isi firmware status").split("`r")).Split("`n")
    if ($Temp[$Temp.count-1].Contains('NO DEVICES FOUND')) {Write-Verbose 'No devices found - possible VM'; $Temp=$null}
    Write-Verbose 'Create an array of objects'
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
    Write-Verbose 'Gather information on the current license status'
    $Temp = ([string](Invoke-SshCommand -ComputerName $ClusterName -Quiet -Command "isi license").split("`r")).Split("`n")
    Write-Verbose 'Create the array of objects'
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
    $Counter=0
    do {
        $Counter++
        Write-Verbose 'Gathering list of current jobs'
        $t = [string](Invoke-SshCommand -ComputerName $ClusterName -Quiet -Command "isi job jobs list --format json$a")
        # Can timeout so attempt a 2nd time if incorrect result
    } while (($t[0]-ne'[') -and ($Counter-lt2))
    if ($t[0]-eq'['){Write-Verbose 'Creating an array of objects'; $Result = ConvertFrom-Json -InputObject $t} else {Write-Verbose 'No data returned'; $Result = $null}
    Return $Result
}

function Get-IsilonListEvents {
    [CmdletBinding()]
    Param([Parameter(Mandatory=$true)]  [string]$ClusterName)
    "id,start_time,end_time,severity,lnn,message" | Out-File -FilePath $SFTempFile -Force
    # The repeated " `| sed 's/,/./ 6'" allows for 20 commas and everything after the 5th will be replaced with a dot
    Write-Verbose 'Gather information on Events'
    [string](Invoke-SshCommand -ComputerName $ClusterName -Quiet -Command "isi events list -w --csv `| sed 's/,/./ 6' `| sed 's/,/./ 6' `| sed 's/,/./ 6' `| sed 's/,/./ 6' `| sed 's/,/./ 6' `| sed 's/,/./ 6' `| sed 's/,/./ 6' `| sed 's/,/./ 6' `| sed 's/,/./ 6' `| sed 's/,/./ 6' `| sed 's/,/./ 6' `| sed 's/,/./ 6' `| sed 's/,/./ 6' `| sed 's/,/./ 6' `| sed 's/,/./ 6'").split("`r") | Out-File -FilePath $SFTempFile -Append -NoClobber
    Write-Verbose 'Create an array of objects'
    $Result = Import-Csv $SFTempFile
    Remove-Item -Path $SFTempFile
    Return $Result
}

function Get-IsilonListJobs {
    [CmdletBinding()]
    Param([Parameter(Mandatory=$true)]  [string]$ClusterName,
          [Parameter(Mandatory=$false)] [boolean]$Detailed=$true)
    if ($Detailed){$a=" -v"}else{$a=$null}
    $Counter=0
    do {
        $Counter++
        Write-Verbose 'Gathering list of Jobs'
        $t = [string](Invoke-SshCommand -ComputerName $ClusterName -Quiet -Command "isi job jobs list --format json$a")
        # Can timeout so attempt a 2nd time if incorrect result
    } while (($t[0]-ne'[') -and ($Counter-lt2))
    if ($t[0]-eq'['){Write-Verbose 'Creating an array of objects'; $Result = ConvertFrom-Json -InputObject $t} else {Write-Verbose 'No data returned'; $Result = $null}
    Return $Result
}

function Get-IsilonListJobEvents {
    [CmdletBinding()]
    Param([Parameter(Mandatory=$true)]  [string]$ClusterName,
          [Parameter(Mandatory=$false)] [boolean]$Detailed=$true)
    if ($Detailed){$a=" -v"}else{$a=$null}
    $Counter=0
    do {
        $Counter++
        Write-Verbose 'Gathering list of job events'
        $t = [string](Invoke-SshCommand -ComputerName $ClusterName -Quiet -Command "isi job events list --format json$a")
        # Can timeout so attempt a 2nd time if incorrect result
    } while (($t[0]-ne'[') -and ($Counter-lt2))
    if ($t[0]-eq'['){Write-Verbose 'Creating an array of objects'; $Result = ConvertFrom-Json -InputObject $t} else {Write-Verbose 'No data returned'; $Result = $null}
    Return $Result
}

function Get-IsilonListJobPolicies {
    [CmdletBinding()]
    Param([Parameter(Mandatory=$true)]  [string]$ClusterName,
          [Parameter(Mandatory=$false)] [boolean]$Detailed=$true)
    if ($Detailed){$a=" -v"}else{$a=$null}
    $Counter=0
    do {
        $Counter++
        Write-Verbose 'Gathering list of job policies'
        $t = [string](Invoke-SshCommand -ComputerName $ClusterName -Quiet -Command "isi job policies list --format json$a")
        # Can timeout so attempt a 2nd time if incorrect result
    } while (($t[0]-ne'[') -and ($Counter-lt2))
    if ($t[0]-eq'['){Write-Verbose 'Creating an array of objects'; $Result = ConvertFrom-Json -InputObject $t} else {Write-Verbose 'No data returned'; $Result = $null}
    Return $Result
}

function Get-IsilonListJobReports {
    [CmdletBinding()]
    Param([Parameter(Mandatory=$true)]  [string]$ClusterName)
    $Counter=0
    do {
        $Counter++
        Write-Verbose 'Gathering list of job reports'
        $t = [string](Invoke-SshCommand -ComputerName $ClusterName -Quiet -Command "isi job reports list --format json")
        # Can timeout so attempt a 2nd time if incorrect result
    } while (($t[0]-ne'[') -and ($Counter-lt2))
    if ($t[0]-eq'['){Write-Verbose 'Creating an array of objects'; $Result = ConvertFrom-Json -InputObject $t} else {Write-Verbose 'No data returned'; $Result = $null}
    Return $Result
}

function Get-IsilonListJobTypes {
    [CmdletBinding()]
    Param([Parameter(Mandatory=$true)]  [string]$ClusterName,
          [Parameter(Mandatory=$false)] [boolean]$Detailed=$true,
          [Parameter(Mandatory=$false)] [boolean]$ShowHidden=$false)
    if ($Detailed){$a=" -v"}else{$a=$null}
    if ($ShowHidden){$b=" --all"}else{$b=$null}
    $Counter=0
    do {
        $Counter++
        Write-Verbose 'Gathering list of job types'
        $t = [string](Invoke-SshCommand -ComputerName $ClusterName -Quiet -Command "isi job types list --format json$a$b")
        # Can timeout so attempt a 2nd time if incorrect result
    } while (($t[0]-ne'[') -and ($Counter-lt2))
    if ($t[0]-eq'['){Write-Verbose 'Creating an array of objects'; $Result = ConvertFrom-Json -InputObject $t} else {Write-Verbose 'No data returned'; $Result = $null}
    Return $Result
}

function Get-IsilonListNFSShares {
    [CmdletBinding()]
    Param([Parameter(Mandatory=$true)]  [string]$ClusterName,
          [Parameter(Mandatory=$false)] [boolean]$Detailed=$true)
    if ($Detailed){$a=" -v"}else{$a=$null}
    $Counter=0
    do {
        $Counter++
        Write-Verbose 'Gathering list of NFS Shares'
        $t = [string](Invoke-SshCommand -ComputerName $ClusterName -Quiet -Command "isi nfs exports list --format json$a")
        # Can timeout so attempt a 2nd time if incorrect result
    } while (($t[0]-ne'[') -and ($Counter-lt2))
    if ($t[0]-eq'['){Write-Verbose 'Creating an array of objects'; $Result = ConvertFrom-Json -InputObject $t} else {Write-Verbose 'No data returned'; $Result = $null}
    Return $Result
}

function Get-IsilonListSMBShares {
    [CmdletBinding()]
    Param([Parameter(Mandatory=$true)]  [string]$ClusterName,
          [Parameter(Mandatory=$false)] [boolean]$Detailed=$true)
    if ($Detailed){$a=" -v"}else{$a=$null}
    $Counter=0
    do {
        $Counter++
        Write-Verbose 'Gathering list of SMB Shares'
        $t = [string](Invoke-SshCommand -ComputerName $ClusterName -Quiet -Command "isi smb share list --format json$a")
        # Can timeout so attempt a 2nd time if incorrect result
    } while (($t[0]-ne'[') -and ($Counter-lt2))
    if ($t[0]-eq'['){Write-Verbose 'Creating an array of objects'; $Result = ConvertFrom-Json -InputObject $t} else {Write-Verbose 'No data returned'; $Result = $null}
    Return $Result
}

function Get-IsilonListSyncJobs {
    [CmdletBinding()]
    Param([Parameter(Mandatory=$true)]  [string]$ClusterName,
          [Parameter(Mandatory=$false)] [boolean]$Detailed=$true)
    if ($Detailed){$a=" -v"}else{$a=$null}
    $Counter=0
    do {
        $Counter++
        Write-Verbose 'Gathering list of Sync Jobs'
        $t = [string](Invoke-SshCommand -ComputerName $ClusterName -Quiet -Command "isi sync jobs list --format json$a")
        # Can timeout so attempt a 2nd time if incorrect result
    } while (($t[0]-ne'[') -and ($Counter-lt2))
    if ($t[0]-eq'['){Write-Verbose 'Creating an array of objects'; $Result = ConvertFrom-Json -InputObject $t} else {Write-Verbose 'No data returned'; $Result = $null}
    Return ($Result)
}

function Get-IsilonListSyncPolicies {
    [CmdletBinding()]
    Param([Parameter(Mandatory=$true)]  [string]$ClusterName,
          [Parameter(Mandatory=$false)] [boolean]$Detailed=$true)
    if ($Detailed){$a=" -v"}else{$a=$null}
    $Counter=0
    do {
        $Counter++
        Write-Verbose 'Gathering list of Sync Policies'
        $t = [string](Invoke-SshCommand -ComputerName $ClusterName -Quiet -Command "isi sync policies list --sort name --format json$a")
        # Can timeout so attempt a 2nd time if incorrect result
    } while (($t[0]-ne'[') -and ($Counter-lt2))
    if ($t[0]-eq'['){Write-Verbose 'Creating an array of objects'; $Result = ConvertFrom-Json -InputObject $t} else {Write-Verbose 'No data returned'; $Result = $null}
    Return ($Result)
}

function Get-IsilonListSyncReports {
    [CmdletBinding()]
    Param([Parameter(Mandatory=$true)]  [string]$ClusterName,
          [Parameter(Mandatory=$false)] [boolean]$Detailed=$true)
    if ($Detailed){$a=" -v"}else{$a=$null}
    $Counter=0
    do {
        $Counter++
        Write-Verbose 'Gathering list of Sync Reports'
        $t = [string](Invoke-SshCommand -ComputerName $ClusterName -Quiet -Command "isi sync reports list --sort start_time --descending --reports-per-policy 1 --format json$a")
        # Can timeout so attempt a 2nd time if incorrect result
    } while (($t[0]-ne'[') -and ($Counter-lt2))
    if ($t[0]-eq'['){Write-Verbose 'Creating an array of objects'; $Result = ConvertFrom-Json -InputObject $t} else {Write-Verbose 'No data returned'; $Result = $null}
    Return $Result
}

function Get-IsilonListSnapshots {
    [CmdletBinding()]
    Param([Parameter(Mandatory=$true)]  [string]$ClusterName,
          [Parameter(Mandatory=$false)] [boolean]$Detailed=$true)
    Write-Verbose "This command can timeout and return a partial 'json' object"
    if ($Detailed){$a=" -v"}else{$a=$null}
    $Counter=0
    do {
        $Counter++
        Write-Verbose 'Gathering list of Snapshots'
        $t = [string](Invoke-SshCommand -ComputerName $ClusterName -Quiet -Command "isi snapshot snapshots list --format json$a")
        # Can timeout so attempt a 2nd time if incorrect result
    } while (($t[0]-ne'[') -and ($Counter-lt2))
    if ($t[0]-eq'['){Write-Verbose 'Creating an array of objects'; $Result = ConvertFrom-Json -InputObject $t} else {Write-Verbose 'No data returned'; $Result = $null}
    Return $Result
}

function Get-IsilonListQuotas {
    [CmdletBinding()]
    Param([Parameter(Mandatory=$true)]  [string]$ClusterName,
          [Parameter(Mandatory=$false)] [boolean]$Detailed=$true)
    if ($Detailed){$a=" -v"}else{$a=$null}
    $Counter=0
    do {
        $Counter++
        Write-Verbose 'Gathering list of Quotas'
        $t = [string](Invoke-SshCommand -ComputerName $ClusterName -Quiet -Command "isi quota quotas list --format json$a")
        # Can timeout so attempt a 2nd time if incorrect result
    } while (($t[0]-ne'[') -and ($Counter-lt2))
    if ($t[0]-eq'['){Write-Verbose 'Creating an array of objects'; $Result = ConvertFrom-Json -InputObject $t} else {Write-Verbose 'No data returned'; $Result = $null}
    Return $Result
}

function Get-IsilonNodeTime {
    [CmdletBinding()]
    [OutputType([String])]
    Param([Parameter(Mandatory=$true)]  [string]$ClusterName)
    "Node,DateTime" | Set-Content $SFTempFile
    Write-Verbose 'Gathering list of the current Node date/time'
    $Result = ([string](Invoke-SshCommand -ComputerName $ClusterName -Quiet -Command "isi_for_array -s date").split("`r")).Split("`n") | Convert-Delimiter ": " "," | Add-Content $SFTempFile
    Write-Verbose 'Creating an array of objects'
    $Result = Import-Csv $SFTempFile
    Remove-Item -Path $SFTempFile
    Return $Result
}

function Get-IsilonReadWriteStatus {
    [CmdletBinding()]
    [OutputType([String])]
    Param([Parameter(Mandatory=$true)] [string]$ClusterName)
    Write-Verbose 'Gathering list of Node Read/Write status'
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
    Write-Verbose "Running the 'isi status' command"
    $Result = ([string](Invoke-SshCommand -ComputerName $ClusterName -Quiet -Command "isi status").split("`r")).Split("`n")
    Return $Result
}

function Get-IsilonStatusDiskPool {
    [CmdletBinding()]
    [OutputType([String])]
    Param([Parameter(Mandatory=$true)] [string]$ClusterName)
    Write-Verbose "Running the 'isi status' command"
    $Result = ([string](Invoke-SshCommand -ComputerName $ClusterName -Quiet -Command "isi status -d").split("`r")).Split("`n")
    Return $Result
}

function Get-IsilonAppliedPatches {
    [CmdletBinding()]
    Param([Parameter(Mandatory=$true)]  [string]$ClusterName,
          [Parameter(Mandatory=$false)] [string]$PatchID=$null)
    Write-Verbose 'Gathering a list of the patches applied and/or attempted to be applied'
    $Result = ([string](Invoke-SshCommand -ComputerName $ClusterName -Quiet -Command "isi pkg info $PatchID").split("`r")).Split("`n")
    if (($Result[0]-like"patch-*")-and ($PatchID.length-eq0)) {
        Write-Verbose 'Creating a list of objects - only the patch ID lines'
        $Result=(($Result.replace(':','        Installed.')) | Select-String -Pattern 'patch-')
    }
    Return $Result
}

function Get-IsilonNodeStatus {
    [CmdletBinding()]
    [OutputType([String])]
    Param([Parameter(Mandatory=$true)] [string]$ClusterName)
    Write-Verbose 'Gathering the status of the cluster'
    $t = Get-IsilonStatus -$ClusterName
#    $t = ([string](Invoke-SshCommand -ComputerName $ClusterName -Quiet -Command "isi status").split("`r")).Split("`n")
    Write-Verbose 'Extracting the Node Status table'
    for ($i=0;$i-lt$t.count;$i++){if ($t[$i].Contains('ID |IP Address')) {$NodeStartBlock=$i+2;break}}
    for (;$i-lt$t.count;$i++){if ($t[$i].Contains('Cluster Totals')) {$NodeEndBlock=$i-1;break}}
    $NodeBlock=@{}
    Write-Verbose 'Text replacement going on'
    for ($i=$NodeStartBlock;$i-lt$NodeEndBlock;$i++) {
        $NodeBlock[($i-$NodeStartBlock)]=($ifsStatus[$i].Replace(' ','').Replace('(NoSSDs)','0,0,0').Replace('(',',').Replace('%)',''))
    }
    $t[($NodeStartBlock-2)].Replace(' ','').Replace('InOut','In|Out|').Replace('al|Used/Size','al|HDD_Used,HDD_Size,HDD_Percent').Replace('Used/Size','SSD_Used,SSD_Size,SSD_Percent') | Convert-Delimiter '\|' "," | Set-Content $SFTempFile
    $NodeBlock.Values | Convert-Delimiter '\|' "," | Convert-Delimiter '\/' "," | Add-Content $SFTempFile
    Write-Verbose 'Creating an array of objects'
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
    Write-Verbose 'Gather the oneFS version number information'
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
    Write-Verbose 'Create a new quota'
    Write-Verbose "SSH command is: $Command"
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
    Write-Verbose 'Remove an SMB Share'
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
    Write-Verbose 'Remove a quota'
    $Result = ([string](Invoke-SshCommand -ComputerName $ClusterName -Quiet -Command "isi quota quotas delete `'$Path`' directory$a").split("`r")).Split("`n")
    Return $Result
}

function Set-IsilonSyncTimeWithDomain {
    [CmdletBinding()]
    [OutputType([String])]
    Param([Parameter(Mandatory=$true)]  [string]$ClusterName,
          [Parameter(Mandatory=$true)]  [string]$Domain)
    Write-Verbose 'Set all the Node date/time to match the Domain Controller'
    $Result = ([string](Invoke-SshCommand -ComputerName $ClusterName -Quiet -Command "isi_for_array -s isi_classic auth ads time --sync --domain=$Domain --force").split("`r")).Split("`n")
    Return $Result
}

function Set-IsilonQuota {
    [CmdletBinding()]
    [OutputType([String])]
    Param([Parameter(Mandatory=$true)]  [string]$ClusterName,
          [Parameter(Mandatory=$true)]  [string]$Path,
          [Parameter(Mandatory=$false)] [string]$HardThreshold,
          [Parameter(Mandatory=$false)] [string]$AdviseThreshold,
          [Parameter(Mandatory=$false)] [string]$SoftThreshold,
          [Parameter(Mandatory=$false)] [string]$SoftGrace,
          [Parameter(Mandatory=$false)] [boolean]$Container,
          [Parameter(Mandatory=$false)] [boolean]$Snapshots,
          [Parameter(Mandatory=$false)] [boolean]$Overhead,
          [Parameter(Mandatory=$false)] [boolean]$Enforced,
          [Parameter(Mandatory=$false)] [boolean]$Detailed)
    Write-Verbose 'Amend an existing quota'
    if ($SoftThreshold -and !$SoftGrace) {Write-Host 'ERROR: SoftThreshold requires -SoftGrace to be set' -BackgroundColor Black -ForegroundColor Red; return}
    if ($Detailed){$a=" -v"}else{$a=$null}
    $Command = "isi quota quotas modify `'$Path`' directory$a"
    if ($Container) {Write-Verbose "Adding Container"; $Command += " --container $Container"}
    if ($Snapshots) {Write-Verbose "Adding Snapshots"; $Command += " --include-snapshots $Snapshots"}
    if ($Overhead) {Write-Verbose "Adding Overhead"; $Command += " --thresholds-include-overhead $Overhead"}
    if ($Enforced) {Write-Verbose "Adding Enforced"; $Command += " --enforced $Enforced"}
    if ($HardThreshold) {Write-Verbose "Adding HardThreshold"; $Command += " --hard-threshold $HardThreshold"}
    if ($AdviseThreshold) {Write-Verbose "Adding AdviseThreshold"; $Command += " --advisory-threshold $AdviseThreshold"}
    if ($SoftThreshold) {Write-Verbose "Adding SoftThreshold"; $Command += " --soft-threshold $SoftThreshold"}
    if ($SoftGrace) {Write-Verbose "Adding SoftGrace"; $Command += " --soft-grace $SoftGrace"}
    Write-Verbose "SSH command is: $Command"
    $Result = ([string](Invoke-SshCommand -ComputerName $ClusterName -Quiet -Command $Command).split("`r")).Split("`n")
    Return $Result
}

function Disconnect-IsilonCluster {
    [CmdletBinding()]
    [OutputType([String])]
    Param([Parameter(Mandatory=$true)] [string]$ClusterName)
    Write-Verbose 'Disconnect from the Cluster'
    $Result = ([string](Remove-SshSession -ComputerName $ClusterName).split("`r")).Split("`n")
    Return $Result
}














################################################################################
## Convert-Delimiter - A function to convert between different delimiters. 
## E.g.: commas to tabs, tabs to spaces, spaces to commas, etc.
##
## This script was published on PoshCode by Joel Bennett
## http://poshcode.org/146
##
## Minor amendments have been made fix a few issues.
################################################################################
## Written primarily as a way of enabling the use of Import-CSV when
## the source file was a columnar text file with data like services.txt:
##         ip              service         port
##         13.13.13.1      http            8000
##         13.13.13.2      https           8001
##         13.13.13.1      irc             6665-6669
## 
## Sample Use:  
##    Get-Content services.txt | Convert-Delimiter " +" "," | Set-Content services.csv
##         would convert the file above into something that could passed to:
##         Import-Csv services.csv
##
##    Get-Content Delimited.csv | Convert-Delimiter "," "`t" | Set-Content Delimited.tab
##         would convert a simple comma-separated-values file to a tab-delimited file
##
Function Convert-Delimiter([regex]$from,[string]$to) 
{ 
   process
   {  
      ## replace the original delimiter with the new one, wrapping EVERY block in Ãž
      ## if there's quotes around some text with a delimiter, assume it doesn't count
      ## if there are two quotes "" stuck together inside quotes, assume they're an 'escaped' quote
      $_ = $_ -replace "(?:`"((?:(?:[^`"]|`"`"))+)(?:`"$from|`"`$))|(?:((?:.(?!$from))*.)(?:$from|`$))","`$1`$2$to" 
      ## clean up the end where there might be duplicates
      $_ = $_ -replace "(?:$to|)?`$",""
      ## normalize quotes so that they're all double "" quotes
      $_ = $_ -replace "`"`"","`"" -replace "`"","`"`"" 
      ## remove the Ãž wrappers if there are no quotes inside them
      $_ = $_ -replace "((?:[^`"](?!$to))+)($to|`$)","`$1`$2"
      ## replace the Ãž with quotes, and explicitly emit the result
      write-output $_ # -replace "","`""
   }
}

################################################################################
## Import-Delimited - A replacement function for Import-Csv that can handle other 
## delimiters, and can import text (and collect it together) from the pipeline!!
## Dependends on the Convert-Delimiter function.
################################################################################
## NOTICE that this means you can use this to import multitple CSV files as one:
## Sample Use:
##        ls ..\*.txt | export-csv textfiles.csv
##        ls *.doc | export-csv docs.csv
##        ls C:\Windows\System32\*.hlp | export-csv helpfiles.csv
##
##       $files = ls *.csv | Import-Delimited
## OR
##     Import-Delimited " +" services1.txt 
## OR
##     gc *.txt | Import-Delimited "  +"
################################################################################
## Version History
## Version 1.0
##    First working version
## Version 2.0
##    Filter #TYPE lines
##    Remove dependency on Convert-Delimiter if the files are already CSV
##    Change to use my Template-Pipeline format (removing the nested Import-String function)
## Version 2.1
##    Fix a stupid bug ...
##    Add filtering for lines starting with "--", hopefully that's not a problem for other people...
##    Added Write-DEBUG output for filtered lines...

Function Import-Delimited([regex]$delimiter=",", [string]$PsPath="")
{
    BEGIN {
        if ($PsPath.Length -gt 0) { 
            write-output ($PsPath | &($MyInvocation.InvocationName) $delimiter); 
        } else {
            $script:tmp = [IO.Path]::GetTempFileName()
            write-debug "Using tempfile $($script:tmp)"
        }
    }
    PROCESS {
        if($_ -and $_.Length -gt 0 ) {
            if(Test-Path $_) {
                if($delimiter -eq ",") {
                    Get-Content $_ | Where-Object {if($_.StartsWith("#TYPE") -or $_.StartsWith("--")){ write-debug "SKIPPING: $_"; $false;} else { $true }} | Add-Content $script:tmp
                } else {
                    Get-Content $_ | Convert-Delimiter $delimiter "," | Where-Object { if( $_.StartsWith("--") ) { write-debug "SKIPPING: $_"; $false;} else { $true }} | Add-Content $script:tmp
                }
            }
            else {
                if($delimiter -eq ",") {
                    $_ | Where-Object {-not $_.StartsWith("#TYPE")} | Add-Content $script:tmp
                } else {
                    $_ | Convert-Delimiter $delimiter "," | Add-Content $script:tmp
                }
            }
        }
    }
    END {
        # Need to guard against running this twice when you pass PsPath
        if ($PsPath.Length -eq 0) {
            Write-Output (Import-Csv $script:tmp)
        }
    }
}