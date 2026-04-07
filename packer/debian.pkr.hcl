packer {
  required_plugins {
    virtualbox = {
      version = ">= 1.0.5"
      source  = "github.com/hashicorp/virtualbox"
    }
    ansible = {
      version = ">= 1.1.2"
      source  = "github.com/hashicorp/ansible"
    }
  }
}

variable "ssh_password" {
  type    = string
  default = "packer" # Change this for production!
}

source "virtualbox-iso" "debian-base" {
  guest_os_type        = "Debian_64"
  # Updated URL for Debian 13.4.0 Trixie
  iso_url      = "https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-13.4.0-amd64-netinst.iso"
  
 # Updated Checksum for 13.4.0 (amd64 netinst)
  iso_checksum = "sha256:0b813535dd76f2ea96eff908c65e8521512c92a0631fd41c95756ffd7d4896dc"
  
  ssh_username         = "packer"
  ssh_password         = var.ssh_password
  ssh_timeout          = "30m"
  ssh_handshake_attempts = "100"
  ssh_port = 22
  cpus                 = 2
  memory               = 2048
  headless             = false
  
  # This fixes the Warning: Packer will now shut down the VM cleanly
  shutdown_command     = "echo '${var.ssh_password}' | sudo -S -t /sbin/shutdown -h now"

  boot_command = [
    "<esc><wait>",
    "install auto=true ",
    "priority=critical ",
    "preseed/url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/preseed.cfg ",
    "<enter>"
  ]
  
  http_directory = "packer/http"
}
build {
  sources = ["source.virtualbox-iso.debian-base"]

  # 1. Hand off to Ansible to do the heavy lifting (Security/Hardening)
  provisioner "ansible" {
    playbook_file   = "ansible/site.yml"
    user            = "packer"
    use_proxy       = false
    
    # Replace your old extra_arguments with this new list:
    extra_arguments = [
      "--extra-vars", "ansible_sudo_pass=${var.ssh_password}",
      "--extra-vars", "ansible_password=${var.ssh_password}",
      "--ssh-extra-args", "-o IdentitiesOnly=yes -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
    ]
  }

  # 2. Final message before shutdown
  provisioner "shell" {
    inline = ["echo 'Hardening Complete. Exporting Image...'"]
  }
}