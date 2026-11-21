# Google Cloud GPU VM

Terraform creates one `n1-standard-4` instance with 4 vCPUs, 15 GiB of RAM, one NVIDIA T4, and a 50 GB balanced persistent boot disk. It defaults to `asia-east1-a` in Taiwan. The VM has a public IPv4 address and accepts HTTP and HTTPS on TCP ports 80 and 443. SSH uses Identity-Aware Proxy and OS Login.

## Boot image

Set `TF_VAR_boot_image` to the full resource path of a bootable Deep Learning VM M129 image with Debian 11 and Python 3.10. If your team preserved M129 as a custom Compute Engine image, use `projects/IMAGE_PROJECT/global/images/IMAGE_NAME`. The Terraform identity needs access to the image, and the image must fit on a 50 GB disk.

Google lists April 1, 2026 as the end of availability for its Debian 11 and Python 3.10 CUDA 12.4 base image. Exact M129 deployment requires a bootable copy if the public image has been retired. See the [M129 release notes](https://docs.cloud.google.com/deep-learning-vm/docs/release-notes#April_16_2025), [image catalog](https://docs.cloud.google.com/deep-learning-vm/docs/images#base_versions), and [image availability policy](https://docs.cloud.google.com/deep-learning-vm/docs/framework-support-policy#support_policy_schedule).

## Create the VM

Use a project with billing enabled, available T4 quota in `asia-east1`, and permission to create Compute Engine instances and VPC resources. From the repository root, replace the placeholders and run the following commands. If the APIs are already enabled, skip the `gcloud services enable` command.

```sh
export TF_VAR_project_id='YOUR_PROJECT_ID'
export TF_VAR_boot_image='projects/IMAGE_PROJECT/global/images/IMAGE_NAME'

gcloud auth login
gcloud auth application-default login --project="$TF_VAR_project_id"
gcloud services enable compute.googleapis.com iap.googleapis.com --project="$TF_VAR_project_id"

terraform -chdir=terraform init
terraform -chdir=terraform apply
```

If `asia-east1-a` has no T4 capacity, set `export TF_VAR_zone=asia-east1-c` before retrying. Both zones offer N1 VMs with T4s. [Google Cloud GPU locations](https://docs.cloud.google.com/compute/docs/regions-zones/gpu-regions-zones)

## Connect and verify

Get the public IP with `terraform -chdir=terraform output -raw external_ip`. For SSH, run the command printed by `terraform -chdir=terraform output -raw ssh_command`. Your Google Cloud identity needs IAP tunnel access and an OS Login role. After first boot, allow the NVIDIA driver installation to complete, then run `nvidia-smi` and `python3 --version` on the VM. [IAP setup](https://docs.cloud.google.com/iap/docs/using-tcp-forwarding), [Deep Learning VM setup](https://docs.cloud.google.com/deep-learning-vm/docs/cli)

Run `terraform -chdir=terraform destroy` with the same inputs when you are finished. This also deletes the boot disk.
