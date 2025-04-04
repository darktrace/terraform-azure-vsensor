#Deployment configuration
variable "location" {
  type        = string
  description = "Location for all resources. Leave blank for Resource Group location."
  default     = ""
}

variable "short_id" {
  type        = string
  description = "A short (upto 20 character alphanumeric) string to prefix resource names by (where available)."

  validation {
    condition     = length(var.short_id) > 0 && length(var.short_id) <= 20 && can(regex("^[a-zA-Z0-9]+$", var.short_id))
    error_message = "The short ID must be upto 20 alphanumeric characters."
  }
}

variable "rg_name" {
  type        = string
  description = "Name of an existing resource group to deploy the quickstart into. Leave blank to let the quickstart create one."
  default     = ""
}


variable "zones" {
  type        = list(number)
  description = "Availability Zone numbers to deploy the vSensors. At least two availablity zones are required. Defaults to random assignment."
  default     = []
}

#Network configuration existing VNet
variable "vnet_name" {
  type        = string
  description = "Name of the existing Virtual Network to be monitored, should be in the same location as this deployment/resource group. Leave blank to deploy a new VNet."
  default     = ""
}

variable "vnet_rg" {
  type        = string
  description = "The Resource Group name that the existing Virtual Network is deployed in."
  default     = null
}

variable "subnet_name" {
  type        = string
  description = "Existing Subnet name (within existing provided vnet_name) that the vSensors should be launched into. Must have 'Microsoft.Storage' Service Endpoint configured."
  default     = ""
}

#Network configuration new VNet

variable "vnet_cidr" {
  type        = string
  description = "The IPv4 CIDR block for deploying a new VNet. This is ignored if an existing vnet_name is provided. Default 10.0.0.0/16."
  default     = null
  validation {
    condition     = var.vnet_cidr == null || can(regex("^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5]).){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(/(1[6-9]|2[0-4]))$", var.vnet_cidr))
    error_message = "The new VNet CIDR block must be in the form x.x.x.x/16-24."
  }
}

variable "subnet_cidr" {
  type        = string
  description = "CIDR IP range of the new private subnet the vSensors will be deployed in. This is ignored if an existing subnet_name is provided. This must be an unused range within the supplied VNet. E.g. 10.0.0.0/24"
  default     = null
  validation {
    condition     = var.subnet_cidr == null || can(regex("^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5]).){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(/(1[7-9]|2[0-8]))$", var.subnet_cidr))
    error_message = "The Subnet CIDR block must be in the form x.x.x.x/17-28."
  }

}

variable "nat_gw_enable" {
  type        = bool
  description = "Deploy a NAT Gateway in the Virtual Network. If using an existing VNet and are using other firewall configurations, false may be required."
  default     = true
}

variable "route_table_name" {
  type        = string
  description = "If not deploying a NAT Gateway, you may need to provide an existing route table to attach to the new deployed vSensor subnet to allow internet routing."
  default     = ""
}

variable "route_table_rg" {
  type        = string
  description = "The Resource Group the existing Route Table (if provided) is deployed in. Default is same resource group as the VNet."
  default     = ""
}

#Bastion
variable "bastion_enable" {
  type        = bool
  description = "Deploy a Azure Bastion host to access your vSensor deployment. If 'false' is selected, configure your ssh access manually after deployment."
  default     = false
}

variable "bastion_subnet_cidr" {
  type        = string
  description = "CIDR IP range of the private subnet the Azure Bastion will be deployed in (if deployed). This must be an unused range within the supplied vNet. E.g. 10.0.160.0/24. If Bastion Enable is false, this value will be ignored."
  default     = null

  validation {
    condition     = var.bastion_subnet_cidr == null || can(regex("^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5]).){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(/(1[7-9]|2[0-6]))$", var.bastion_subnet_cidr))
    error_message = "The Subnet CIDR block must be in the form x.x.x.x/17-26."
  }
}

variable "ssh_cidrs" {
  type        = list(any)
  description = "Provide a private address range using CIDR notation (e.g. 10.1.0.0/24), or an IP address (e.g. 192.168.99.21) for Management access via ssh (port 22/TCP)."
  default     = null
}

variable "terraform_cidrs" {
  type        = list(any)
  description = "Allowed Public CIDR blocks where terraform will execute from. This is required to apply access rules for PCAP storage, whilst also allowing terraform to manage resources. This is due to a limitation with the Azure provider/API."
}

#Darktrace vSensor configuration
variable "instance_size" {
  type        = string
  description = "The VM size. Check the Darktrace customer portal for more information about the vSensor Virtual Hardware requirements."
  default     = "Standard_D2s_v3"
}

variable "min_size" {
  type        = number
  description = "The minimum number of vSensors to auto-scale down to."
  default     = 2
}

variable "max_size" {
  type        = number
  description = "The maximum number of vSensors to be deployed by auto-scaling during high traffic."
  default     = 5
}

variable "ssh_admin_username" {
  type        = string
  default     = "darktrace"
  description = "Administrator username to be created when the vSensor is spun up."
}

variable "ssh_pubkey" {
  type        = string
  description = "Public key for the admin username to ssh to the vSensors. Note that password authentication over ssh for newly created VMs is disabled"

  validation {
    condition     = length(var.ssh_pubkey) > 0
    error_message = "The ssh_pubkey cannot be empty. It is required with the admin username to access and manage vSensors."
  }
}

variable "update_key" {
  type        = string
  description = "Darktrace Update Key needed to install the vSensor package. Contact your Darktrace representative for more information."

  validation {
    condition     = length(var.update_key) <= 256 && can(regex("^[a-zA-Z0-9%.]+:[a-zA-Z0-9%.]+$", var.update_key))
    error_message = "Invalid update key format - should be of alphanumeric format containing a colon (:) and up to 256 characters."
  }
}


#Darktrace environment configuration
variable "instance_host_name" {
  type        = string
  description = "The FQDN or IP of the Darktrace master instance (virtual/physical)."
}

variable "instance_port" {
  type        = number
  description = "Connection port between vSensor and the Darktrace Master instance."
  default     = 443
  validation {
    condition     = floor(var.instance_port) == var.instance_port && var.instance_port <= 65535 && var.instance_port >= 1
    error_message = "The Darktrace master instance port must be a valid port number."
  }
}

variable "instance_proxy" {
  type        = string
  description = "(Optional) A proxy that should be specified in the format http://user:pass@hostname:port." #gitleaks:allow
  default     = ""

  validation {
    condition     = var.instance_proxy == "" || can(regex("^http://.+:[0-9]+$", var.instance_proxy)) || can(regex("^http://.+:.+@.+:[0-9]+$", var.instance_proxy))
    error_message = "Invalid proxy - the proxy should be specified in the format http://hostname:port with no authentication, or http://user:pass@hostname:port with authentication." #gitleaks:allow
  }
}

variable "push_token" {
  type        = string
  description = <<EOT
  Push token to authenticate with the appliance. Should be generated on the Darktrace master instance."
  For more information, see the Darktrace Customer Portal (https://customerportal.darktrace.com/login)."
  EOT

  validation {
    condition     = can(regex("^[a-zA-Z0-9-]{4,64}:[a-zA-Z0-9]{5,63}$", var.push_token))
    error_message = "Invalid push token format - should be of alphanumeric format containing a colon (:). Double check or regenerate the push token."
  }
}

variable "os_sensor_hmac_token" {
  type        = string
  description = "The hash-based message authentication code (HMAC) token to authenticate osSensors with vSensor."

  validation {
    condition     = can(regex("^[a-zA-Z0-9]{6,62}$", var.os_sensor_hmac_token))
    error_message = "Invalid osSensor HMAC token format - should be of alphanumeric format between 6 and 62 characters. Double check or change the osSensor HMAC token."
  }
}

#Logs and captured packet retention
variable "lifecycle_pcaps_blob_days" {
  description = "Number of days to retain captured packets in Azure Blob Storage. Longer retention will increase storage costs. Set to 0 to disable PCAP storage."
  type        = number
  default     = 7

  validation {
    condition     = floor(var.lifecycle_pcaps_blob_days) == var.lifecycle_pcaps_blob_days && var.lifecycle_pcaps_blob_days <= 365 && var.lifecycle_pcaps_blob_days >= 0
    error_message = "The number of days to retain captured packets in Azure Blob Storage must be a whole number."
  }
}

variable "private_link_enable" {
  type        = bool
  description = "If `true` will create a private link service to attach osSensors from other networks."
  default     = false
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to all compatible resources. The template will also add tags for the deployment prefix."
  default     = {}
}
