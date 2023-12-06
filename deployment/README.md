# Azure Arc Connected Machine Agent
# Design and Deployment Considerations

## Decisions
### General

1. Decide if you plan to use the [Guest Configuration](https://learn.microsoft.com/en-us/azure/architecture/hybrid/azure-arc-hybrid-config#enable-azure-policy-guest-configuration) feature and [which extensions you will require for the features you plan to use](https://learn.microsoft.com/en-us/azure/azure-arc/servers/overview#supported-cloud-operations).
   
2. Decide which subscription, region, and resource group the Azure Arc Server resources will be stored in.

**Private Link Only** 
There are [specific regional limitations when using Private Link](https://learn.microsoft.com/en-us/azure/azure-arc/servers/private-link-security#restrictions-and-limitations) which must be taken into consideration.

### Connectivity
1. Decide if you will use [Private Link connectivity](https://learn.microsoft.com/en-us/azure/azure-arc/servers/private-link-security) for the Azure Arc Connected Machine agent.
   
### Governance
1. Decide if you will use [Azure Policy to automatically install additional extensions such as the Azure Monitor Agent](https://learn.microsoft.com/en-us/azure/azure-arc/servers/concept-log-analytics-extension-deployment#use-azure-policy).
   
2. Decide if you will use [automatic or manual](https://learn.microsoft.com/en-us/azure/azure-arc/servers/manage-automatic-vm-extension-upgrade?tabs=azure-portal) extension upgrades.
   
3. Decide if you will use an allow or block list to govern which extensions can be deployed to the onboarded machines.

### Deployment
1. Decide [how you will deploy the Azure Arc Connected Machine Agent](https://learn.microsoft.com/en-us/azure/azure-arc/servers/deployment-options#onboarding-methods). It is recommended to deploy the agent using the [deployment script generated](https://learn.microsoft.com/en-us/azure/azure-arc/servers/onboard-service-principal) by the Azure Portal. This script can then be deployed via custom automation or an [enterprise solution like SCCM](https://learn.microsoft.com/en-us/azure/azure-arc/servers/onboard-configuration-manager-custom-task#create-a-task-sequence).  The agent must be deployed using an administrator for Windows and a root account for Linux. 
   
	**NOTE - The service principal credentials are stored in the script by default. It is recommended to store and retrieve this credential from an enterprise secret management solution if available.**
   
## Prerequisites
1. Validate the subscription you are connected the machines to has the [required resource providers registered](https://learn.microsoft.com/en-us/azure/azure-arc/servers/prerequisites#azure-resource-providers)

2. Validate the operating system of the machines you are planning to onboard is a [supported operating system for Azure Arc](https://learn.microsoft.com/en-us/azure/azure-arc/servers/prerequisites#supported-operating-systems). 
   
3. Validate that the [feature you wish to use is supported](https://learn.microsoft.com/en-us/azure/azure-arc/servers/manage-vm-extensions#operating-system-extension-availability) on the operating system.
   
4. [Validate the URLs the agent will need access to](https://learn.microsoft.com/en-us/azure/azure-arc/servers/network-requirements?tabs=azure-cloud#urls) based upon the features you have choosen to use.
   
5. Validate you have opened the appropriate firewall rules [to allow traffic to the required endpoints](https://learn.microsoft.com/en-us/azure/azure-arc/servers/network-requirements?tabs=azure-cloud#urls) to onboard the Azure Connected Machine Agent and relevant Azure Arc features you decided to use. 

	**NOTE - There is a [subset of endpoints](https://learn.microsoft.com/en-us/azure/azure-arc/servers/network-requirements?tabs=azure-cloud#subset-of-endpoints-for-esu-only) required if you only intend to use Azure Arc for Extended Security Updates. If you use this susbet of endpoints only, you must manually install the intermediary CA certificate on all endpoints that will receive these updates. This certificate is used to sign the updates delivered through ESU. There is also a special update that must be installed on each endpoint that receives ESU updates. Both the certificate and the update as all as other prerequisites for ESU can be [found here](https://learn.microsoft.com/en-us/azure/azure-arc/servers/troubleshoot-extended-security-updates#esu-patches-issues).**
   
6. Validate if the machines being onboarded use a proxy. If the machines do use a proxy, then determine if the proxy requires authentication. If so, you will need to bypass the authentication for the required Azure Arc endpoints. [The Azure Arc Connected Machine Agent does not support authenticated proxies](https://learn.microsoft.com/en-us/azure/azure-arc/servers/manage-agent?tabs=windows#update-or-remove-proxy-settings)


## Setup of On-premises Environment
1. If you are using Windows Active Directory Restricted Groups to restrict which security principals are granted the "Log On as a Service" user right, [you must ensure that "NT SERVICE\\himds" is included as a security principal with this user right](https://learn.microsoft.com/en-us/azure/azure-arc/servers/security-overview#agent-security-and-permissions). This local machine identity is used by the Hybrid Instance Metadata Service.

## Setup of Azure Resources
1. [Create an Azure AD Service Principal](https://learn.microsoft.com/en-us/cli/azure/create-an-azure-service-principal-azure-cli) which will be used to authenticate to Azure to onboard the machine to Azure Arc. This service principal should be granted the Azure RBAC role named Azure Connected Machine Onboarding.
   
2. **Private Link Only** [Create Private DNS Zones for the following zones](https://learn.microsoft.com/en-us/azure/azure-arc/servers/private-link-security#dns-configuration-using-azure-integrated-private-dns-zones)
	1. privatelink.his.arc.azure.com
	2. privatelink.guestconfiguration.azure.com
	3. privatelink.dp.kubernetesconfiguration.azure.com
	   
3. **Private Link Only** [Link Private DNS Zones to virtual network DNS resolver is deployed to](https://learn.microsoft.com/en-us/azure/dns/private-dns-virtual-network-links)
   
4. **Private Link Only**  [Create Azure Arc Private Link Scope and Private Endpoints](https://learn.microsoft.com/en-us/azure/azure-arc/servers/private-link-security#create-a-private-link-scope)
   
5. **Private Link Only** Validate that the Network Security Group associated with the subnet containing the Private Endpoint allows for traffic from on-premises network space. This traffic will come over TCP 443.
   
6. **Private Link Only** Configure DNS forwarding on premises for the following zones:
	1. his.arc.azure.com
	2. guestconfiguration.azure.com
	3. dp.kubernetesconfiguration.azure.com
	   
7. **Private Link Only** Test DNS resolution from an on-premises machine to ensure ithe DNS forwarding is working properly.
   
8. Create a resource group in your preferred Azure region in the Azure subcription you want the Azure Arc Server objects to be deployed to.
   
9. Generate onboarding script
	* [Generate onboarding script when not using Private Link connectivity model](https://learn.microsoft.com/en-us/azure/azure-arc/servers/onboard-portal#generate-the-installation-script-from-the-azure-portal)
	* **Private Link Only** [Generate onboarding script when using Private Link connectivity model](https://learn.microsoft.com/en-us/azure/azure-arc/servers/private-link-security#configure-a-new-azure-arc-enabled-server-to-use-private-link)

## Installation of Azure Connected Machine Agent
1. If the machine uses a proxy to communicate with the Internet, you will need to modify the onboarding script to include the code snippet below. This code snippet should be placed before the azcmagent.exe connect command.

	* Windows
	```
	# Configure a proxy
	& "$env:ProgramW6432\AzureConnectedMachineAgent\azcmagent.exe" config set 
	proxy.url "http://{{proxy-url}}:{{proxy-port}}";
	```
	* Linux
	```
	# Configure a proxy
	sudo azcmagent config set proxy.url "http://{{proxy-url}}:{{proxy-port}}";
	```
2. **Private Link Only** If you are using Private Link connectivity to the Azure Arc service and a proxy on the machine you are onboarding, modify the deployment script to [bypass the proxy for communication to the endpoints behind the Private Endpoints](https://learn.microsoft.com/en-us/azure/azure-arc/servers/manage-agent?tabs=windows#proxy-bypass-for-private-endpoints). You can use the code snippet below. This code snippet should be placed after the line in step 1.
   
	* Windows
	```
	# Configure proxy bypass for Private Link
	& "$env:ProgramW6432\AzureConnectedMachineAgent\azcmagent.exe" config set 
	proxy.bypass "Arc";
	```
	* Linux
	```
	# Configure proxy bypass for Private Link
	sudo azcmagent config set proxy.bypass "Arc";
	```

3. Download the MSI package for the agent and install it [manually on a non-production machine](https://learn.microsoft.com/en-us/azure/azure-arc/servers/onboard-portal#install-and-validate-the-agent-on-windows). If using a proxy, configure the proxy with the commands in step 1. Validate the machine is capable of reaching the required endpoints using [azmcagent check](https://learn.microsoft.com/en-us/azure/azure-arc/servers/manage-agent?tabs=windows#check). 
   
	**Private Link Only** There is an [additional parameter](https://learn.microsoft.com/en-us/azure/azure-arc/servers/manage-agent?tabs=windows#check) you must specify if you are using Private Link
	
4.  [Manually onboard the non-production machine by running your deployment script](https://learn.microsoft.com/en-us/azure/azure-arc/servers/onboard-portal). Validate that the service principal is able to onboard the machine and that the machine appears in the Portal.

5. Begin to deploy the machine in batches using one of the [non-interactive methods included](https://learn.microsoft.com/en-us/azure/azure-arc/servers/deployment-options#onboarding-methods) in the documentation and validate the machines are appearing in the Portal and reporting as connected.

## Best Practices

1. There are a wide range of features available for onboarded machines. This author recommends governing which features can be enabled for machines onboarded to Azure Arc. Features like [Guest Configuration should be disabled](https://learn.microsoft.com/en-us/azure/azure-arc/servers/security-overview#enable-or-disable-guest-configuration) if it will not be used. You should [control which extensions can be deployed to the machine](https://learn.microsoft.com/en-us/azure/azure-arc/servers/security-overview#local-agent-security-controls). If you're using Azure Arc for only Extended Support Updates you can ]block all extensions with the Azure Connected Machine Agent version 1.35 and above](https://learn.microsoft.com/en-us/azure/azure-arc/servers/security-overview#extension-allowlists-and-blocklists).
   
	Some Azure Arc features and extensions allow for the Azure management plane to modify the operating system of the onboarded server. The Guest Configuration feature is an example of such a feature. Extensions such as the Custom Script and Hybrid Runbook extensions are other examples. If this is not desired, the features should be disabled and the extensions should be disallowed.
	
	When governing extensions, it is best practice to use an allow list versus a deny list.

	Azure Policy can be used to audit the status of extensions installed on an Azure Arc connected machines. [This policy is an example](https://github.com/mattfeltonma/azure-custom-policies/tree/master/Arc/audit-allow-extensions) where the policy reports Azure Arc connected machines as non-compliant if they allow for extensions to be deployed.
	
2. Secure the group membership to the [Hybrid agent extension applications local group](https://learn.microsoft.com/en-us/azure/azure-arc/servers/agent-overview#windows-agent-installation-details) on each Azure Arc onboarded server. 
   
	A system-assigned managed identity (SMI) is created for each server onboarded for Azure Arc. This SMI is used by the agent to obtain access tokens from Azure Active Directory to access Azure services. This capability in provided by the Hybrid Instance Metadata Service (HIMDS) that runs on the onboarded machine. 
	
	Members of the Hybrid agent extension applications local group can obtain access tokens from Azure AD for the machine's SMI allowing that application to exercise the permissions in Azure granted to the SMI. 
	
	It is best practice to secure the membership to this group to ensure only authorized applications are capable of obtaining an access token.
	
3. Deploy the Azure Connected Machine Agent to a non-production machine first. Validate the agent can be successfully deployed using the service principal you have provisioned. Also validate that the Azure Connected Machine Agent and additional extensions you may use do not interfere with existing 3rd party agents you may be using.
   
4. Deploy the Azure Connected Machine Agent in batches. Ensure you incorporate some type of validation testing such as using the agent's built in [connectivity checker](https://learn.microsoft.com/en-us/azure/azure-arc/servers/manage-agent?tabs=windows#check) and validating in the Portal the machine is connected.

