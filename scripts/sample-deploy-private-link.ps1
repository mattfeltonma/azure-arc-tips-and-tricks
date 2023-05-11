try {
    # Add the service principal application ID and secret here
    $servicePrincipalClientId="{{ client_id }}";
    $servicePrincipalSecret="{{ client_secret }}";

    $env:SUBSCRIPTION_ID = "{{ subscription_id }}";
    $env:RESOURCE_GROUP = "{{ resource_group }}";
    $env:TENANT_ID = "{{ tenant_id }}";
    $env:LOCATION = "{{ region }}";
    $env:AUTH_TYPE = "principal";
    $env:CORRELATION_ID = "e8244fe3-e965-492a-8552-a66035eaad6b";
    $env:CLOUD = "AzureCloud";
    

    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072;

    # Download the installation package
    Invoke-WebRequest -UseBasicParsing -Uri "https://aka.ms/azcmagent-windows" -TimeoutSec 30 -OutFile "$env:TEMP\install_windows_azcmagent.ps1";

    # Install the hybrid agent
    & "$env:TEMP\install_windows_azcmagent.ps1";
    if ($LASTEXITCODE -ne 0) { exit 1; }

    # Configure a proxy
    & "$env:ProgramW6432\AzureConnectedMachineAgent\azcmagent.exe" config set proxy.url "http://{{proxy-url}}:{{proxy-port}}";
    
    # Configure proxy bypass for Private Link
	& "$env:ProgramW6432\AzureConnectedMachineAgent\azcmagent.exe" config set proxy.bypass "Arc";

    # Configure an allow list for extensions
    & "$env:ProgramW6432\AzureConnectedMachineAgent\azcmagent.exe" config set extensions.allowlist "Microsoft.Azure.Monitor/AzureMonitorWindowsAgent"

    # Run connect command
    & "$env:ProgramW6432\AzureConnectedMachineAgent\azcmagent.exe" connect `
    --service-principal-id "$servicePrincipalClientId" `
    --service-principal-secret "$servicePrincipalSecret" `
    --resource-group "$env:RESOURCE_GROUP" `
    --tenant-id "$env:TENANT_ID" `
    --location "$env:LOCATION" `
    --subscription-id "$env:SUBSCRIPTION_ID" `
    --cloud "$env:CLOUD" `
    --private-link-scope "{{ private-link-scope-resource-id }}" `
    --tags "Datacenter=MyDataCenter,City=MyCity,StateOrDistrict=MyState,CountryOrRegion=MyCountry,mytag1=myvalue1,mytag2=myvalue2" `
    --correlation-id "$env:CORRELATION_ID";
}
catch {
    $logBody = @{subscriptionId="$env:SUBSCRIPTION_ID";resourceGroup="$env:RESOURCE_GROUP";tenantId="$env:TENANT_ID";location="$env:LOCATION";correlationId="$env:CORRELATION_ID";authType="$env:AUTH_TYPE";operation="onboarding";messageType=$_.FullyQualifiedErrorId;message="$_";};
    Invoke-WebRequest -UseBasicParsing -Uri "https://gbl.his.arc.azure.com/log" -Method "PUT" -Body ($logBody | ConvertTo-Json) | out-null;
    Write-Host  -ForegroundColor red $_.Exception;
}
 
