
function ZYFP()
{
	$VSPHERE_CLIENT=Read-Host "
"---------------------------------------------"
	(1) MEILIN-VC   192.168.156.110
	(2) GUOTONG-VC  192.168.22.221
"---------------------------------------------"
	Please input your vCServer (1/2)"
	
	switch ($VSPHERE_CLIENT)
	{
	1 {Connect-VIServer 192.168.156.110 -User admin -Password ############}
	2 {Connect-VIServer 192.168.22.221 -User admin -Password ############}
	Default{ZYFPLOOP}
	}
}
function ZYFPLOOP()
{
	echo "ERROR  Unavialble Vaule"
	ZYFP
}
function CHECKTEMP(){
	$VSPHERE_TEMP=Read-Host "
"---------------------------------------------"	
	(1) RedHat74
	(2) CentOS74
	(3) RedHat69
	(4) WinServer2012R2
"---------------------------------------------"
	Please input your Template (1/2/3/4)"
	switch ($VSPHERE_TEMP)
	{
	1 {$script:tName = 'RedHat74'}
	2 {$script:tName = 'CentOS74'}
	3 {$script:tName = 'RedHat69'}
	4 {$script:tName = 'WinServer2012R2'}
	Default{CHECKTEMPLOOP}
	}
}
function CHECKTEMPLOOP()
{
	echo "ERROR  Unavialble Vaule"
	CHECKTEMP
}
function GETIPADD()
{
	$IPStart=Read-Host "Please input start ip"
	$IPEnd=Read-Host "Please input end ip"
	$tempipstart=$IPStart -Split "\."
	$tempipend=$IPEnd -Split "\."
	$script:Vlan=$tempipstart[2]
	$script:IPHead=$tempipstart[0]+"."+$tempipstart[1]+"."+$tempipstart[2]
	$script:IPLegstart=$tempipstart[3]
	$script:IPLegend=$tempipend[3]

}
function GETEXSIADD()
{
	$mltest01_exsip=@("192.168.156.122","192.168.156.123","192.168.156.124","192.168.156.125","192.168.156.126","192.168.156.127","192.168.156.128","192.168.156.129","192.168.156.130")
	$mltest02_exsip=@("192.168.156.131","192.168.156.132","192.168.156.133","192.168.156.134","192.168.156.135","192.168.156.136","192.168.156.137","192.168.156.138","192.168.156.139")
	$VSPHERE_CLUSTER=Read-Host "
"---------------------------------------------"	
	(1) TEST01
	(2) TEST02
"---------------------------------------------"
	Please input your Cluster (1/2)"
	switch ($VSPHERE_CLUSTER)
	{
	1 {$script:EXSIP = $mltest01_exsip;$script:DataStore = "TEST01-DataStore"}
	2 {$script:EXSIP = $mltest02_exsip;$script:DataStore = "TEST02-DataStore"}
	Default{CHECKCLUSTERLOOP}
	}
}
	function CHECKCLUSTERLOOP()
{
	echo "ERROR  Unavialble Vaule"
	GETEXSIADD
}
#主程序部分####
ZYFP
CHECKTEMP
GETEXSIADD
GETIPADD
echo $script:IPHead
echo $script:IPLegstart
echo $script:IPLegend
$SpecName="TempSpec"+(Get-Random)
$Vlan="VLAN "+$script:Vlan
$GateWay=$script:IPHead+".1"
$netMask='255.255.255.0'
$dns='192.168.156.114'
echo $Vlan
echo $GateWay
$ipa=[int]$script:IPLegstart
$ipz=[int]$script:IPLegend
$ClusterIp=$script:EXSIP
for ($ipa ;$ipa -le $ipz;$ipa++)
{
	$staticip=$script:IPHead+"."+$ipa	
	$count=Get-Random -Maximum $ClusterIp.length
	$exsinow=$ClusterIp.Split(',')[$count]
    $vmName=$staticip+'-'+$script:tName
	
   if($script:tName -eq "WinServer2012R2"){
      Get-OSCustomizationSpec -name WinDomain | New-OSCustomizationSpec -name $SpecName -Type NonPersistent
      Get-OSCustomizationSpec $SpecName | Get-OSCustomizationNicMapping | Set-OSCustomizationNicMapping -IpMode UseStaticIP -IpAddress $staticip -SubnetMask $netMask -DefaultGateway $GateWay -Dns $dns
   }else{
      Get-OSCustomizationSpec -name LinuxDomain | New-OSCustomizationSpec -name $SpecName -Type NonPersistent
      Get-OSCustomizationSpec $SpecName | Get-OSCustomizationNicMapping | Set-OSCustomizationNicMapping -IpMode UseStaticIP -IpAddress $staticip -SubnetMask $netMask -DefaultGateway $GateWay
   }


	$task = New-VM -Name $vmName -Template $script:tName -VMHost $exsinow -Datastore $script:DataStore -OSCustomizationSpec $SpecName -Location $script:IPHead -Confirm:$false 
	while($task.ExtensionData.Info.State -eq "running")
	{
		sleep 1
		$task.ExtensionData.UpdateViewData('Info.State')
	}

	$task = Start-VM -VM $vmName
	while($task.ExtensionData.Info.State -eq "running")
	{
  		sleep 1
		$task.ExtensionData.UpdateViewData('Info.State')
	}

	$task = Get-NetworkAdapter -VM $vmName | Set-NetworkAdapter -NetworkName $Vlan -Confirm:$false
    while($task.ExtensionData.Info.State -eq "running")
    {
		sleep 1
		$task.ExtensionData.UpdateViewData('Info.State')
    }
         	
	Remove-OSCustomizationSpec -CustomizationSpec $SpecName -Confirm:$false 

}


