# Setup GCP VM with Terraform

This Terraform configuration automatically creates a Google Cloud VM with an NVIDIA T4 GPU for the C247A final project. Instead of manually configuring the VM in Google Cloud Console, you can provision it by running a few commands.

## VM Specifications

| Component | Specification |
| --- | --- |
| CPU | 4 vCPUs (`n1-standard-4`) |
| RAM | 15 GiB |
| GPU | 1 NVIDIA T4 |
| Storage | 50 GB balanced persistent boot disk |
| OS | Ubuntu 22.04 Base Deep Learning VM with NVIDIA drivers included |
| Region | Taiwan (`asia-east1`), zone `asia-east1-a` by default |

## Step 1: Install Terraform

Follow the [Terraform installation instructions](https://developer.hashicorp.com/terraform/install).

## Step 2: Install Google Cloud CLI

Follow the [Google Cloud CLI installation instructions](https://docs.cloud.google.com/sdk/docs/install-sdk).

## Step 3: Configure Your Project

From the repository root, copy the example file.

```sh
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

Replace `YOUR_PROJECT_ID` in `terraform/terraform.tfvars` with your project ID. The project needs billing enabled and quota for one T4 in `asia-east1`. If the default zone is out of capacity, add `zone = "asia-east1-c"` to the same file.

## Step 4: Deploy the VM

From the repository root, sign in to Google Cloud, authorize Terraform, and enable the Compute Engine and Identity-Aware Proxy APIs.

```sh
PROJECT_ID=$(awk -F '"' '/^[[:space:]]*project_id[[:space:]]*=/ { print $2 }' terraform/terraform.tfvars)
gcloud auth login
gcloud config set project "$PROJECT_ID"
gcloud auth application-default login --project="$PROJECT_ID"
gcloud services enable compute.googleapis.com iap.googleapis.com --project="$PROJECT_ID"
```

Initialize Terraform, preview what it will create, and confirm the deployment when `apply` prompts you.

```sh
terraform -chdir=terraform init
terraform -chdir=terraform plan
terraform -chdir=terraform apply
```

## Connect to the VM

Both methods use Identity-Aware Proxy (IAP). Your account needs IAP tunnel access and an OS Login role. The VM uses an external IP for outbound downloads, and the firewall allows inbound SSH only from IAP. [Google Cloud IAP SSH guide](https://docs.cloud.google.com/compute/docs/connect/ssh-using-iap)

### Terminal SSH

Print the SSH command, then copy and run it.

```sh
terraform -chdir=terraform output -raw ssh_command
```

Run `nvidia-smi` on the VM to check the GPU. For VS Code setup, run `whoami` to get your OS Login username.

### VS Code Remote - SSH

Install the Remote - SSH extension, then connect once using terminal SSH to register your key. Add this entry to your local `~/.ssh/config`. Replace `YOUR_OS_LOGIN_USERNAME` and `YOUR_PROJECT_ID`, and use your VM's zone.

```sshconfig
Host emg2qwerty-gpu
    User YOUR_OS_LOGIN_USERNAME
    IdentityFile ~/.ssh/google_compute_engine
    ProxyCommand gcloud compute start-iap-tunnel %h %p --listen-on-stdin --project=YOUR_PROJECT_ID --zone=asia-east1-a
```

In the VS Code Command Palette, run **Remote-SSH: Connect to Host** and select `emg2qwerty-gpu`. [VS Code Remote SSH guide](https://code.visualstudio.com/docs/remote/ssh)

## Stop / Start the VM

Running the GPU VM consumes credits. Run these commands from your local terminal with the project selected in Step 4. If you set `zone = "asia-east1-c"`, use that zone in both commands.

Stop the VM when you finish working.

```sh
gcloud compute instances stop emg2qwerty-gpu --zone=asia-east1-a
```

Start it when you need it again.

```sh
gcloud compute instances start emg2qwerty-gpu --zone=asia-east1-a
```

## Delete the VM

When you are done with the project, run the command below and confirm the deletion when prompted. This deletes the VM, its boot disk, and its Terraform-managed network resources. Save any files you want to keep first.

```sh
terraform -chdir=terraform destroy
```
