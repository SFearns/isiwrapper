$Cluster="Isilon"
$ClusterUserID="root"
$ClusterPassword="password"

$ttConnected=$null
$ifsStatus=$null

if (!$ttConnected) {$ttConnected=Connect-IsilonCluster -ClusterName $Cluster -Username $ClusterUserID -Password $ClusterPassword}

Set-IsilonSyncTimeWithDomain -ClusterName $Cluster -Domain ADDOMAIN
