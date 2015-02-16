<#
This module will pull information from an Isilon Cluster and produce a daily
report on the state of the system.

Version History:
    v0.1  - Initial Version


Additional Features:
    Output Information as HTML
    Tidy up the report so it's more readable
        Battery Status
        Read/Write Status
    Node Health
    Storage space (Node levels)
    Number of Hosts
    Show installed patches and/or updates
#>

$iCheckName="Isilon Check"
$iCheckVer="0.3"
$iCheckDate="31st December 2014"
$iCheckAuthor="Stephen Fearns"

# Live Environment
$Cluster="Isilon"
$ClusterUserID="root"
$ClusterPassword="password"

# Count must be greater than 0
$MaxSyncErrors=[int]9999
$MaxSyncResults=[int]9999
$MaxResults=[int]10
$FreeSpaceWarning=[int]80
$FreeSpaceAlert=[int]90
$FreeSpaceCritical=[int]95
$TodaysDate=Get-Date
$IgnoreForDays=30
$ReportFolder='C:\WorkFolder\Reports\'
$ReportFileName=[string](Get-Date -Format yyyyMMdd)+"_"+[string](Get-Date -Format HHmmss)+" - iCheck Report for Isilon Cluster ($Cluster).txt"
$HTMLReportFileName=[string](Get-Date -Format yyyyMMdd)+"_"+[string](Get-Date -Format HHmmss)+" - iCheck Report for Isilon Cluster ($Cluster).htm"
$Report=$ReportFolder+$ReportFileName
$HTMLReport=$ReportFolder+$HTMLReportFileName
$LoadReport=$false
$ReportTitle="iCheck Report for Isilon Cluster ($Cluster)"
$SendAsHTML=$true
$DomainController='DC.company.com'
$CourierON='<font face="Courier New, Courier, monospace">'
$CourierOFF='</font>'

# Mail Settings
$MailServer="mailhost"
$MailTo="sfearns@company.com"
$MailCC=""
$MailFrom="sfearns@company.com"
$MailSubject=$ReportTitle+" on "+($TodaysDate).DayOfWeek+" "+($TodaysDate).ToLongDateString()+" at "+($TodaysDate).ToShortTimeString()

# HTML report variables
# Wheat
$CSS='<style>table{margin:auto; width:98%}
              Body{background-color:PapayaWhip; Text-align:Center;}
       tr:hover td{background-color:rgb(150, 150, 220);color:black;}
tr:nth-child(even){background-color:rgb(242, 242, 242);}
                th{background-color:DeepSkyBlue; color:black;}
                td{background-color:Gainsboro; color:Black; Text-align:Center;}
     </style>'
$ColourBlackOn='<font color=Black><b>'
$ColourBlackOff='</b></font>'
$ColourGreenOn='<font color=Green><b>'
$ColourGreenOff='</b></font>'
$ColourWarningOn='<font color=Orange><b>'
$ColourWarningOff='</b></font>'
$ColourAlertOn='<font color=DarkRed><b>'
$ColourAlertOff='</b></font>'
$ColourCriticalOn='<font color=Red><b>'
$ColourCriticalOff='</b></font>'

<#
This section of the report will include the following information:

    Cluster Name
    ifs Version
    Cluster Health
    Number of nodes / health (ToAdd: This whole bit)
    Battery Status (ToAdd: colour codes)
    Firmware versions  (ToAdd: Look for duplicates and highlight)
    Cluster R/O or R/W status  (ToAdd: colour codes)

#>

function OutputStorage {
<#
This section of the report will include the following information:

    Cluster level
        HDD space (Total / Used / Available)
        SSD space (Total / Used / Available)

    Node level
        HDD space (Total / Used / Available)
        SSD space (Total / Used / Available)
#>
#    $Storage=($ifsStatus[2..6])
    $Storage=($ifsStatus[2..6]).Replace(':','').Replace('n/a','0').Replace('%','').Replace('(','').Replace(')','').Replace('HDD','HDD Column3').Replace('SSD','SDD Column5').Replace('Raw','').Replace('VHS Size','VHSSize').Replace('Cluster Storage','ClusterStorage').Replace('<','').Replace('>','') | Convert-Delimiter " +" "," | Set-Content $SFTempFile
    $Temp=Import-Csv $SFTempFile
    Remove-Item -Path $SFTempFile

    $ifsClusterTotalStorageHDD=$Temp[0].HDD
    $ifsClusterTotalStorageHDDUsed=$Temp[2].HDD
    $ifsClusterTotalStorageHDDUsedPer=[int]$Temp[2].Column3
    $ifsClusterTotalStorageHDDAvail=$Temp[3].HDD
    $ifsClusterTotalStorageHDDAvailPer=[int]$Temp[3].Column3
    $c1=$ColourBlackOn
    $c2=$ColourBlackOff
    if ($ifsClusterTotalStorageHDDUsedPer-ge(100-$FreeSpaceWarning)){$c1=$ColourWarningOn;$c2=$ColourWarningOff}
    if ($ifsClusterTotalStorageHDDUsedPer-ge(100-$FreeSpaceAlert)){$c1=$ColourAlertOn;$c2=$ColourAlertOff}
    if ($ifsClusterTotalStorageHDDUsedPer-ge(100-$FreeSpaceCritical)){$c1=$ColourCriticalOn;$c2=$ColourCriticalOff}
    Out-HTML "HDD Total:    $ifsClusterTotalStorageHDD" -PreContent "<h2>Disk Space - overview</h2>" -Path $HTMLReport
#    "`tHDD Total:`t`t{0}" -f $ifsClusterTotalStorageHDD | Out-HTML -Path $HTMLReport
    "Used:    {0}    {1:N0}%" -f $ifsClusterTotalStorageHDDUsed,$ifsClusterTotalStorageHDDUsedPer | Out-HTML -Path $HTMLReport
    "Avail:    {0}{1}    {2:N0}%{3}" -f $c1,$ifsClusterTotalStorageHDDAvail,$ifsClusterTotalStorageHDDAvailPer,$c2 | Out-HTML -Path $HTMLReport

    $ifsClusterTotalStorageHDD=$Temp[0].HDD
    $ifsClusterTotalStorageHDDUsed=$Temp[2].HDD
    $ifsClusterTotalStorageHDDUsedPer=[int]$Temp[2].Column3
    $ifsClusterTotalStorageHDDAvail=$Temp[3].HDD
    $ifsClusterTotalStorageHDDAvailPer=[int]$Temp[3].Column3

    $ifsClusterTotalStorageSSD=$Temp[0].SDD
    if ($ifsClusterTotalStorageSSD -gt 0){
        $ifsClusterTotalStorageSSDUsed=$Temp[2].SDD
        $ifsClusterTotalStorageSSDUsedPer=[int]$Temp[2].Column5.replace('n/a','')
        $ifsClusterTotalStorageSSDAvail=$Temp[3].SDD
        $ifsClusterTotalStorageSSDAvailPer=[int]$Temp[3].Column5.replace('n/a','')
        $c1=$ColourBlackOn
        $c2=$ColourBlackOff
        if ($ifsClusterTotalStorageSSDUsedPer-ge(100-$FreeSpaceWarning)){$c1=$ColourWarningOn;$c2=$ColourWarningOff}
        if ($ifsClusterTotalStorageSSDUsedPer-ge(100-$FreeSpaceAlert)){$c1=$ColourAlertOn;$c2=$ColourAlertOff}
        if ($ifsClusterTotalStorageSSDUsedPer-ge(100-$FreeSpaceCritical)){$c1=$ColourCriticalOn;$c2=$ColourCriticalOff}
    } else {
        $ifsClusterTotalStorageSSDUsed=0
        $ifsClusterTotalStorageSSDUsedPer=0
        $ifsClusterTotalStorageSSDAvail=0
        $ifsClusterTotalStorageSSDAvailPer=0
        $c1=$ColourBlackOn
        $c2=$ColourBlackOff
    }
#    Out-HTML "<br>SSD Disk Space" -Path $HTMLReport
    "<br>SSD Total:    {0}" -f $ifsClusterTotalStorageSSD | Out-HTML -Path $HTMLReport
    "Used:    {0}    {1:N0}%" -f $ifsClusterTotalStorageSSDUsed,$ifsClusterTotalStorageSSDUsedPer | Out-HTML -Path $HTMLReport
    "Avail:    {0}{1}     {2:N0}%{3}" -f $c1,$ifsClusterTotalStorageSSDAvail,$ifsClusterTotalStorageSSDAvailPer,$c2 | Out-HTML -Path $HTMLReport

    for ($i=0;$i-lt$ifsStatus.count;$i++){if ($ifsStatus[$i].Contains('ID |IP Address')) {$NodeStartBlock=$i+2;break}}
    for (;$i-lt$ifsStatus.count;$i++){if ($ifsStatus[$i].Contains('Cluster Totals')) {$NodeEndBlock=$i-1;break}}
    if ($NodeStartBlock -and $NodeEndBlock) {
        $NodeBlock=@{}
        for ($i=$NodeStartBlock;$i-lt$NodeEndBlock;$i++) {
            $NodeBlock[($i-$NodeStartBlock)]=($ifsStatus[$i].Replace(' ','').Replace('(NoHDDs)','0,0,0').Replace('(NoStorageHDDs)','0,0,0').Replace('(NoSSDs)','0,0,0').Replace('(NoStorageSSDs)','0,0,0').Replace('(',',').Replace('%)',''))
        }
        $ifsStatus[($NodeStartBlock-2)].Replace(' ','').Replace('<','').Replace('InOut','In|Out|').Replace('al|Used/Size','al|HDD_Used,HDD_Size,HDD_Percent').Replace('Used/Size','SSD_Used,SSD_Size,SSD_Percent') | Convert-Delimiter '\|' "," | Set-Content $SFTempFile
        ($NodeBlock.Values).Replace('<','') | Convert-Delimiter '\|' "," | Convert-Delimiter '\/' "," | Add-Content $SFTempFile
        $NodeDiskUsage = Import-Csv $SFTempFile
        Remove-Item -Path $SFTempFile
        # Place colours around the DASR data
#        for ($i=0;$i-le$NodeDiskUsage.count;$i++) {
#            $NodeDiskUsage[$i].DASR = ($NodeDiskUsage[$i].DASR).Replace('OK',"$($ColourGreenOn)OK$($ColourGreenOff)").Replace('ATTN',"$($ColourCriticalOn)ATTN$($ColourCriticalOff)")
#        }
#        $NodeDiskUsage.DASR = ($NodeDiskUsage.DASR).Replace('OK',"$($ColourGreenOn)OK$($ColourGreenOff)").Replace('ATTN',"$($ColourCriticalOn)ATTN$($ColourCriticalOff)")
        $NodeDiskUsage | ConvertTo-Html -Fragment -PreContent "<h2>Specific Node Information</h2>" | Add-Content -Path $HTMLReport
    } else {
        Write-Host "Unable to find the Node Block"
    }
}

function OutputJobs {
<#
This section of the report will include the following information:

    Monitor Jobs
#>
    $t = Get-IsilonListJobs -ClusterName $Cluster
    $r=$t | Where-Object state -eq 'running'
    $f=$t | Where-Object state -eq 'failed'
    $p=$t | Where-Object state -match "^paus*"
    if ($r){
        $r | Sort-Object time -Descending | Select-Object type,impact,priority,phase_cur_tot,@{n='running time (hh:mm)';e={(Get-UnixDate($PSItem.running_time)).ToShortTimeString()}} | ConvertTo-Html -Fragment -PreContent "<h2>Running jobs</h2>" | Add-Content -Path $HTMLReport
    } else {
        Out-HTML "No running jobs." -PreContent "<h2>Running Jobs</h2>" -Path $HTMLReport
    }
    if ($p){
        $p | Sort-Object time -Descending | Select-Object type,impact,priority,phase_cur_tot,@{n='running time (hh:mm)';e={(Get-UnixDate($PSItem.running_time)).ToShortTimeString()}} | ConvertTo-Html -Fragment -PreContent "<h2>Paused jobs</h2>" | Add-Content -Path $HTMLReport
    } else {
        Out-HTML "No paused or waiting jobs." -PreContent "<h2>Paused Jobs</h2>" -Path $HTMLReport
    }
    if ($f){
        $f | Sort-Object time -Descending | Select-Object type,impact,priority,phase_cur_tot,@{n='running time (hh:mm)';e={(Get-UnixDate($PSItem.running_time)).ToShortTimeString()}} | ConvertTo-Html -Fragment -PreContent "<h2>Failed jobs</h2>" | Add-Content -Path $HTMLReport
    } else {
        Out-HTML "No failed jobs." -PreContent "<h2>Failed Jobs</h2>" -Path $HTMLReport
    }

    $t = Get-IsilonListJobPolicies -ClusterName $Cluster
    if ($t.count-gt0){
        $t | Sort-Object description | Select-Object description,intervals | ConvertTo-Html -Fragment -PreContent "<h2>Job Policies</h2>" | Add-Content -Path $HTMLReport
    } else {
        Out-HTML "No Job Policies found" -PreContent "<h2>Job Policies</h2>" -Path $HTMLReport
    }
}

function OutputSync {
<#
This section of the report will include the following information:

    Monitor SyncIQ results
    Current SyncIQ policies
#>
    $t=Get-IsilonListSyncJobs -ClusterName $Cluster
    if ($t){
        $t | Sort-Object policy_name | Select-Object -Property policy_name,@{n='start time';e={(Get-UnixDate($PSItem.start_time))}},@{N="source path";E={$PSItem.policy.source_root_path}},@{N="target host";E={$_.policy.target_host}},@{N="target path";E={$_.policy.target_path}} | ConvertTo-Html -Fragment -PreContent "<h2>Active SyncIQ jobs(s)</h2>" | Add-Content -Path $HTMLReport
    } else {
        Out-HTML "No active Jobs found" -PreContent "<h2>Active SyncIQ Jobs</h2>" -Path $HTMLReport
    }

    $t=Get-IsilonListSyncReports -ClusterName $Cluster
    if ($t.count-gt0){
        $Failed=0
        for ($i=0;$i-lt$t.count;$i++){if ($t[$i].State -like 'failed'){$Failed++}}

        # Found a failed Sync report - Display 'x' results
        if (($Failed-gt0)-and($MaxSyncErrors-gt0)){
            $c=0
            $t | Where-Object State -eq "failed" | Sort-Object name | Select-Object -Property @{N="name";E={$PSItem.policy.name}},@{n='start time';e={(Get-UnixDate($PSItem.start_time))}},@{N="source path";E={$PSItem.policy.source_root_path}},@{N="target host";E={$_.policy.target_host}},@{N="target path";E={$_.policy.target_path}} -First $MaxSyncErrors | ConvertTo-Html -Fragment -PreContent "<h2>SyncIQ $Failed FAILED Report(s)</h2>" | Add-Content -Path $HTMLReport
        }

        # Display 'x' results
        if (($t.count-gt$Failed)-and($MaxSyncResults-gt0)){
            $c=0
            $t | Where-Object State -eq "finished" | Sort-Object name | Select-Object -Property @{N="name";E={$PSItem.policy.name}},@{n='start time';e={(Get-UnixDate($PSItem.start_time))}},@{N="source path";E={$PSItem.policy.source_root_path}},@{N="target host";E={$_.policy.target_host}},@{N="target path";E={$_.policy.target_path}} -First $MaxSyncResults | ConvertTo-Html -Fragment -PreContent "<h2>SyncIQ Finished Report(s)</h2>" | Add-Content -Path $HTMLReport
        }
    } else {
        Out-HTML "No SyncIQ Reports found" -PreContent "<h2>SyncIQ reports</h2>" -Path $HTMLReport
    }

    $t = Get-IsilonListSyncPolicies -ClusterName $Cluster
    if ($t.count-gt0){
        $t | Sort-Object name | Select-Object name,@{n='next run';e={(Get-UnixDate($PSItem.next_run))}},source_root_path,target_host,target_path | ConvertTo-Html -Fragment -PreContent "<h2>SyncIQ Policies</h2>" | Add-Content -Path $HTMLReport
    } else {
        Out-HTML "No SyncIQ Policies found" -PreContent "<h2>SyncIQ Policies</h2>" -Path $HTMLReport
    }
}

function OutputQuotas {
<#
This section of the report will include the following information:

    Current Quota List
    Monitor Quotas space and colour code

#>
    $t=Get-IsilonListQuotas -ClusterName $Cluster | Sort-Object Path
#    $t | Sort-Object path | Select-Object -Property path.Replace("/ifs/data/NIMR/","../"),@{N="Limit";E={$PSItem.thresholds.hard}},@{N="Used";E={$_.usage_derived}} -First $MaxSyncErrors | Format-Table -AutoSize | Out-String -Width 4096 | Out-File -FilePath $Report -Append -NoClobber

    "<h2>Directory quota</h2>(excluding DatAnywhere)" | Add-Content -Path $HTMLReport
    "<table>" | Add-Content -Path $HTMLReport
    "<colgroup><col/><col/><col/><col/><col/></colgroup>" | Add-Content -Path $HTMLReport
    "<tr><th>Path</th><th>Limit</th><th>Used</th><th>Free</th><th>Used %</th></tr>" | Add-Content -Path $HTMLReport
    $t | Where-Object type -eq 'directory' | ForEach-Object{
        if ($PSItem.Path -notlike "*/DatAnywhere_SharingArea/*") {
            $l="TB"; $a=($PSItem.thresholds.hard / 1TB); $b=($PSItem.usage_derived / 1TB)
            if ($PSItem.thresholds.hard -le (1TB-1GB)){
                $l="GB"; $a=($PSItem.thresholds.hard / 1GB); $b=($PSItem.usage_derived / 1GB)
            }
            if ($PSItem.thresholds.hard -le (1GB-1MB)){
                $l="MB"; $a=($PSItem.thresholds.hard / 1MB); $b=($PSItem.usage_derived / 1MB)
            }
            $d=$a-$b
            $e=$b/($a / 100)
            $c1=$null
            $c2=$null
            if ($e-ge$FreeSpaceWarning){$c1=$ColourWarningOn;$c2=$ColourWarningOff}
            if ($e-ge$FreeSpaceAlert){$c1=$ColourAlertOn;$c2=$ColourAlertOff}
            if ($e-ge$FreeSpaceCritical){$c1=$ColourCriticalOn;$c2=$ColourCriticalOff}
            "<tr><td>{0}{2}{1}</td><td>{0}{3:N2} {4}{1}</td><td>{0}{5:N2} {4}{1}</td><td>{0}{7:N2} {4}{1}</td><td>{0}{6:N0}%{1}</td></tr>" -f $c1,$c2,$($PSItem.path),$a,$l,$b,$e,$d | Add-Content -Path $HTMLReport
        }
    }
    "</table>" | Add-Content -Path $HTMLReport

    "<h2>Directory quotas</h2>(DatAnywhere)" | Add-Content -Path $HTMLReport
    "<table>" | Add-Content -Path $HTMLReport
    "<colgroup><col/><col/><col/><col/><col/></colgroup>" | Add-Content -Path $HTMLReport
    "<tr><th>Path</th><th>Limit</th><th>Used</th><th>Free</th><th>Used %</th></tr>" | Add-Content -Path $HTMLReport
    $t | Where-Object type -eq 'directory' | ForEach-Object{
        if ($PSItem.Path -like "*/DatAnywhere_SharingArea/*") {
            $l="TB"; $a=($PSItem.thresholds.hard / 1TB); $b=($PSItem.usage_derived / 1TB)
            if ($PSItem.thresholds.hard -le (1TB-1GB)){
                $l="GB"; $a=($PSItem.thresholds.hard / 1GB); $b=($PSItem.usage_derived / 1GB)
            }
            if ($PSItem.thresholds.hard -le (1GB-1MB)){
                $l="MB"; $a=($PSItem.thresholds.hard / 1MB); $b=($PSItem.usage_derived / 1MB)
            }
            $d=$a-$b
            $e=$b/($a / 100)
            $c1=$null
            $c2=$null
            if ($e-ge$FreeSpaceWarning){$c1=$ColourWarningOn;$c2=$ColourWarningOff}
            if ($e-ge$FreeSpaceAlert){$c1=$ColourAlertOn;$c2=$ColourAlertOff}
            if ($e-ge$FreeSpaceCritical){$c1=$ColourCriticalOn;$c2=$ColourCriticalOff}
            "<tr><td>{0}{2}{1}</td><td>{0}{3:N2} {4}{1}</td><td>{0}{5:N2} {4}{1}</td><td>{0}{7:N2} {4}{1}</td><td>{0}{6:N0}%{1}</td></tr>" -f $c1,$c2,$($PSItem.path),$a,$l,$b,$e,$d | Add-Content -Path $HTMLReport
        }
    }
    "</table>" | Add-Content -Path $HTMLReport

    "<h2>User quotas</h2>" | Add-Content -Path $HTMLReport
    "<table>" | Add-Content -Path $HTMLReport
    "<colgroup><col/><col/><col/><col/><col/></colgroup>" | Add-Content -Path $HTMLReport
    "<tr><th>User</th><th>Path</th><th>Used</th></tr>" | Add-Content -Path $HTMLReport
    $t | Where-Object type -eq 'user' | Sort-Object appliesto,path | ForEach-Object{
        $Size="TB"; $Usage=($PSItem.usage_derived / 1TB)
        if ($PSItem.usage_derived -le (1TB-1GB)){
            $Size="GB"; $Usage=($PSItem.usage_derived / 1GB)
        }
        if ($PSItem.usage_derived -le (1GB-1MB)){
            $Size="MB"; $Usage=($PSItem.usage_derived / 1MB)
        }
        $Path=$PSItem.path
        $User=$PSItem.appliesto
        Write-Progress -Activity "Searching for Disabled AD accounts" -CurrentOperation $User
        if ($ADUsers) {
            $ADUserID=$ADUsers | Where-Object SamAccountName -eq $User.Replace('ADDOMAIN\','')
            if ($?) {
                if (($ADUserID.AccountExpirationDate -and 
                    ($ADUserID.AccountExpirationDate -lt $TodaysDate.AddDays(0-$IgnoreForDays))) -or 
                    !$ADUserID.Enabled) {
                    $c1=$ColourCriticalOn
                    $c2=$ColourCriticalOff
                } else {
                    $c1=$null
                    $c2=$null
                }
            }
        } else {
            $c1=$null
            $c2=$null
        }
        "<tr><td>{4}{0}{5}</td><td>{1}</td><td>{2:N2} {3}</td></tr>" -f $User,$Path,$Usage,$Size,$c1,$c2 | Add-Content -Path $HTMLReport
    }
    "</table>" | Add-Content -Path $HTMLReport
}

function Out-HTML {
param([Parameter(Mandatory=$false,ValueFromPipeline=$true)]  [string[]]$Text=$null,
      [Parameter(Mandatory=$false,ValueFromPipeline=$false)] [string]$PreContent=$null,
      [Parameter(Mandatory=$false,ValueFromPipeline=$false)] [string]$Path=$null)
    $Result=$null
    if ($PreContent) {$Result=$PreContent}
    if ($Text) {for ($i=0;$i-lt$Text.Count;$i++) {$Result+=$Text[$i]+'<br>'}}
    if ($Path -and ($PreContent -or $Text)) {$Result | Add-Content -Path $Path;return}
    return $Result
}

# Connect to the Isilon Cluster
$ifsConnection = Connect-IsilonCluster -ClusterName $Cluster -Username $ClusterUserID -Password $ClusterPassword

if ($ifsConnected -like "Unable to connect to*") {return $ifsConnected}
if ($ifsConnected -like "No SSH session found*") {return $ifsConnected}

if (!$LoginCreds) {$LoginCreds=Get-Credential -Message 'Domain Details'}
Write-Output "Gathering AD information"
try {$ADUsers=Get-ADUser -Filter * -Properties * -Server $DomainController -Credential $LoginCreds -ErrorAction SilentlyContinue}
catch {Write-Host "Not able to connect to $DomainController"}

$ifsStatus=Get-IsilonStatus -ClusterName $Cluster

<#
 Produce the Report

 Sections of the report are:
    General
        oneFS version
        System Health
    Overall Disk usage
    Disk usage (df -i)
    Node disk usage breakdown
    List jobs
    List Quotas
    List SyncIQ
        Failed reports
        Finished reports
    List Events
    List Snapshots
        Expiring - Scheduled
        Expiring - Ad-Hoc
        Persistant
    Patches

    System Configuration
        Firmware version info
        Node Read/Write status
        License info
        Battery info
        SMB shares
        NFS shares
        List job policies
        SyncIQ policies
#>
ConvertTo-Html -Title "$ReportTitle" -Head "<h1>$ReportTitle<br></h1><br>This report was created at $(Get-Date)<br>$iCheckName v$iCheckVer by $iCheckAuthor" -Body "$Css" | Set-Content -Path $HTMLReport

# Out-HTML $ifsStatus -PreContent "<h2>raw 'isi status' output</h2>" -Path $HTMLReport
Out-HTML "Cluster: $(($ifsStatus[0].Split())[2])  ($(((Get-IsilonVersion -ClusterName $Cluster).split())[2]))" -PreContent "<h2>Cluster Details</h2>" -Path $HTMLReport

if($ifsStatus[1]-like"*OK*"){$ClusterHealth=$ColourGreenOn+"OK"+$ColourGreenOff}
if($ifsStatus[1]-like"*ATTN*"){$ClusterHealth=$ColourWarningOn+"ATTN"+$ColourWarningOff}
if($ifsStatus[1]-like"*DOWN*"){$ClusterHealth=$ColourCriticalOn+"ATTN"+$ColourCriticalOff}

Out-HTML "Cluster Health: $ClusterHealth" -PreContent "<h2>Cluster Health</h2>" -Path $HTMLReport

OutputStorage

$t=Get-IsilonSystemIdentification -ClusterName $Cluster
if ($t) {
    if ($t.GetType().BaseType.Name-like"array"){
        $t | ConvertTo-Html -Fragment -PreContent "<h2>System Identification</h2>" | Add-Content -Path $HTMLReport
    } else {
        $t | Out-HTML -PreContent "<h2>System Identification</h2>" -Path $HTMLReport
    }
}
Get-IsilonNodeTime -ClusterName $Cluster | Sort-Object DateTime | ConvertTo-Html -Fragment -PreContent "<h2>Node Times</h2>" | Add-Content -Path $HTMLReport
$t=Get-IsilonAppliedPatches -ClusterName $Cluster;  Out-HTML -Text $t -PreContent "<h2>Patches</h2>" -Path $HTMLReport
$t=Get-IsilonBatteryStatus -ClusterName $Cluster
if ($t) {
    if ($t.GetType().BaseType.Name-like"array"){
        $t | ConvertTo-Html -Fragment -PreContent "<h2>Battery Status</h2>" | Add-Content -Path $HTMLReport
    } else {
        $t | Out-HTML -PreContent "<h2>Battery Status</h2>" -Path $HTMLReport
    }
}

$t=Get-IsilonDiskUsage -ClusterName $Cluster
For ($i=0;$i-lt$t.count;$i++){
    $l="TB"; $Div=1GB
    if ([long]($t[$i].K_blocks) -lt 1GB){$l="GB"; $Div=1MB}
    if ([long]($t[$i].K_blocks) -lt 1MB){$l="MB"; $Div=1KB}
    if ([long]($t[$i].K_blocks) -lt 1KB){$l="KB"; $Div=1}
    $t[$i].K_blocks="{0:N2} {1}" -f ($t[$i].K_blocks / $Div),$l
    $t[$i].Avail="{0:N2} {1}" -f ($t[$i].Avail / $Div),$l
    $t[$i].Used="{0:N2} {1}" -f ($t[$i].Used / $Div),$l
    $t[$i].iused="{0:N2} {1}" -f ($t[$i].iused / $Div),$l
    $t[$i].ifree="{0:N2} {1}" -f ($t[$i].ifree / $Div),$l
}
$t | ConvertTo-Html -Fragment -PreContent "<h2>Isilon Disk usage</h2>" | Add-Content -Path $HTMLReport

$t=Get-IsilonFirmwareStatus -ClusterName $Cluster
if ($t) {
    if ($t.GetType().BaseType.Name-like"array"){
        $t | ConvertTo-Html -Fragment -PreContent "<h2>Firmware Versions</h2>" | Add-Content -Path $HTMLReport
    } else {
        $t | Out-HTML -PreContent "<h2>Firmware Versions</h2>" -Path $HTMLReport
    }
}
Get-IsilonReadWriteStatus -ClusterName $Cluster | ConvertTo-Html -Fragment -PreContent "<h2>ReadWrite Status</h2>" | Add-Content -Path $HTMLReport
Get-IsilonListSMBShares -ClusterName $Cluster | Sort-Object name | Select-Object name,path | ConvertTo-Html -Fragment -PreContent "<h2>SMB Shares</h2>" | Add-Content -Path $HTMLReport
Get-IsilonListNFSShares -ClusterName $Cluster | Sort-Object id | Select-Object id,description,paths | ConvertTo-Html -Fragment -PreContent "<h2>NFS Shares</h2>" | Add-Content -Path $HTMLReport

$t=Get-IsilonListSnapshots -ClusterName $Cluster
if ($t){
    $t | Where-Object expires -ne $null | Where-Object schedule -ne $null | Sort-Object expires | Select-Object -Property name,@{n='created';e={(Get-UnixDate($PSItem.created))}},@{n='expires';e={(Get-UnixDate($PSItem.expires))}},state,path | ConvertTo-Html -Fragment -PreContent "<h2>Expiring - Scheduled SnapShots</h2>" | Add-Content -Path $HTMLReport
    $t | Where-Object expires -ne $null | Where-Object schedule -eq $null | Sort-Object expires | Select-Object -Property name,@{n='created';e={(Get-UnixDate($PSItem.created))}},@{n='expires';e={(Get-UnixDate($PSItem.expires))}},state,path | ConvertTo-Html -Fragment -PreContent "<h2>Expiring - Other SnapShots</h2>" | Add-Content -Path $HTMLReport
    $t | Where-Object expires -eq $null | Sort-Object expires | Select-Object -Property name,@{n='created';e={(Get-UnixDate($PSItem.created))}},@{n='expires';e={(Get-UnixDate($PSItem.expires))}},state,path | ConvertTo-Html -Fragment -PreContent "<h2>Persistant - SnapShots</h2>" | Add-Content -Path $HTMLReport
} else {
    Out-HTML "None found" -PreContent "<h2>SnapShots</h2>" -Path $HTMLReport
}

$t = Get-IsilonListEvents -ClusterName $Cluster
if ($t.count-gt0){
    $t | ConvertTo-Html -Fragment -PreContent "<h2>System Events</h2>" | Add-Content -Path $HTMLReport
} else {
    Out-HTML "No Events found" -PreContent "<h2>System Events</h2>" -Path $HTMLReport
}

Get-IsilonLicenseStatus -ClusterName $Cluster | Sort-Object LicenseStatus,Module | ConvertTo-Html -Fragment -PreContent "<h2>System Licenses</h2>" | Add-Content -Path $HTMLReport

OutputJobs
OutputSync
OutputQuotas

# Get-IsilonUptime -ClusterName $Cluster | ConvertTo-Html -Fragment -PreContent "<h2>Cluster Uptime</h2>" | Add-Content -Path $HTMLReport
Out-HTML "<h2>Cluster Uptime</h2>" -Path $HTMLReport
Out-HTML -PreContent "$CourierON" -Path $HTMLReport
Get-IsilonUptime -ClusterName $Cluster | ForEach-Object {Out-HTML $_ -Path $HTMLReport}
Out-HTML -PreContent "$CourierOFF" -Path $HTMLReport
Get-IsilonNICs -Cluster $Cluster | ConvertTo-Html -Fragment -PreContent "<h2>Network Interfaces</h2>" | Add-Content -Path $HTMLReport
Get-IsilonSubnets -Cluster $Cluster | ConvertTo-Html -Fragment -PreContent "<h2>Network Subnets</h2>" | Add-Content -Path $HTMLReport
Out-HTML "<h2>Network Pools</h2>" -Path $HTMLReport
Out-HTML -PreContent "$CourierON" -Path $HTMLReport
Get-IsilonPools -Cluster $Cluster | ForEach-Object {Out-HTML $_ -Path $HTMLReport}
Out-HTML -PreContent "$CourierOFF" -Path $HTMLReport
# Get-IsilonPools -Cluster $Cluster | ConvertTo-Html -Fragment -PreContent "<h2>Network Pools</h2>" | Add-Content -Path $HTMLReport
Get-IsilonRules -Cluster $Cluster | ConvertTo-Html -Fragment -PreContent "<h2>Network Rules</h2>" | Add-Content -Path $HTMLReport

$ifsConnection = Disconnect-IsilonCluster -ClusterName $Cluster

if ($MailServer -and $MailFrom -and $MailTo){
    if ($SendAsHTML) {
        $t=(Get-Content $HTMLReport)
        if ($MailCC){
            Send-MailMessage -SmtpServer $MailServer -Port 25 -From $MailFrom -To $MailTo -CC $MailCC -Subject $MailSubject -BodyAsHtml "$t<br><br>" -Attachments $HTMLReport
        } else {
            Send-MailMessage -SmtpServer $MailServer -Port 25 -From $MailFrom -To $MailTo -Subject $MailSubject -BodyAsHtml "$t<br><br>" -Attachments $HTMLReport
        }
    } else {
        if ($MailCC){
            Send-MailMessage -SmtpServer $MailServer -Port 25 -From $MailFrom -To $MailTo -CC $MailCC -Subject $MailSubject -Body "Please find attached the report.`n" -Attachments $HTMLReport
        } else {
            Send-MailMessage -SmtpServer $MailServer -Port 25 -From $MailFrom -To $MailTo -Subject $MailSubject -Body "Please find attached the report.`n" -Attachments $HTMLReport
        }
    }
}

If ($LoadReport-eq$true) {Invoke-Item -Path $HTMLReport}
