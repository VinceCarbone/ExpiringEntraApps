You can use this script to find any Enterprise App or App Registration with a soon-to-expire certificate or secret. I have this running as a scheduled task once a month in my environment.

A few requirements

1. An App Registration granted the Microsoft Graph "Directory.Read.All" API permission (application, not delegated)
2. You'll also need a certificate uploaded to the app registration, and that same certificate installed under the user profile of whoever is going to run the script
3. The Microsoft.Graph.Applications PowerShell module needs to be installed https://learn.microsoft.com/en-us/powershell/module/microsoft.graph.applications/?view=graph-powershell-1.0

You'd run this by simply calling the script like so, obviously subsituting your own information

```
.\ExpiringEntraApps.ps1 -TenantID "whatever.onmicrosoft.com" -ClientID "12345678-1234-5678-1234-123456789012" -CertificateThumbprint "ABCDEFGHIJ1234567890ABCDEFGHIJ" -Expiration 45
```

Two files will be output onto your desktop
EntraApps_All_<date>.csv - contains all Enterprise Apps and App Registrations
EntraApps_ExpiringSoon_<date>.csv - only contains apps with expirations in the next X amount of days (based on the Expiration your provided when you ran the script)
