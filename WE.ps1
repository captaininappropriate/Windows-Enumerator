﻿# Name        : Windows Enumerator (WE)
# Author      : Greg Nimmo
# Version     : 0.14 beta
# Description : Post exploitation script to automate common enumeration activities within a Windows envrionment
#             : enumeration assumes that that the Active Directory PowerShell module is not installed so 
#             : its portable to any windows host with compatable powershell
# TODO        : Search other registry hives, unquoted service paths, create an enumerate all function

$menuPadding = "=" * 10

# main menu function
function Show-MainMenu {
    param (
        [string]$title = 'Windows Enumerator'
    )
    do {
        Clear-Host
        Write-Host "`n$menuPadding $title $menuPadding"
        Write-Host "`t 'A' Local system"
        Write-Host "`t 'B' Domain"
        Write-Host "`t 'C' Enumerate all"
        Write-Host "`t 'Q' Quit"
        Write-Host ("=" * ((($menuPadding.Length + 1) * 2) + $title.Length))

        # user input
        $mainSelection = Read-Host '[*] >>> '

        switch($mainSelection){
            'A'{
                Show-LocalSystemMenu
                continue
            }
            'B'{
                Show-DomainMenu
                continue
            }
            'C'{
                Write-Host "`tEnumerating everything`n`tCheck output file for results"
                continue
            }
            'Q'{
                Write-Host "`tExiting program"
                return
            }
        } # end switch

    } while ($mainSelection -ne 'Q') # end do until loop  
} # end Show-MainMenu function 

# start local system sub menu
function Show-LocalSystemMenu{
    param (
        [string]$title = 'Local System Enumeration'
    )
    do {
        Clear-Host
        Write-Host "`n$menuPadding $title $menuPadding"
        Write-Host "`t 'A' Accounts"
        Write-Host "`t 'B' Operating System"
        Write-Host "`t 'C' Network Configuration"
        write-host "`t 'D' Search Registry"
        Write-Host "`t 'Q' Quit"
        Write-Host ("=" * ((($menuPadding.Length + 1) * 2) + $title.Length))

        $localSystemSelection = Read-Host '[*] >>> '

        # pass argument to Enumerate-LocalSystem function paramater 0
        Enumerate-LocalSystem($localSystemSelection)

    } while ($localSystemSelection -ne 'Q')

}
# end local system sub menu

# start domain sub menu
Function Show-DomainMenu{
    param (
        [string]$title = 'Domain Enumeration'
    )
    do{
        Clear-Host
        Write-Host "`n$menuPadding $title $menuPadding"
        Write-Host "`t 'A' Domain"
        Write-Host "`t 'B' Domain Users and Groups"
        Write-Host "`t 'C' Domain Shares"
        Write-Host "`t 'Q' Quit"
        Write-Host ("=" * ((($menuPadding.Length + 1) * 2) + $title.Length))

        $domainMenuSelection = Read-Host '[*] >>> '

        # pass argument to Enumerate-Domain function paramater 0
        Enumerate-Domain($domainMenuSelection)

    } while ($domainMenuSelection -ne 'Q')
}
# end domain sub menu

# enumeration functions
# local system enumeration
function Enumerate-LocalSystem{
    param(
        [Parameter(Position=0,mandatory=$true)][string]$selection
        )
    Clear-Host
    if ($selection -eq 'A'){
        # enumerate local accounts
        '[*] Enumerating local system accoounts and groups.'
        "--- local Account Details ---`n" | Out-File -FilePath $localSystemLogFile -Append
        "[*] Current User : $env:USERNAME" | Out-File -FilePath $localSystemLogFile -Append

        # enumerate all local users and identify enabled accounts 
        '[*] Enumerating enabled local user accounts' | Out-File -FilePath $localSystemLogFile -Append
        $allUsers = @(Get-LocalUser | select Name, Description, Enabled, PasswordLastSet, LastLogon)
        $allUsers |
        ForEach-Object { 
            if ($_.Enabled -eq 'True'){
                $_ | Out-File -FilePath $localSystemLogFile -Append
            }
        } 
        # list all users home directories and their contents which are accessible and save to log
        '[*] Local Users Home Directory Contents' | Out-File -FilePath $localSystemLogFile -Append
        Get-ChildItem -Path C:\Users\$allUsers -Recurse -OutVariable userFolders -ErrorAction SilentlyContinue
        $userFolders | Out-File -FilePath $localSystemLogFile -Append
        
        # enumerate all local groups
        '[*] Local Groups' | Out-File -FilePath $localSystemLogFile -Append
        $localGroups = Get-LocalGroup
        foreach ($group in $localGroups){
            "`t`t$group" | Out-File -FilePath $localSystemLogFile -Append
        }
        # enumerate local administrators group
        $localAdmins = @(Get-LocalGroupMember -Name 'Administrators')
        '[*] Local Administrators' | Out-File -FilePath $localSystemLogFile -Append
        foreach ($admin in $localAdmins){
            "`t`t$admin" | Out-File -FilePath $localSystemLogFile -Append
        }
        Write-Host "`n[+] Account details written to:`n`t$localSystemLogFile"
        pause
    }

    elseif ($selection -eq 'B'){
        # enumerate operating system
        '[*] Enumerating operating system details.'
        '--- Operating System ---' | Out-File -FilePath $localSystemLogFile -Append
        "[*] Computer Name : $env:COMPUTERNAME" | Out-File -FilePath $localSystemLogFile -Append

        # enumeating OS details
        $operatingSystemName = (Get-WmiObject Win32_OperatingSystem).Caption
        $operatingSystemVersion = (Get-WmiObject Win32_OperatingSystem).Version
        $operatingSystemBuild = (Get-WmiObject Win32_OperatingSystem).BuildNumber
        $operatingSystemArchitecture = (Get-WmiObject Win32_OperatingSystem).OSArchitecture
        '[*] Operating System Details' | Out-File -FilePath $localSystemLogFile -Append
        "`tName : $operatingSystemName" | Out-File -FilePath $localSystemLogFile -Append
        "`tVersion : $operatingSystemVersion" | Out-File -FilePath $localSystemLogFile -Append
        "`tBuild : $operatingSystemBuild" | Out-File -FilePath $localSystemLogFile -Append
        "`t$operatingSystemArchitecture" | Out-File -FilePath $localSystemLogFile -Append
   
        # enumerate hotfix and installed software
        # installed hotfixes
        '[*] Enumerating hostfixes and installed software.'
        '[*] Installed Hotfixes and Software' | Out-File -FilePath $localSystemLogFile -Append
        "`tHotfixes`n" | Out-File -FilePath $localSystemLogFile -Append
        (Get-HotFix -ComputerName $env:COMPUTERNAME) | Out-File -FilePath $localSystemLogFile -Append
        
        # installed software
        "`tSoftware Packages`n" | Out-File -FilePath $localSystemLogFile -Append
        Get-WMIObject -Query "SELECT * FROM Win32_Product" | FT Name, Vendor, Version, Caption | Out-File -FilePath $localSystemLogFile -Append

        # active services
        '[*] Enumerating running services and processes.'
        '[*] Active Running Services' | Out-File -FilePath $localSystemLogFile -Append
        Get-Service |
        Where-Object {
            $_.Status -eq "Running"
        } | select Name, DisplayName | Out-File -FilePath $localSystemLogFile -Append


        # get all processes and the user who has spawned it. PowerShell cmdlets require admin privs so to get around this issue i'm using WMI
        '[*] Running Processes' | Out-File -FilePath $localSystemLogFile -Append
        $processOwners = @{}
        Get-WmiObject Win32_Process | Where-Object {$processOwners[$_.handle] = $_.getowner().user}
        $allProcess = Get-Process | select processname,Id,@{l="Owner";e={$processOwners[$_.id.tostring()]}}
        foreach($process in $allProcess) {
            if($process.Owner -eq $env:USERNAME) {
                $process | Out-File -FilePath $localSystemLogFile -Append
            }
        }
### cached wifi passwords

### unquoted service paths

        #TODO
        # check for unquoted service paths
        # use a foreach loop to iterate through each value in the PathName searchfing for a space character
        # if the service doesnt comtain a " and contains a space flag as possible unquoted service path to review


        "`t[+] Operating system details written to `n`t`t$localSystemLogFile"
        pause
    }

    elseif ($selection -eq 'C'){
        # enumerate network
        '--- Network Configuration ---' | Out-File -FilePath $localSystemLogFile -Append
        # enumerate IP v4 addresses
        '[*] Enumerating network configuration.'
        $ipV4AddressList = (Get-NetIPAddress | Where-Object { $_.IPv4Address -ne $null }).IPv4Address
        '[*] IP v4 Addresses' | Out-File -FilePath $localSystemLogFile -Append
        foreach ($ipv4Address in $ipV4AddressList){
            "`t$ipV4Address" | Out-File -FilePath $localSystemLogFile -Append
        }

        # enumerate IP v6 addresses
        $ipV6AddressList = (Get-NetIPAddress | Where-Object { $_.IPv6Address -ne $null }).IPv6Address
        '[*] IP v6 Addresses' | Out-File -FilePath $localSystemLogFile -Append
        foreach ($ipv6Address in $ipV6AddressList){
            "`t$ipV6Address" | Out-File -FilePath $localSystemLogFile -Append
        }

        # enumerate routing table
        '[*] IP Routing' | Out-File -FilePath $localSystemLogFile -Append
        Get-NetRoute | Out-File -FilePath $localSystemLogFile -Append

        # enumerate listening and establed tcp / udp connections
        '[*] TCP and UDP Ports' | Out-File -FilePath $localSystemLogFile -Append
        Get-NetTcpConnection -State Listen, Established | Out-File -FilePath $localSystemLogFile -Append
        Get-NetUDPEndpoint | Out-File -FilePath $localSystemLogFile -Append
        
        # output results
        Write-Host "`t[+] IP addressing, routing table, listening and established ports written to`n`t`t$localSystemLogFile"

        # enumerate firewall rules
        Get-LocalFirewallRules('Inbound')
        Get-LocalFirewallRules('Outbound')
        pause
    }

    elseif ($selection -eq 'D'){
        # search registry
        Write-Host "--- Search Registry ---"
        # array to hold search terms
        $searchTermArray = @()

        do {
            $searchTerm = Read-Host 'Enter search term >>'
            $searchTermArray += $searchTerm
        } until ($searchTerm -eq '')

        # HKCU registry hive
        $hkcuKey = Get-ChildItem HKCU:\ -Recurse -ErrorAction SilentlyContinue

        # loop through each key within the registry hive and search for the user defined terms
        foreach ($key in $hkcuKey){
            $searchKey = $key.Property
            foreach ($searchTerm in $searchTermArray){
                if ($searchKey -eq $searchTerm){
                    "[+] $key Contains $searchTerm" | Out-File -FilePath $registryLog -Append
                }
            }
        }
        Write-Host "`t[+] Registry search results written to`n`t`t$registryLog"
        pause
    }

    else{ # this shouldn't be reachable
        # exit Enumerate-LocalSystem function
        return
    }
}
# end local system enumeration function

# start Get-LocalFirewallRules function
function Get-LocalFirewallRules{
    param(
        [Parameter(Position=0,mandatory=$true)][string]$selection
        )
        "[*] Enumerating $selection firewall rules."
        "[*] $selection firewall rules`n" | Out-File -FilePath $firewallLog -Append
        Get-NetFirewallRule | 
        ForEach-Object {
            if ($_.Enabled -eq 'True' -and $_.Direction -eq $selection){
                # create an array for the rule
                $firewallRule = @($_.DisplayName, $_.Description, $_.Action)
                # format the output
                "Display Name " + $firewallRule[0] | Out-File -FilePath $firewallLog -Append 
                "Description " + $firewallRule[1] | Out-File -FilePath $firewallLog -Append
                "Action " + $firewallRule[2] | Out-File -FilePath $firewallLog -Append
                $_ | Get-NetFirewallPortFilter | Out-File -FilePath $firewallLog -Append
            }
        }
        Write-Host "`t[+] $selection firewall rules written to`n`t`t$firewallLog"
}
# end Get-LocalFirewallRules function

# domain enumeration
function Enumerate-Domain{
    param(
        [Parameter(Position=0,mandatory=$true)][string]$selection
        )
    Clear-Host
    if ($selection -eq 'A'){
        # enumerate domain details
        # get domain name
        "[*} Domain Name : $env:USERDNSDOMAIN" | Out-File -FilePath $domainLogFile -Append

        # get the domain SID
        $userName = $env:USERNAME
        $user = New-Object System.Security.Principal.NTAccount($username)
        $sid = $user.Translate([System.Security.Principal.SecurityIdentifier])
        $userSid = $sid.Value
        $domainSidValues = @($userSid.Split("-")[0..6])
        $domainSid = $domainSidValues -join '-'
        "[*] Domain SID : $domainSid" | Out-File -FilePath $domainLogFile -Append

        # locate all domain controllers in the forest
        '[*] Domain Controllers' | Out-File -FilePath $domainLogFile -Append
        $forest = [System.Directoryservices.ActiveDirectory.Forest]::GetCurrentForest()  
        $forest.Domains | ForEach-Object {$_.DomainControllers} |`
        ForEach-Object {
            $hostEntry= [System.Net.Dns]::GetHostByName($_.Name)
            New-Object -TypeName PSObject -Property @{
                Name = $_.Name
                IPAddress = $hostEntry.AddressList[0].IPAddressToString
            }
        } |
        Select-Object -property @{N='Domain Controller';E={$_.Name}}, IPAddress | Out-File -FilePath $domainLogFile -Append
    } 
    elseif ($selection -eq 'B'){
        # enumerate domain users and groups
        "`n[*] Domain Users" | Out-File -FilePath $domainLogFile -Append
        Get-DomainObject('User')
        "`n[*] Domain Groups" | Out-File -FilePath $domainLogFile -Append
        Get-DomainObject('Group')
        
    }
    elseif ($selection -eq 'C'){
        # enumerate computers and shares
        "`n[*] Domain Computers" | Out-File -FilePath $domainLogFile -Append
        Get-DomainObject('Computer') 
    }
    else{ # this shouldn't be reachable
        # exit Enumerate-Domain function
        return
    }
}
# end domain enumeration function

# start domain object function
function Get-DomainObject{
    param(
        [Parameter(Position=0,mandatory=$true)][string]$domainObject
        )
        $objectTypes = @('User','Group','Computer')
        if ($domainObject | Where-Object { $_ -in $objectTypes }){
            $forest = [System.DirectoryServices.ActiveDirectory.Forest]::GetCurrentForest()
            $domainList = @($forest.Domains)
            $domains = $domainList | foreach { $_.name }
            foreach ($domain in $domains){
                # search filter based on supplied argument
                $strFilter = "(objectCategory=$domainObject)"

                # new directory searcher instance
                $objDomain = New-Object System.DirectoryServices.DirectoryEntry
                
                # directory searcher object properties
                $objSearcher = New-Object System.DirectoryServices.DirectorySearcher
                $objSearcher.SearchRoot = $objDomain
                $objSearcher.PageSize = 1000
                $objSearcher.Filter = $strFilter
                $objSearcher.SearchScope = "Subtree"

                # properties to return
                $colProplist = "samaccountname"
                foreach ($i in $colPropList){$objSearcher.PropertiesToLoad.Add($i) | out-null}

                # search active directory 
                $colResults = $objSearcher.FindAll()
                foreach ($objResult in $colResults){
                    $objItem = $objResult.Properties; $objItem.samaccountname | Out-File -FilePath $domainLogFile -Append
                }
            } # end foreach loop

            # if the arguemnt passed to the function is Group
            if ($domainObject -eq 'Group'){
                # create a new search filter for only administrator groups
                "`n[*] Administrative Groups and Users" | Out-File -FilePath $domainLogFile -Append
                $objSearcher.Filter = "(&(objectClass=Group)(sAMAccountName=*Admin*))"

                # properties to return
                $colProplist = "samaccountname"
                foreach ($i in $colPropList){
                    $objSearcher.PropertiesToLoad.Add($i) | out-null 
                }
                
                # search active directory for only administrative groups
                $allObjects = $objSearcher.FindAll()
                foreach ($objResult in $colResults){
                    $objItem = $objResult.Properties
                    if ($objItem.samaccountname | Where-Object { $_ -like "*Admins*"}){
                        "`t[+] " + $objItem.samaccountname | Out-File -FilePath $domainLogFile -Append
                        
                        # for each admin group found setup a ldap filter
                        $adminGroup = $objItem.samaccountname
                        $strFilter = "(&(ObjectClass=Group)(cn=$adminGroup))"
                        
                        # properties to return
                        $colProplist = "member"
                        foreach ($i in $colPropList){$objSearcher.PropertiesToLoad.Add($i) | out-null}
                        
                        # search active directory for group members
                        $colResults = $objSearcher.FindAll()
                        foreach ($objResult in $colResults){
                            $objItem = $objResult.Properties; $objItem.member | Out-File -FilePath $domainLogFile -Append
                        }
                    }
                }
            } # end if #domainObject is a Group

            # if the argument passed to domainObject is computer
            elseif ($domainObject -eq 'Computer'){
                # get all computers by samaccountname
                "`n[*] Domain Computer Shares" | Out-File -FilePath $domainLogFile -Append
                foreach ($objResult in $colResults){
                    $domainComputers = @($objItem = $objResult.Properties; $objItem.samaccountname)
                    foreach($domainComputer in $domainComputers){
                        # remove $ sign from the computer name so get-wmiobject doesn't fail
                        foreach($domainComputer in $domainComputers){
                            ForEach-Object{
                                $domainComputer = $domainComputer.Substring(0,$($domainComputer.Length - 1))
                                Get-WmiObject -Class Win32_Share -Property * -ComputerName $domainComputer 
                                } |
                                # rename a few columns to something more understandable and output the results
                                Select-Object -property @{N='Hostname';E={$_.PSComputerName}}, @{N='Share';E={$_.Name}}, description | Out-File -FilePath $domainLogFile -Append
                            } # end inner foreach-object
                        } # end inner foreach
                    } # end outer foreach       
            } # end elseif
        } # end outer if
            #search the object for shares
    }
# end domain object function

# enumerate all function
    # create an array holding all valid options for Enumerate-LocalSystem and Enumerate-Domain
    # loop through the array executing each option
    #$domainMenuArray = @('A','B','C')
    #foreach ($value in $domainMenuArray){ xxxxx } execute function calls
# end enumerate all function

# execute program
# log file locations (keeping things seperate to make life easier)
$localSystemLogFile = ${env:USERPROFILE} + "\Documents\$(Get-Date -Format 'yyyy-MM-dd')_WE_localSystemLog.txt"
$firewallLog = ${env:USERPROFILE} + "\Documents\$(Get-Date -Format 'yyyy-MM-dd')_WE_firewall_log.txt"
$registryLog = ${env:USERPROFILE} + "\Documents\$(Get-Date -Format 'yyyy-MM-dd')_WE_registry_log.txt"
$domainLogFile = ${env:USERPROFILE} + "\Documents\$(Get-Date -Format 'yyyy-MM-dd')_WE_DomainDetailsLog.txt"
Show-MainMenu