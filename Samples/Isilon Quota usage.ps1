$ToolName="Quota Usage"
$ToolVer="1.0"
$ToolDate="22nd January 2015"
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
$IgnoreForDays=30
$ReportFolder='C:\WorkFolder\Reports\'
$HTMLReportFileName=[string](Get-Date -Format yyyyMMdd)+"_"+[string](Get-Date -Format HHmmss)+" - Quota Usage for Isilon Cluster ($Cluster).htm"
$Report=$ReportFolder+$ReportFileName
$HTMLReport=$ReportFolder+$HTMLReportFileName
$ReportTitle="Quota Usage for Isilon Cluster ($Cluster)"

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
if (!$LoginCreds) {$LoginCreds=Get-Credential}

Write-Output "Gathering AD information"
$ADUsers=Get-ADUser -Filter * -Properties * -Server DC -Credential $LoginCreds -ErrorAction SilentlyContinue
$t=Get-IsilonListQuotas -ClusterName $Cluster | Sort-Object Path

ConvertTo-Html -Title "$ReportTitle" -Head "<h1>$ReportTitle<br></h1><br>This report was created at $TodaysDate<br>$ToolName v$ToolVer by $ToolAuthor" -Body "$Css" | Set-Content -Path $HTMLReport

"<h2>Directory quotas</h2>(excluding DatAnywhere)" | Add-Content -Path $HTMLReport
"<table>" | Add-Content -Path $HTMLReport
"<colgroup><col/><col/><col/><col/><col/></colgroup>" | Add-Content -Path $HTMLReport
"<tr><th>Path</th><th>Limit</th><th>Used</th><th>Free</th><th>Used %</th></tr>" | Add-Content -Path $HTMLReport
$t | Where-Object type -eq 'directory' | Where-Object Path -notlike "*/DatAnywhere_SharingArea/*" | ForEach-Object{
    $l="TB"; $a=($PSItem.thresholds.hard / 1TB); $b=($PSItem.usage_derived / 1TB)
    if ($PSItem.thresholds.hard -le (1TB-1GB)){$l="GB"; $a=($PSItem.thresholds.hard / 1GB); $b=($PSItem.usage_derived / 1GB)}
    if ($PSItem.thresholds.hard -le (1GB-1MB)){$l="MB"; $a=($PSItem.thresholds.hard / 1MB); $b=($PSItem.usage_derived / 1MB)}
    $d=$a-$b
    $e=$b/($a / 100)
    $c1=$null
    $c2=$null
    if ($e-ge$FreeSpaceWarning){$c1=$ColourWarningOn;$c2=$ColourWarningOff}
    if ($e-ge$FreeSpaceAlert){$c1=$ColourAlertOn;$c2=$ColourAlertOff}
    if ($e-ge$FreeSpaceCritical){$c1=$ColourCriticalOn;$c2=$ColourCriticalOff}
    "<tr><td>{0}{2}{1}</td><td>{0}{3:N2} {4}{1}</td><td>{0}{5:N2} {4}{1}</td><td>{0}{7:N2} {4}{1}</td><td>{0}{6:N0}%{1}</td></tr>" -f $c1,$c2,$($PSItem.path),$a,$l,$b,$e,$d | Add-Content -Path $HTMLReport
}
"</table>" | Add-Content -Path $HTMLReport

"<h2>Directory quotas</h2>(DatAnywhere)" | Add-Content -Path $HTMLReport
"<table>" | Add-Content -Path $HTMLReport
"<colgroup><col/><col/><col/><col/><col/></colgroup>" | Add-Content -Path $HTMLReport
"<tr><th>Path</th><th>Limit</th><th>Used</th><th>Free</th><th>Used %</th></tr>" | Add-Content -Path $HTMLReport
$t | Where-Object type -eq 'directory' | Where-Object Path -like "*/DatAnywhere_SharingArea/*" | ForEach-Object{
    $l="TB"; $a=($PSItem.thresholds.hard / 1TB); $b=($PSItem.usage_derived / 1TB)
    if ($PSItem.thresholds.hard -le (1TB-1GB)){$l="GB"; $a=($PSItem.thresholds.hard / 1GB); $b=($PSItem.usage_derived / 1GB)}
    if ($PSItem.thresholds.hard -le (1GB-1MB)){$l="MB"; $a=($PSItem.thresholds.hard / 1MB); $b=($PSItem.usage_derived / 1MB)}
    $d=$a-$b
    $e=$b/($a / 100)
    $c1=$null
    $c2=$null
    if ($e-ge$FreeSpaceWarning){$c1=$ColourWarningOn;$c2=$ColourWarningOff}
    if ($e-ge$FreeSpaceAlert){$c1=$ColourAlertOn;$c2=$ColourAlertOff}
    if ($e-ge$FreeSpaceCritical){$c1=$ColourCriticalOn;$c2=$ColourCriticalOff}
    "<tr><td>{0}{2}{1}</td><td>{0}{3:N2} {4}{1}</td><td>{0}{5:N2} {4}{1}</td><td>{0}{7:N2} {4}{1}</td><td>{0}{6:N0}%{1}</td></tr>" -f $c1,$c2,$($PSItem.path),$a,$l,$b,$e,$d | Add-Content -Path $HTMLReport
}
"</table>" | Add-Content -Path $HTMLReport

"<h2>User quotas</h2>" | Add-Content -Path $HTMLReport
"<table>" | Add-Content -Path $HTMLReport
"<colgroup><col/><col/><col/><col/><col/></colgroup>" | Add-Content -Path $HTMLReport
"<tr><th>User</th><th>Path</th><th>Used</th></tr>" | Add-Content -Path $HTMLReport
$t | Where-Object type -eq 'user' | Sort-Object path,appliesto | ForEach-Object{
    $Size="TB"; $Usage=($PSItem.usage_derived / 1TB)
    if ($PSItem.usage_derived -le (1TB-1GB)){
        $Size="GB"; $Usage=($PSItem.usage_derived / 1GB)
    }
    if ($PSItem.usage_derived -le (1GB-1MB)){
        $Size="MB"; $Usage=($PSItem.usage_derived / 1MB)
    }
    $Path=$PSItem.path
    $User=$PSItem.appliesto
    if ($ADUsers) {
        Write-Progress -Activity "Searching for Disabled AD accounts" -CurrentOperation $User
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
    }

    "<tr><td>{4}{0}{5}</td><td>{1}</td><td>{2:N2} {3}</td></tr>" -f $User,$Path,$Usage,$Size,$c1,$c2 | Add-Content -Path $HTMLReport
}
"</table>" | Add-Content -Path $HTMLReport

$t=(Get-Content $HTMLReport)
Send-MailMessage -SmtpServer $MailServer -Port 25 -From $MailFrom -To $MailTo -Subject $MailSubject -BodyAsHtml "$t<br><br>" -Attachments $HTMLReport
