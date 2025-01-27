# Defines the Tenant, App, and cert
param (    
    [Parameter(Mandatory=$true)][string]$tenantid,
    [Parameter(Mandatory=$true)][string]$clientid,
    [Parameter(Mandatory=$true)][string]$CertificateThumbprint,
    [Parameter(Mandatory=$true)][string]$expiration
)

# Checks to see if the certificate specified is valid
If(-not(Test-Path -Path "Cert:\CurrentUser\My\$CertificateThumbprint")){
    Write-Host "Unable to find a certificate with the following thumbprint: $CertificateThumbprint" -ForegroundColor Red
    exit
}

# Connects to Microsoft Graph
Connect-MgGraph -TenantId $tenantid -ClientId $clientid -CertificateThumbprint (Get-Item -Path "Cert:\CurrentUser\My\$CertificateThumbprint").Thumbprint

# Finds all Enterprise Apps
$EnterpriseApps = Get-MgServicePrincipal -All -Property appid,createdDateTime,displayname,id,keycredentials,notes,preferredsinglesignonmode,serviceprincipaltype

# Finds all App Registrations
$AppRegistrations = Get-MgApplication -all -property appid,approles,createddatetime,displayname,id,notes,passwordcredentials,keycredentials

# Correlates Enterprise Apps with their corresponding App Registration
$Results = @(
    ForEach($EnterpriseApp in $EnterpriseApps){

        # Retrieves owners for Enterprise Apps
        $Owners = @(Get-MgServicePrincipalOwner -ServicePrincipalID $enterpriseapp.ID)
        $EnterpriseOwners = $null
        $EnterpriseOwners = @(
            ForEach($owner in $owners){                
                Try{Get-MgUser -UserID $owner.id -erroraction Stop | Select-Object -ExpandProperty DisplayName} Catch {$EnterpriseApps | Where-Object Id -eq $owner.id | Select-Object -ExpandProperty DisplayName} # Apparently some can be owned by other enterprise apps, so I added this try/catch
            }
        )
        $EnterpriseOwnersCombined = $EnterpriseOwners -join ","
        
        # Finds the matching App Registration
        $MatchingAppRegistration = $AppRegistrations | Where-Object AppId -eq $enterpriseapp.AppId

        # Obtains the Owners value for the matching App Registation
        If($MatchingAppRegistration){
            $Owners = @(Get-MgApplicationOwner -ApplicationId $MatchingAppRegistration.ID)
            $AppOwners = $null
            $AppOwners = @(
                ForEach($owner in $owners){
                    Try{Get-MgUser -UserID $owner.id -erroraction Stop | Select-Object -ExpandProperty DisplayName} Catch {$EnterpriseApps | Where-Object Id -eq $owner.id | Select-Object -ExpandProperty DisplayName} # Apparently some can be owned by other enterprise apps, so I added this try/catch
                }
            )
            $AppOwnersCombined = $AppOwners -join ","
        } Else {$AppOwnersCombined = $null}

        # Builds the custom object to export to CSV
        [pscustomobject]@{
            EnterpriseApp = $enterpriseapp.DisplayName
            EnterpriseObjectID = $enterpriseapp.Id
            EnterpriseApplicationID = $enterpriseapp.AppId
            EnterpriseCreated = (Get-Date "$($enterpriseapp.additionalproperties.createdDateTime)").ToString("yyyy-MM-dd") # the createdDateTime key is CASE SENSITIVE specifically for the enterprise app
            EnterpriseCertificateExpiration = (($enterpriseapp | Select-Object -ExpandProperty keycredentials | Select-Object -ExpandProperty enddatetime | Sort-Object | Get-Unique) | ForEach-Object { [datetime]::Parse($_) } | Sort-Object -Descending | Select-Object -first 1)
            EnterprisePreferredSingleSignOnMode = $enterpriseapp.PreferredSingleSignOnMode
            EnterpriseServicePrincipalType = $enterpriseapp.serviceprincipaltype
            EnterpriseOwners = $EnterpriseOwnersCombined
            EnterpriseNotes = $enterpriseapp.notes
            AppRegistration = $MatchingAppRegistration.DisplayName
            AppObjectID = $MatchingAppRegistration.Id
            AppApplicationID = $MatchingAppRegistration.AppId
            AppCreated = If($MatchingAppRegistration.CreatedDateTime){(Get-Date "$($MatchingAppRegistration.CreatedDateTime)").ToString("yyyy-MM-dd")}Else{$null}
            AppClientSecretExpiration = (($MatchingAppRegistration | Select-Object -ExpandProperty passwordcredentials | Select-Object -ExpandProperty enddatetime | Sort-Object | Get-Unique) | ForEach-Object { [datetime]::Parse($_) } | Sort-Object -Descending | Select-Object -first 1)
            AppCertificateExpiration = (($MatchingAppRegistration | Select-Object -ExpandProperty keycredentials | Select-Object -ExpandProperty enddatetime |sort-object | Get-Unique) | ForEach-Object { [datetime]::Parse($_) } | Sort-Object -Descending | Select-Object -first 1)
            AppOwners = $AppOwnersCombined
            AppNotes = $MatchingAppRegistration.notes
        }
    }
)

# Adds any App Registrations that do not have a corresponding Enterprise Application to the array
$Results += @(
    ForEach($AppRegistration in $AppRegistrations){
        If(($enterpriseapps | Where-Object appid -eq $appRegistration.appid) -eq $null){

            # Obtains the Owners value for the App Registation
            $Owners = @(Try{Get-MgApplicationOwner -ApplicationId $appRegistration.appid -ErrorAction Stop}Catch{$null})
            $AppOwners = $null
            $AppOwners = @(
                ForEach($owner in $owners){
                    Try{Get-MgUser -UserID $owner.id -erroraction Stop | Select-Object -ExpandProperty DisplayName}Catch{$null}
                }
            )
            $AppOwnersCombined = $AppOwners -join ","
            
            # Builds the custom object to export to CSV
            [pscustomobject]@{
                EnterpriseApp = $null
                EnterpriseObjectID = $null
                EnterpriseApplicationID = $null
                EnterpriseCreated = $null
                EnterpriseCertificateExpiration = $null
                EnterprisePreferredSingleSignOnMode = $null
                EnterpriseServicePrincipalType = $null
                EnterpriseOwners = $null
                EnterpriseNotes = $null
                AppRegistration = $AppRegistration.DisplayName
                AppObjectID = $AppRegistration.Id
                AppCreated = (Get-Date "$($AppRegistration.CreatedDateTime)").ToString("yyyy-MM-dd")
                AppApplicationID = $AppRegistration.AppId
                AppClientSecretExpiration = (($appregistration | Select-Object -ExpandProperty passwordcredentials | Select-Object -ExpandProperty enddatetime | Sort-Object | Get-Unique) | ForEach-Object { [datetime]::Parse($_) } | Sort-Object -Descending | Select-Object -first 1)# -join "," 
                AppCertificateExpiration = (($appregistration | Select-Object -ExpandProperty keycredentials | Select-Object -ExpandProperty enddatetime |sort-object | Get-Unique) | ForEach-Object { [datetime]::Parse($_) } | Sort-Object -Descending | Select-Object -first 1)# -join ","
                AppOwners = $AppOwnersCombined
                AppNotes = $AppRegistration.Notes
            }
        }
    }
)

# Narrows the list down to just entries that have expirations in the next X number of days
$expiringsoon = $results | Where-Object EnterpriseServicePrincipalType -ne "ManagedIdentity" | Where-Object {($_.EnterpriseCertificateExpiration -ne $null -and $_.EnterpriseCertificateExpiration -lt (get-date).adddays($expiration)) -or ($_.AppClientSecretExpiration -ne $null -and $_.AppClientSecretExpiration -lt (get-date).adddays($expiration)) -or ($_.AppCertificateExpiration -ne $null -and $_.AppCertificateExpiration -lt (get-date).adddays($expiration))}

# Exports the results
$date = get-date -format yyyyMMddHHmmss
$Results | Export-Csv -path "$env:USERPROFILE\desktop\EntraApps_All_$date.csv" -NoTypeInformation -Force
$ExpiringSoon | Export-Csv -path "$env:USERPROFILE\desktop\EntraApps_ExpiringSoon_$date.csv" -NoTypeInformation -Force