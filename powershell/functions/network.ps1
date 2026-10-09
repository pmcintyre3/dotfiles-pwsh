# Grabbed from answer by user 'dog'
# Ref: https://stackoverflow.com/questions/41785413/use-powershell-to-get-device-names-and-their-ipaddress-on-a-home-network
function Get-NetworkDeviceInfo {
    #replace the string with e.g. "192.168.1.$_", whatever your subnet is, optional but will improve # of devices found
    $ips= 0..255 | ForEach-Object{ "192.168.1.$_" }

    #optional: add ports to scan. 22=ssh, 80=http, 443=https, 135=smb, 3389=rdp
    $ports= 22, 80, 443, 135, 3389

    #optional: change batch size to speed up / slow down (warning: too high will throw errors)
    $batchSize = 64

    $ips += Get-NetNeighbor | ForEach-Object{ $_.IPAddress }
    $ips = $ips | Sort-Object | Get-Unique
    $ips | ForEach-Object -Throttlelimit $batchSize -Parallel {
        $ip = $_
        $activePorts = $using:ports |
            ForEach-Object{
                if(Test-Connection $ip -quiet -TcpPort $_ -TimeoutSeconds 1){ $_ }
            }
        if(Test-Connection $ip -quiet -TimeoutSeconds 1 -count 1){
            [array]$activePorts+="(ping)"
        } 
        if($activePorts) {
            $dns = (Resolve-DnsName $ip -ErrorAction SilentlyContinue).NameHost
            $mac = ((Get-NetNeighbor |
                Where-Object{ $_.State -ne "Incomplete" -and $_.State -ne "Unreachable" -and $_.IPAddress -match $ip } |
                ForEach-Object{$_}).LinkLayerAddress)
            return [pscustomobject] @{
                dns = $dns
                ip = $ip
                ports = $activePorts
                mac = $mac
            }
        }
    } | Tee-Object -variable "dvcResults"
    $dvcResults | Sort-Object -property mac

    #build dict
    $oui = (Invoke-RestMethod standards-oui.ieee.org/oui/oui.txt) -split '\r?\n'
    $dict = @{}
    $oui |
        Where-Object{$_ -match "^[^\s]{8}"} |
        ForEach-Object {
            $arr=$_ -split "\s+"
            $dict[$arr[0]]=(($arr |Select-Object -skip 2) -join " ")
        }

    #append data
    $dvcDescriptions = $dvcResults |
        ForEach-Object{
            [pscustomobject] @{
                dns = $_.dns
                ip = $_.ip
                ports = $_.ports
                companyName = $_.mac ? $dict[$_.mac.Substring(0,8)] : ""
                mac=$_.mac
            }
        }

    $dvcDescriptions | Sort-Object -property companyName | Format-Table
}