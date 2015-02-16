$ToolName="Quota increase"
$ToolVer="1.0"
$ToolDate="22nd December 2014"
$ToolAuthor="Stephen Fearns"

$Cluster="Isilon"
$ClusterUserID="root"
$ClusterPassword="password"

# Count must be greater than 0
$FreeSpaceWarning=[int]80
$FreeSpaceAlert=[int]90
$FreeSpaceCritical=[int]98
$IncreaseByMB=(1MB*25)
$IncreaseByGB=(1GB*25)
$IncreaseByTB=1TB
$TodaysDate=Get-Date
$ReportFolder='C:\WorkFolder\Reports\'
$HTMLReportFileName=[string](Get-Date -Format yyyyMMdd)+"_"+[string](Get-Date -Format HHmmss)+" - Quota increases for Isilon Cluster ($Cluster).htm"
$Report=$ReportFolder+$ReportFileName
$HTMLReport=$ReportFolder+$HTMLReportFileName
$ReportTitle="Quota increases for Isilon Cluster ($Cluster)"

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

$ifsConnection = Connect-IsilonCluster -ClusterName $Cluster -Username $ClusterUserID -Password $ClusterPassword

if ($ifsConnected -like "Unable to connect to*") {return $ifsConnected}
if ($ifsConnected -like "No SSH session found*") {return $ifsConnected}
$t=Get-IsilonListQuotas -ClusterName $Cluster | Sort-Object Path

ConvertTo-Html -Title "$ReportTitle" -Head "<h1>$ReportTitle<br></h1>This report was created at $TodaysDate<br>$ToolName v$ToolVer by $ToolAuthor" -Body "$Css" | Set-Content -Path $HTMLReport

"<h2>Revised Quotas</h2>" | Add-Content -Path $HTMLReport
"<table>" | Add-Content -Path $HTMLReport
"<colgroup><col/><col/><col/><col/><col/></colgroup>" | Add-Content -Path $HTMLReport
"<tr><th>Path</th><th>Limit</th><th>Used</th><th>Free</th><th>Used %</th></tr>" | Add-Content -Path $HTMLReport
$t | Where-Object type -eq 'directory' | Where-Object Path -notlike "*/DatAnywhere_SharingArea/*" | ForEach-Object{
    $l="TB"; $a=($PSItem.thresholds.hard / 1TB); $b=($PSItem.usage_derived / 1TB)
    if ($PSItem.thresholds.hard -le (1TB-1GB)){$l="GB"; $a=($PSItem.thresholds.hard / 1GB); $b=($PSItem.usage_derived / 1GB)}
    if ($PSItem.thresholds.hard -le (1GB-1MB)){$l="MB"; $a=($PSItem.thresholds.hard / 1MB); $b=($PSItem.usage_derived / 1MB)}
    $d=$a-$b; $e=$b/($a / 100); $c1=$null; $c2=$null
    if ($e-ge$FreeSpaceWarning){$c1=$ColourWarningOn;$c2=$ColourWarningOff}
    if ($e-ge$FreeSpaceAlert){$c1=$ColourAlertOn;$c2=$ColourAlertOff}
    if ($e-ge$FreeSpaceCritical){$c1=$ColourCriticalOn;$c2=$ColourCriticalOff}

    if ($e-ge$FreeSpaceCritical) {
        if ($l-like"MB") {
            $NewHard=($PSItem.thresholds.hard)+$IncreaseByMB
            if ($PSItem.thresholds.soft) {$NewSoft=($PSItem.thresholds.soft)+$IncreaseByMB}
            if ($PSItem.thresholds.adv) {$NewAdv=($PSItem.thresholds.adv)+$IncreaseByMB}
        } elseif ($l-like"GB") {
            $NewHard=($PSItem.thresholds.hard)+$IncreaseByGB
            if ($PSItem.thresholds.soft) {$NewSoft=($PSItem.thresholds.soft)+$IncreaseByGB}
            if ($PSItem.thresholds.adv) {$NewAdv=($PSItem.thresholds.adv)+$IncreaseByGB}
        } elseif ($l-like"TB") {
            $NewHard=($PSItem.thresholds.hard)+$IncreaseByTB
            if ($PSItem.thresholds.soft) {$NewSoft=($PSItem.thresholds.soft)+$IncreaseByTB}
            if ($PSItem.thresholds.adv) {$NewAdv=($PSItem.thresholds.adv)+$IncreaseByTB}
        } else {
            Write-Host "ERROR: Unexpected action" -BackgroundColor Black -ForegroundColor Red
        }

        $l="TB"; $a=($NewHard / 1TB); $b=($PSItem.usage_derived / 1TB)
        if ($NewHard -le (1TB-1GB)){$l="GB"; $a=($NewHard / 1GB); $b=($PSItem.usage_derived / 1GB)}
        if ($NewHard -le (1GB-1MB)){$l="MB"; $a=($NewHard / 1MB); $b=($PSItem.usage_derived / 1MB)}
        $d=$a-$b; $e=$b/($a / 100); $c1=$null; $c2=$null
        if ($e-ge$FreeSpaceWarning){$c1=$ColourWarningOn;$c2=$ColourWarningOff}
        if ($e-ge$FreeSpaceAlert){$c1=$ColourAlertOn;$c2=$ColourAlertOff}
        if ($e-ge$FreeSpaceCritical){$c1=$ColourCriticalOn;$c2=$ColourCriticalOff}

        Set-IsilonQuota -ClusterName $Cluster -Path $PSItem.path -HardThreshold $NewHard
        if ($PSItem.thresholds.soft){Set-IsilonQuota -ClusterName $Cluster -Path $PSItem.path -SoftThreshold $NewSoft -SoftGrace $PSItem.thresholds.soft_grace}
        if ($PSItem.thresholds.adv) {Set-IsilonQuota -ClusterName $Cluster -Path $PSItem.path -AdviseThreshold -$NewAdv}
        "<tr><td>{0}{2}{1}</td><td>{0}{3:N2} {4}{1}</td><td>{0}{5:N2} {4}{1}</td><td>{0}{7:N2} {4}{1}</td><td>{0}{6:N0}%{1}</td></tr>" -f $c1,$c2,$($PSItem.path),$a,$l,$b,$e,$d | Add-Content -Path $HTMLReport
    }
}
"</table>" | Add-Content -Path $HTMLReport

"<h2>Original Quotas</h2>" | Add-Content -Path $HTMLReport
"<table>" | Add-Content -Path $HTMLReport
"<colgroup><col/><col/><col/><col/><col/></colgroup>" | Add-Content -Path $HTMLReport
"<tr><th>Path</th><th>Limit</th><th>Used</th><th>Free</th><th>Used %</th></tr>" | Add-Content -Path $HTMLReport
$t | Where-Object type -eq 'directory' | Where-Object Path -notlike "*/DatAnywhere_SharingArea/*" | ForEach-Object{
    $l="TB"; $a=($PSItem.thresholds.hard / 1TB); $b=($PSItem.usage_derived / 1TB)
    if ($PSItem.thresholds.hard -le (1TB-1GB)){$l="GB"; $a=($PSItem.thresholds.hard / 1GB); $b=($PSItem.usage_derived / 1GB)}
    if ($PSItem.thresholds.hard -le (1GB-1MB)){$l="MB"; $a=($PSItem.thresholds.hard / 1MB); $b=($PSItem.usage_derived / 1MB)}
    $d=$a-$b; $e=$b/($a / 100); $c1=$null; $c2=$null
    if ($e-ge$FreeSpaceWarning){$c1=$ColourWarningOn;$c2=$ColourWarningOff}
    if ($e-ge$FreeSpaceAlert){$c1=$ColourAlertOn;$c2=$ColourAlertOff}
    if ($e-ge$FreeSpaceCritical){$c1=$ColourCriticalOn;$c2=$ColourCriticalOff}
    "<tr><td>{0}{2}{1}</td><td>{0}{3:N2} {4}{1}</td><td>{0}{5:N2} {4}{1}</td><td>{0}{7:N2} {4}{1}</td><td>{0}{6:N0}%{1}</td></tr>" -f $c1,$c2,$($PSItem.path),$a,$l,$b,$e,$d | Add-Content -Path $HTMLReport
}
"</table>" | Add-Content -Path $HTMLReport

$t=(Get-Content $HTMLReport)
Send-MailMessage -SmtpServer $MailServer -Port 25 -From $MailFrom -To $MailTo -Subject $MailSubject -BodyAsHtml "$t<br><br>" -Attachments $HTMLReport
