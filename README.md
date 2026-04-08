# born2broot-devops

# 🏗️ Born2bRoot: Infrastructure as Code Edition
### *Automated Debian Hardening via Packer & Ansible*

This project demonstrates the transition from manual system administration to **Infrastructure as Code (IaC)**. While the 42 `born2broot` subject traditionally requires a manual installation, this repository automates the entire lifecycle—from raw ISO to a hardened, LVM-partitioned, and audited "Golden Image."

---

## 🛠️ The Tech Stack

| Component | Technology | Purpose |
| :--- | :--- | :--- |
| **Orchestrator** | **Packer** | Automates VM creation and OS installation via Preseed. |
| **Provisioner** | **Ansible** | Handles security hardening and configuration management. |
| **Virtualizer** | **VirtualBox** | The target environment for the exported VM artifact. |
| **OS** | **Debian 13 (Trixie)** | The minimal, stable base for the server. |

---

## 📐 Architecture & Lifecycle

The build process follows a coordinated **"Bake"** strategy to ensure a repeatable and immutable environment:

1. **The Seed (Preseed)**: Packer boots the Debian ISO and serves a `preseed.cfg` via an HTTP server. This automates the partitioning (LVM), user creation, and base package installation.
2. **The Hardening (Ansible)**: Once the OS reboots, Packer connects via SSH and hands over control to Ansible. Ansible applies the hardening roles (UFW, Sudoers, Password Policies).
3. **The Artifact**: Packer executes a graceful shutdown and exports the VM as an `.ovf` and `.vdi` package.

---

## 🔒 Security Hardening (The "Born2bRoot" Standard)

The Ansible `hardening` role implements the following strict security requirements:

### 1. Network & Firewall (UFW)
* **Default Policy**: Deny all incoming traffic.
* **Restricted Access**: Only Port **4242** is permitted for SSH.
* **Build Strategy**: Port 22 was temporarily permitted to allow the Ansible handshake, then programmatically closed in the final cleanup to reduce the attack surface.

### 2. Sudo & Auditing
* **TTY Enforcement**: `requiretty` is enabled to prevent non-interactive shell exploits.
* **Exemptions**: A specific exception was created for the `packer` user (`!requiretty`) to allow the automation tool to perform a graceful shutdown.
* **Logging**: All administrative actions are logged to `/var/log/sudo/sudo_config` for forensic auditing.
* **Custom Messaging**: Failed password attempts trigger a custom "Wrong password!" message.

### 3. Password Policy (`libpam-pwquality`)
* **Complexity**: Enforces a 10-character minimum, requiring uppercase, lowercase, and digits.
* **History**: Prevents password reuse (last 7 passwords).

---

## 💾 Storage Management (LVM)

To comply with the project's partitioning requirements, an **Expert Recipe** was defined in the preseed configuration to create the following Logical Volume structure:

| Partition | Size | Type | Mount Point |
| :--- | :--- | :--- | :--- |
| **sda1** | 512MB | ext4 (Primary) | `/boot` |
| **lv_root** | ~35GB | LVM Logical Volume | `/` (root) |
| **lv_swap** | 2GB | LVM Logical Volume | `swap` |

---

## 🚀 How to Reproduce the Build

To generate the identical "Golden Image" from source:

1. **Clone the repository**:
   ```bash
   git clone [https://github.com/kevshouse/born2broot-devops.git](https://github.com/kevshouse/born2broot-devops.git)
   cd born2broot-devops
2. **Initialise Plugins:**
   ```bash
   packer init packer/debian.pkr.hcl
3. **Build the Image:**
    ```bash
    ssh packer@localhost -p 4242
---
## 🧠 Key Engineering Challenges
### The "Port 4242" Hand-off
A primary challenge was migrating the SSH port from 22 to 4242 mid-build. Changing the port and restarting the service immediately would sever the Packer connection and cause a build failure.

### The Solution:
Implemented a "Stealth Migration" where Ansible updated the ```sshd_config``` but deferred the service restart. This allowed Packer to finish its tasks on port 22. Upon the first "production" boot, the system automatically initializes SSH on the required port 4242.

### The Sudo TTY Lockout
Enabling ```requiretty``` in the sudoers file for security purposes initially blocked Packer from executing the ```shutdown_command```.

### The Solution:
Integrated a specific Ansible task to inject a ```!requiretty``` default for the ```packer``` service user. This maintains high security for human users while allowing the automation pipeline to terminate gracefully.

---

## 🌐 Post-Import Configuration (Going Live)

After the build completes and the `.ovf` artifact is imported into VirtualBox, the following manual configurations are required to ensure the VM is accessible and adheres to the final security state.

### 1. Networking & Port Forwarding
By default, the VM uses a **NAT** network. To allow SSH access from the host machine to the guest, a Port Forwarding rule must be manually established:

| Setting | Value |
| :--- | :--- |
| **Protocol** | TCP |
| **Host IP** | `127.0.0.1` |
| **Host Port** | `4242` |
| **Guest IP** | (Leave Blank) |
| **Guest Port** | `4242` |

**Steps in VirtualBox GUI:**
1. Select the VM > **Settings** > **Network**.
2. Under **Adapter 1**, ensure it is attached to **NAT**.
3. Click **Advanced** > **Port Forwarding**.
4. Add a new rule using the values in the table above.

### 2. Finalizing the SSH Handover
During the build process, the SSH service was configured to listen on port **4242**, but the service was not restarted to maintain the automation tunnel. On the first "live" boot, the configuration must be refreshed.

1. Log in to the VM console.
2. Restart the SSH service:
   ```bash
   sudo systemctl restart ssh
3. Verify the service is listening on the correct port:
   ```bash
   ss -tuln | grep 4242
### 3. Production Security Audit (UFW)
   To achieve the final hardened state required for the Born2bRoot evaluation, the temporary "automation bridge" on port 22 must be closed. This ensures that port **4242** is the only entry point for remote administration.

**Execute the following inside the VM:**
```bash
  # Verify current rules
  sudo ufw status numbered

  # Delete the temporary rule for port 22
  # (Replace '1' with the actual rule number if different)
  sudo ufw delete 1

  # Confirm final status
  sudo ufw status verbose
```
### 4. Resource & Guest Additions
For optimal performance in a live environment, verify the following hardware settings in the VirtualBox Manager before starting the VM:

| Category | Setting | Recommendation |
| :--- | :--- | :--- |
| **System** | **Processor** | Ensure at least **2 CPUs** are allocated for smooth background auditing. |
| **System** | **Motherboard** | Enable **PAE/NX** to support modern kernel security features. |
| **Display** | **Screen** | Set Video Memory to at least **16MB** to prevent console flickering. |

---

## 🔍 Verification Checklist

Before considering the deployment complete and ready for evaluation, run through this final audit:

- [ ] **SSH Access**: `ssh packer@localhost -p 4242` connects successfully without a timeout.
- [ ] **Firewall Integrity**: `sudo ufw status` shows `4242/tcp ALLOW` and specifically that port **22** has been removed.
- [ ] **Audit Trail**: `sudo ls /var/log/sudo` contains the `sudo_config` file, proving administrative logging is active.
- [ ] **LVM Architecture**: `lsblk` confirms the Logical Volume partitions (root and swap) are mounted and sized correctly.
- [ ] **Password Strength**: Attempting to change a password to something simple (e.g., "123") is rejected by `libpam-pwquality`.

---

**Project status: Hardened & Verified.** 🚀
   
