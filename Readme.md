# Azure NFS → AWS EFS Migration (DataSync) — Handover

## 1. What this does

Migrates an Azure Files NFS share to Amazon EFS using AWS DataSync, with a DataSync agent deployed as an Azure VM. This doc lists exactly what you need on both sides, how to deploy and activate the agent, and how to run the Terraform.

---

## 2. What you need from AWS (have these values ready)

- **VPC ID** — the VPC your EFS mount targets live in
- **EFS file system ARN**
- **EFS security group ID** — the SG already attached to the EFS mount targets (Terraform will add a rule to it, not replace it)
- **Subnet ARN** — a subnet in that same VPC/AZ as an EFS mount target, for DataSync's ENI
- **S3 bucket ARN** — any existing bucket to store DataSync task-report output (unrelated to the migration data itself)
- **KMS key ARN** — if reusing an existing key, otherwise the module can create one

Pull these with:
```bash
aws efs describe-mount-targets --region <region> --file-system-id <fs-id> --output table
aws efs describe-mount-target-security-groups --region <region> --mount-target-id <mount-target-id>
```

---

## 3. What you need from Azure

- An **Azure Files NFS share** (Premium/FileStorage account, `--enabled-protocols NFS`), reachable over the network from wherever the DataSync agent VM will live
- The storage account must have **`https-only` set to `false`** — NFS doesn't run over HTTPS, and this is required for the mount to succeed
- If using a private endpoint: a **private DNS zone** (`privatelink.file.core.windows.net`) linked to the VNet, with an **A record** pointing to the private endpoint's IP — this doesn't get created automatically by `az network private-endpoint create` via CLI, it must be set up explicitly
- A **VNet/subnet** for the DataSync agent VM — ideally the same VNet as the NFS share (or with network access to it)

You'll need the NFS share's:
- **Hostname** (e.g. `<account>.file.core.windows.net`)
- **Subdirectory/path** (e.g. `/<account>/<share-name>`)

---

## 3.1 Azure Network Security Group (NSG) Rules

The DataSync Agent VM requires specific Network Security Group (NSG) rules on its Subnet/NIC:

### Outbound Rules:
- **Port 443 (TCP)**: Source `VirtualNetwork` -> Destination `Internet` (Action: `Allow`)
  - *Role*: Enables outbound control plane communication and TLS-encrypted data streaming to AWS DataSync endpoints (`datasync.<region>.amazonaws.com`).
- **Ports 2049, 111 (TCP/UDP)**: Source `VirtualNetwork` -> Destination `VirtualNetwork` / Storage Private Endpoint (Action: `Allow`)
  - *Role*: Enables mounting and traversing the Azure Files NFS share over NFS/RPC.

### Inbound Rules:
- **Port 80 (TCP)**: Source `VirtualNetwork` (or Admin IP) -> Destination `Agent_VM_IP` (Action: `Allow`)
  - *Role*: Temporary rule used only during setup to retrieve the agent's `activationKey`. Delete this rule after activation.
- **Port 22 (TCP)**: Restrict to internal jumpbox/admin IP or disable if not needed.
- **Default Inbound**: All unsolicited inbound traffic from the internet is **blocked** by default (`DenyAllInBound`).

---

## 3.2 Azure NAT Gateway Setup (Enterprise Egress without Public IP)

For banking and enterprise clients where assigning a Public IP directly to a VM NIC is prohibited:

An **Azure NAT Gateway** provides **outbound-only** internet access (Port 443 HTTPS) for the DataSync Agent VM while keeping the VM 100% private and blocking 100% of unsolicited inbound internet connections.

---

## 4. Deploying the DataSync agent (Azure VM)

Use AWS's official automation: https://github.com/aws-samples/aws-datasync-deploy-agent-azure

### EC2 instance needed to run the deployment script
- **Amazon Linux 2**
- **At least 160GB disk** — the agent's VHDX→VHD conversion is a large file operation and will fail partway through on a small default volume
- Outbound internet access (to reach both Azure and AWS endpoints)
- `aws` CLI (with credentials/instance role for DataSync), `az` CLI, `jq`, `qemu-img` — the script installs these itself if missing

### Run it
```bash
git clone https://github.com/aws-samples/aws-datasync-deploy-agent-azure.git
cd aws-datasync-deploy-agent-azure

# Known jq key-casing bug in the script — patch before running:
sed -i "s/jq -r '\.accessSAS'/jq -r '.accessSas \/\/ .accessSAS'/" datasync.sh

az login

sudo bash datasync.sh \
  -d existing_vnet \
  -l <azure-region> \
  -r <resource-group> \
  -v <vm-name> \
  -g <vnet-resource-group> \
  -n <vnet-name> \
  -s <subnet-name> \
  -z <vm-size> \
  -u <azure-subscription-id>
```

**VM size guidance (official)**: 32GB RAM for task executions up to 20 million files, 64GB above that. The DataSync agent VM must boot as **Hyper-V Generation 1** — pick a VM size that supports Gen1, not just whatever's available; forcing the disk to Gen2 to work around a size restriction leads to disk-controller boot failures instead.

---

## 5. Retrieving the activation key

The agent VM serves an activation redirect on port 80. You need network reachability to it — either from something already inside its VNet, or by temporarily attaching a public IP.

```bash
curl -v -L "http://<agent-ip>/?activationRegion=<aws-region>"
```

The activation key is in the **first** `302` response's `Location` header:
```
Location: https://console.aws.amazon.com:443?...&activationKey=XXXXX-XXXXX-XXXXX-XXXXX-XXXXX
```
You don't need to follow the rest of the redirect chain — the key is already there.

If you attached a temporary public IP for this, remove it afterward:
```bash
az network nic ip-config update -g <rg> --nic-name <nic> --name <ipconfig> --remove PublicIPAddress
az network public-ip delete -g <rg> -n <pip-name>
```

---

## 6. Running the Terraform

Fill in `terraform.tfvars` with everything gathered above:

```hcl
vpc_id                 = "<from step 2>"
efs_security_group_id  = "<from step 2>"

task_report_s3_bucket_arn = "<from step 2>"

agent_activation_key = "<from step 5>"
# or, if Terraform can reach the agent directly over the network:
# agent_ip_address = "<agent-ip>"

migrations = {
  nfs-to-efs = {
    nfs_server_hostname = "<from step 3>"
    nfs_subdirectory    = "<from step 3>"

    efs_file_system_arn = "<from step 2>"
    efs_subdirectory    = "/"

    subnet_arn = "<from step 2>"

    task_report_subdirectory = "/datasync-reports/nfs-to-efs"
  }
}
```

Then:
```bash
terraform init
terraform plan
terraform apply
```

**The task itself is not started by Terraform** — go to **AWS Console → DataSync → Tasks → Start** manually, matching the existing Blob→S3 workflow.

---

## 7. Troubleshooting notes

- **`mount.nfs: access denied by server`** → storage account still has `https-only` enabled. Fix: `az storage account update --https-only false` (mutable, no need to recreate).
- **DNS resolves to a public IP instead of private** → private DNS zone/VNet link/A record weren't created. The CLI path for `az network private-endpoint create` doesn't set these up automatically the way the Portal does — create them explicitly.
- **`SubnetsHaveNoServiceEndpointsConfigured`** → enable the `Microsoft.Storage` service endpoint on the subnet before adding a storage account network rule.
- **`enableNfsV3` errors on Azure Files** → that property is for Blob NFS 3.0, a different feature. Azure Files NFS is controlled entirely by `--enabled-protocols NFS` on the share.
- **`Destination: 'null'` during `azcopy copy`** in the deployment script → known `jq` key-casing bug (`accessSAS` vs `accessSas`). Patch as shown in Section 4.
- **`cannot boot Hypervisor Generation '1'`** → the chosen VM size is Gen2-only. Pick a Gen1-capable size instead of converting the disk.
- **`cannot boot with OS image or disk` (disk controller mismatch)** → happens if you force the disk to Gen2 to dodge the above. Don't — find a Gen1-capable size instead. Query for the intersection of Gen1-capable and available sizes:
  ```bash
  az vm list-skus --location <region> --resource-type virtualMachines \
    --query "[?contains(capabilities[?name=='HyperVGenerations'].value | [0], 'V1')].name" \
    --output table
  ```
- **Agent has no public IP, activation needs HTTP reachability** → activate from something already inside the VNet where possible; only use a temporary public IP if nothing else can reach it, and remove it right after.

---


## 9. Production hardening checklist

- **Network**: private connectivity (ExpressRoute/Direct Connect) instead of public internet; DataSync via VPC PrivateLink; agent with no public IP, ever; least-privilege SG/NSG rules.
- **Encryption**: customer-managed KMS keys, TLS 1.2+ enforced, key rotation enabled.
- **IAM**: least-privilege role scoped to specific EFS/KMS/log-group ARNs only; no long-lived credentials.
- **Agent HA**: 2+ agents across fault domains; CloudWatch alarms on agent health.
- **Terraform**: remote state with locking, plan/approval gate in CI, no ad hoc applies against prod.
- **Data governance**: data classification review, formal migration runbook with rollback plan, `POINT_IN_TIME_CONSISTENT` verify mode for the real cutover, independent post-migration reconciliation audit.
- **Monitoring**: CloudWatch alarms on task failure/verification mismatch/agent offline; CloudTrail logging on all DataSync API calls.

---

## 10. Official references

- AWS DataSync overview: https://docs.aws.amazon.com/datasync/latest/userguide/what-is-datasync.html
- Transferring data to/from Azure Files: https://docs.aws.amazon.com/datasync/latest/userguide/transferring-azure-files.html
- Creating an EFS location: https://docs.aws.amazon.com/datasync/latest/userguide/create-efs-location.html
- Agent deployment automation (Azure): https://github.com/aws-samples/aws-datasync-deploy-agent-azure
- `aws_datasync_agent` Terraform resource: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/datasync_agent
- `aws_datasync_location_nfs`: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/datasync_location_nfs
- `aws_datasync_location_efs`: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/datasync_location_efs