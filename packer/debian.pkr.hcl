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
  ssh_port = 22 # We stay on port 22 just for the build
  cpus                 = 2
  memory               = 2048
  headless             = false
  
  # The standard shutdown command now works because of the !requiretty fix in Ansible
  shutdown_command = "echo '${var.ssh_password}' | sudo -S /sbin/shutdown -h now"

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

  provisioner "ansible" {
    playbook_file   = "ansible/site.yml"
    user            = "packer"
    use_proxy       = false
    
    extra_arguments = [
      "--extra-vars", "ansible_sudo_pass=${var.ssh_password}",
      "--extra-vars", "ansible_password=${var.ssh_password}",
      "--ssh-extra-args", "-o IdentitiesOnly=yes -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
    ]
  }
  
  # The shell provisioner is removed to prevent the handshake timeout error
}
