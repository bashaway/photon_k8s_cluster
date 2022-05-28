# get path info
$path_script = Split-Path  $MyInvocation.MyCommand.Path

# read config file
$ini_file = "$path_script/config.ps1"
. "$ini_file"

# set photon os image file
$photon_image="${path_script}/photon.ova"
if(!(Test-Path $photon_image)){
    echo ""
    echo "##################################"
    echo "# IMAGE FILE ERROR "
    echo "##################################"
    echo "Image Not Found , Please download PhotonOS from Github"
    echo "https://github.com/vmware/photon/wiki/Downloading-Photon-OS"
    echo ""
    echo "curl -L https://packages.vmware.com/photon/4.0/Rev1/ova/photon-ova-4.0-ca7c9e9330.ova -o esxi_photon_deployer/photon.ova"
    echo "curl -L https://packages.vmware.com/photon/4.0/Rev2/ova/photon-ova-4.0-c001795b80.ova -o esxi_photon_deployer/photon.ova"
    echo ""
    exit
}

# set hostnames
$hosts = @()
foreach($num in 1..$num_guests){
  $chk = "{0:D2}" -f $num
  $hosts += "$host_prefix$chk"
}


# get esxi login info
$esxi_host =  Read-Host -Prompt "ESXi server name or address "
$esxi_user =  Read-Host -Prompt "ESXi server login username  "
$esxi_pwd_secure =  Read-Host -Prompt "ESXi $esxi_user password " -AsSecureString
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($esxi_pwd_secure)
$esxi_pwd = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($BSTR)
[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)

# connect esxi host
Write-Host Connecting ESXi host...
$connect = Connect-VIServer -Server $esxi_host -User $esxi_user -Password $esxi_pwd -Force

if( !($connect) ){
  Write-Host ESXi connection error.
  exit
}

# get all guest machine
$current_guests = (Get-VM).Name


Write-Host "`n#################################"
Write-Host "# deploy photon os guest machine"
Write-Host "#################################"

$results = @()
foreach ( $hostname in $hosts ) {
  if( $current_guests.Contains($hostname) ){
    Write-Host $hostname : skip deploy.
  }else{
    Write-Host $hostname : now deploying...
    $results += $hostname
    ovftool --noSSLVerify -q --acceptAllEulas -dm=thin --powerOn --net:None="${port_group}" -ds="$datastore" --name=$hostname --numberOfCpus:"$hostname"=$cpu --memorySize:"$hostname"=$memory $photon_image vi://${esxi_user}:${esxi_pwd}@${esxi_host}/ > /dev/null
  }
}

Write-Host "`n#################################"
Write-Host "# configure guest machine"
Write-Host "#################################"

foreach ( $hostname in $hosts ) {

  $pos_address = ""
  while( !($pos_address ) ){
    $pos_address = (Get-VMGuest $hostname).IPAddress[0] | Select-String -Pattern $address_prefix 
    Start-Sleep -s 1
  }
  
  if( "$pos_address" -ne "$address_prefix$new_host_address"){
    Write-Host $hostname : now configuring...
    $args = "$hostname $pos_address $address_prefix$new_host_address $address_gw $address_dns $domain_name"
    $cmd  = "${path_script}/setup.sh $args"
    Invoke-Expression $cmd
  }else{
    Write-Host $hostname : skip configuration.
  }

  $new_host_address += 1
}

$str_hosts = ""
foreach($num in 0..($num_guests-1)){
  $hostname = $hosts[$num]

  switch ( $num )
  {
    0 { $str_hosts += "[master]`n" }
    1 { $str_hosts += "`n[worker]`n" }
  }

  $str_hosts += "$hostname`.$domain_name ansible_python_interpreter=/usr/bin/python3`n"
}

$file_hosts = (Split-Path -Parent $path_script)+"/hosts.ini"

$str_hosts | Set-Content $file_hosts

Write-Host "`n#################################"
Write-Host "# output hosts.ini file"
Write-Host "#################################"
$str_hosts
