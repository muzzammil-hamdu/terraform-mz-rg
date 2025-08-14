
# Windows VM on Azure with Java, Teams, and Chrome (Terraform Cloud)

This project provisions a Windows Server 2022 VM on Azure and installs **Java JDK 21**, **Microsoft Teams**, and **Google Chrome** automatically via the **Custom Script Extension**.

## Terraform Cloud Setup
- **Organization:** `trm-mz`
- **Workspace:** `terraform-mz-rg`
- Backend is preconfigured in `main.tf`.

### Workspace Variables (set these in app.terraform.io → Workspace → Variables)
Set the following **Environment Variables** (type: Environment):
- `ARM_CLIENT_ID`
- `ARM_CLIENT_SECRET` (sensitive)
- `ARM_TENANT_ID`
- `ARM_SUBSCRIPTION_ID`

Set the following **Terraform Variables** (type: Terraform):
- `admin_password` (mark **Sensitive**).  
  Optionally override: `resource_group_name`, `location`, `vm_name`, `vm_size`, `admin_username`.

> ⚠️ Do not commit secrets to version control. Using workspace variables keeps them secure.

## Run
1. Push this folder to a Git repo and connect it to the Terraform Cloud workspace `terraform-mz-rg`.
2. In Terraform Cloud, click **New run** → **Plan & Apply**.
3. When the run finishes, view the **Outputs** tab to get `public_ip_address`.
4. Connect with RDP: `mstsc` → IP → username `mujju` and the password you set.

## Notes
- NSG allows inbound **RDP (3389)** only.
- Software installs happen once the VM is up, via the VM Agent + Custom Script Extension.
- If any download source temporarily fails, the script retries and also falls back to Chocolatey for Teams/Chrome.
