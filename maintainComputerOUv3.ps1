############################################################################
# Modification History	:
# 				08/05/2020 - v1.0 - * Initial Version
# 						 
#
############################################################################


<#
.NOTES
Author   : Bobby Boone
Copyright: Aflac Inc., All Rights reserved.
#>


function main
{

  

$homedir = "\maintainOU"
cd $homedir

#maintainComputerOU.ps1
#use the data from the linux automation server, I used some unix commands, and so need to make mods before I can run it all on Windows
#aws.exe s3 cp s3://imagebuilder555/metadata/acct-name-ip.txt acct-name-ip.txt


# create an array of all machines in the computer OU
# 1st see if it resolves in DNS, since AD maintains DNS, not in DNS, does not exist
# Next get IP if it does exist, then lookup in the ec2.txt file produced by a python script, listInstancesBuckets2.py (buckets part commmented out)   
$array = Get-ADComputer -Filter * -SearchBase "OU=computers, OU=aflawsnonprod,DC=aws,DC=nonprod,DC=aflac,DC=com"  | Select-Object Name 
' Just ran ' | Out-File -FilePath c:\$homedir\Justran.txt
# a less than elegent way to determine if the array comes back NULL
if ($array.Name.Length -gt 0){
'objects found in the computers OU, processing....'
#aws.exe s3 cp s3://imagebuilder555/metadata/acct-name-ip.txt acct-name-ip.txt
# Run the python script to get EC2 metadata, and then wait 1 min for it to complete (less than elegent I admit)
# this only runs if an instance is in the computers account
#& C:\Python27\python.exe c:\$homedir\list-ec2-name-account-ip.py 
#Start-Sleep -s 60

$arglist = "c:\$homedir\list-ec2-name-account-ip.py"
Start-Process -NoNewWindow -Wait -FilePath "C:\Python27\python.exe" -ArgumentList $arglist
#Start-Sleep -s 60         



foreach ($element in $array) {

    $ips = "NULL"

   'looking for '+$element[0].Name.ToString()
    $host2= $element[0].Name.ToString()
    $host2
     #$elstring
     #$elstring = $elstring+ ".aws.nonprod.aflac.com"
     $ips = [System.Net.Dns]::GetHostAddresses($element[0].Name.ToString())


     if ($ips -ne "NULL") {
        # adding dashes so that we don't get a hit on a substring
        $ipaddr= '-'+$ips[0].IPAddressToString+'-'
       # "looking for IP="+$ipaddr
       # most of the time [0] is the IPv4 addr, but sometimes it's IPv6, so we need to check
        if ($ipaddr.IndexOf(':') -gt 1) { $ipaddr = '-'+$ips[1].IPAddressToString+'-'}
        
        # looking up in the file that only contains 4 columns
        if ((Get-Content acct-name-ip.txt | %{$_ -match $ipaddr}) -contains $true) {   
           $aws_meta = Get-Content acct-name-ip.txt | Where-Object { $_.Contains($ipaddr) }         
           $element[0].Name.ToString()+' found in aws '+ $ipaddr
           $allinfo= Get-Content acct-name-ip.txt |Where-Object {$_ -match $ipaddr} 
           # split out the fields and get the instanceID
           #Split fields into values, get instance ID
           $awsmetaarray = $aws_meta -split (",")
           $instanceID = $awsmetaarray[3]

           #update AD with EC2 metadata
           Set-ADComputer $host2 -Description $allinfo

         
          #strip out the dashes so we can pass the ip to checkSubnet
          $ipaddr = $ipaddr -replace '-',''
          #initalize OU variable  
          $OU=''
          # These are the CIDRs for the accounts we care about 
          If((checkSubnet $ipaddr '10.45.12.0/23').Condition) {$OU='GI'}
          If((checkSubnet $ipaddr '10.45.14.0/23').Condition) {$OU='GI'}
          If((checkSubnet $ipaddr '10.45.16.0/23').Condition) {$OU='GI'} 
          If((checkSubnet $ipaddr '10.45.22.0/23').Condition) {$OU='GSS'}
   
          $OU
         # Run the runonce script
        
         #aws ssm send-command --document-name "AWS-RunPowerShellScript" --parameters commands=["c:\download\runonce.bat"] --targets "Key=instanceids,Values=i-051b4c6dbf4827033"
         # I eventually gave up and am calling a very small python boto3 script 
         #& C:\Python27\python.exe c:\$homedir\runcommand.py $instanceID
         # & C:\Python27\python.exe runcommand.py $instanceID
         $arglist = "c:\$homedir\runcommand.py "+$instanceID
         $instanceID
         Start-Process -NoNewWindow -FilePath "C:\Python27\python.exe" -ArgumentList $arglist
         

          $targetpath = "OU=$OU"+",OU=Development,OU=Servers, OU=aflawsnonprod,DC=aws,DC=nonprod,DC=aflac,DC=com"

          #If account is not in the list above, just put it in the Development OU          
          if ($OU -eq '') { $targetpath = "OU=Development,OU=Servers, OU=aflawsnonprod,DC=aws,DC=nonprod,DC=aflac,DC=com"} 
          $targetpath
          Move-ADObject -Identity "CN=$host2, OU=computers, OU=aflawsnonprod,DC=aws,DC=nonprod,DC=aflac,DC=com"   -TargetPath $targetpath 
          
           } 

         else {
           $element[0].Name.ToString()+'-- NOT found in aws'+ $ipaddr
           # move to OU notfound to be deleted later
           $targetpath =  "OU=NotFound, OU=Servers, OU=aflawsnonprod,DC=aws,DC=nonprod,DC=aflac,DC=com"  
           Move-ADObject -Identity "CN=$host2, OU=computers, OU=aflawsnonprod,DC=aws,DC=nonprod,DC=aflac,DC=com"  -TargetPath $targetpath


           }
        }
      else {
         '--not found in dns--'
         # move to OU notfound to be deleted later
         $targetpath =  "OU=NotFound, OU=Servers, OU=aflawsnonprod,DC=aws,DC=nonprod,DC=aflac,DC=com"  
         Move-ADObject -Identity "CN=$host2, OU=computers, OU=aflawsnonprod,DC=aws,DC=nonprod,DC=aflac,DC=com"  -TargetPath $targetpath

        }
}
}
}


# ref: http://www.gi-architects.co.uk/2016/02/powershell-check-if-ip-or-subnet-matchesfits/
# The function will check ip to ip, ip to subnet, subnet to ip or subnet to subnet belong to each other and return true or false and the direction of the check
#////////////////////////////////////////////////////////////////////////////////////////////////
function checkSubnet ([string]$addr1, [string]$addr2)
{
    # Separate the network address and lenght
    $network1, [int]$subnetlen1 = $addr1.Split('/')
    $network2, [int]$subnetlen2 = $addr2.Split('/')
 
 
    #Convert network address to binary
    [uint32] $unetwork1 = NetworkToBinary $network1
 
    [uint32] $unetwork2 = NetworkToBinary $network2
 
 
    #Check if subnet length exists and is less then 32(/32 is host, single ip so no calculation needed) if so convert to binary
    if($subnetlen1 -lt 32){
        [uint32] $mask1 = SubToBinary $subnetlen1
    }
 
    if($subnetlen2 -lt 32){
        [uint32] $mask2 = SubToBinary $subnetlen2
    }
 
    #Compare the results
    if($mask1 -and $mask2){
        # If both inputs are subnets check which is smaller and check if it belongs in the larger one
        if($mask1 -lt $mask2){
            return CheckSubnetToNetwork $unetwork1 $mask1 $unetwork2
        }else{
            return CheckNetworkToSubnet $unetwork2 $mask2 $unetwork1
        }
    }ElseIf($mask1){
        # If second input is address and first input is subnet check if it belongs
        return CheckSubnetToNetwork $unetwork1 $mask1 $unetwork2
    }ElseIf($mask2){
        # If first input is address and second input is subnet check if it belongs
        return CheckNetworkToSubnet $unetwork2 $mask2 $unetwork1
    }Else{
        # If both inputs are ip check if they match
        CheckNetworkToNetwork $unetwork1 $unetwork2
    }
}
 
function CheckNetworkToSubnet ([uint32]$un2, [uint32]$ma2, [uint32]$un1)
{
    $ReturnArray = "" | Select-Object -Property Condition,Direction
 
    if($un2 -eq ($ma2 -band $un1)){
        $ReturnArray.Condition = $True
        $ReturnArray.Direction = "Addr1ToAddr2"
        return $ReturnArray
    }else{
        $ReturnArray.Condition = $False
        $ReturnArray.Direction = "Addr1ToAddr2"
        return $ReturnArray
    }
}
 
function CheckSubnetToNetwork ([uint32]$un1, [uint32]$ma1, [uint32]$un2)
{
    $ReturnArray = "" | Select-Object -Property Condition,Direction
 
    if($un1 -eq ($ma1 -band $un2)){
        $ReturnArray.Condition = $True
        $ReturnArray.Direction = "Addr2ToAddr1"
        return $ReturnArray
    }else{
        $ReturnArray.Condition = $False
        $ReturnArray.Direction = "Addr2ToAddr1"
        return $ReturnArray
    }
}
 
function CheckNetworkToNetwork ([uint32]$un1, [uint32]$un2)
{
    $ReturnArray = "" | Select-Object -Property Condition,Direction
 
    if($un1 -eq $un2){
        $ReturnArray.Condition = $True
        $ReturnArray.Direction = "Addr1ToAddr2"
        return $ReturnArray
    }else{
        $ReturnArray.Condition = $False
        $ReturnArray.Direction = "Addr1ToAddr2"
        return $ReturnArray
    }
}
 
function SubToBinary ([int]$sub)
{
    return ((-bnot [uint32]0) -shl (32 - $sub))
}
 
function NetworkToBinary ($network)
{
    $a = [uint32[]]$network.split('.')
    return ($a[0] -shl 24) + ($a[1] -shl 16) + ($a[2] -shl 8) + $a[3]
}
#////////////////////////////////////////////////////////////////////////

# this allows us to put 'main' at the top of the listing
main
