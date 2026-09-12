
# Ansible Control Server and Worker Node Setup

> **Important:** Ansible is normally installed only on the **control server**. You do not need to install Ansible on the worker nodes.
>
> Worker nodes generally need **SSH access** and **Python** for most Ansible modules.

## Architecture

```text
                    CONTROL NODE
                     srv1128015
                    ansible user
                         |
                         | SSH
       +-----------------+-----------------+
       |                 |                 |
       v                 v                 v
   Worker 1          Worker 2          Worker 3
   Hostinger         Hostinger         Hostinger
   VPS               VPS               VPS
````

---

## 1. Control Server

Our Ansible control server is:

```text
srv1128015
```

The current user is:

```text
ansible@srv1128015
```

### Install Ansible

Run the following commands on the control server:

```bash
sudo apt update
sudo apt install -y ansible
```

Check the installation:

```bash
ansible --version
```

Example output:

```text
ansible [core ...]
  python version = ...
```

### Install `sshpass`

`sshpass` is required only if you want to use SSH password authentication with Ansible.

```bash
sudo apt install -y sshpass
```

Verify:

```bash
sshpass -V
```

Example:

```text
sshpass 1.09
```

> **Note:** `sshpass` is installed on the **control server**, not on the worker nodes.

---

# 2. Why Ansible Is Not Installed on Worker Nodes

You do **not** need to run:

```bash
sudo apt install ansible
```

on every worker.

Ansible works approximately like this:

```text
Control Server
     |
     | Sends modules/tasks over SSH
     v
Worker Server
     |
     | Executes the task
     v
Result returned to Control Server
```

Therefore:

| Component  |                         Control Server |              Worker Server |
| ---------- | -------------------------------------: | -------------------------: |
| Ansible    |                             ✅ Required |             ❌ Not required |
| SSH Client |                             ✅ Required | ❌ Not required for Ansible |
| SSH Server |             ❌ Not required for Ansible |                 ✅ Required |
| Python 3   |                 ✅ Required/recommended |     ✅ Required/recommended |
| `sshpass`  | ✅ Required for password authentication |             ❌ Not required |

---

# 3. Prepare Each Worker Node

For each Hostinger VPS, log in using its root credentials.

Example:

```bash
ssh root@62.72.31.140
```

Once logged into the worker:

### Update the server

```bash
apt update
```

### Install Python

```bash
apt install -y python3
```

Check the Python version:

```bash
python3 --version
```

### Check SSH Server

```bash
systemctl status ssh
```

The SSH service should be active.

If SSH is not installed or running:

```bash
apt install -y openssh-server
systemctl enable --now ssh
```

At this point, the worker has the basic requirements for Ansible.

---

# 4. Create an Ansible User

You can initially use `root`, but for a proper production setup it is recommended to create a dedicated `ansible` user.

Run the following commands on each worker:

```bash
adduser ansible
```

Add the user to the `sudo` group:

```bash
usermod -aG sudo ansible
```

Verify:

```bash
id ansible
```

You should see `sudo` in the user's groups.

### Why use an `ansible` user?

Instead of:

```text
Ansible
   |
   v
 root
```

use:

```text
Ansible
   |
   v
 ansible user
   |
   v
 sudo
   |
   v
 root privileges
```

This is safer and easier to manage than using root directly.

---

# 5. SSH Authentication

Ansible needs an SSH connection from the control server to each worker.

```text
Control Server
      |
      | SSH
      v
Worker Server
```

There are two common authentication methods.

---

## Option A: SSH Password Authentication

You can currently use:

```bash
ansible -i inventory.ini all_clients -m ping --ask-pass
```

Ansible asks for the SSH password.

This requires `sshpass` on the control server:

```bash
sudo apt install -y sshpass
```

The worker does **not** need `sshpass`.

Example successful workers:

```text
Vinayaka        ✅
BCG             ✅
Vaishnavi Gems  ✅
```

---

# 6. Recommended: SSH Key Authentication

For production, SSH keys are recommended instead of passwords.

Generate an SSH key on the control server:

```bash
ssh-keygen -t ed25519
```

Press `Enter` to accept the default location:

```text
/home/ansible/.ssh/id_ed25519
```

This creates:

```text
~/.ssh/id_ed25519
~/.ssh/id_ed25519.pub
```

### Important

The private key:

```text
~/.ssh/id_ed25519
```

must remain on the control server.

The public key:

```text
~/.ssh/id_ed25519.pub
```

is copied to the worker server.

---

# 7. Copy the SSH Key to a Worker

Example:

```bash
ssh-copy-id ansible@62.72.31.140
```

Enter the `ansible` user's password once.

Then test:

```bash
ssh ansible@62.72.31.140
```

You should be able to log in without entering a password.

Repeat this process for every worker.

---

# 8. Configure `known_hosts`

The control server should know and trust the SSH host keys of the workers.

Create the SSH directory:

```bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh
```

Create the `known_hosts` file:

```bash
touch ~/.ssh/known_hosts
chmod 600 ~/.ssh/known_hosts
```

Add worker server fingerprints:

```bash
ssh-keyscan -H 62.72.31.140 >> ~/.ssh/known_hosts
ssh-keyscan -H 82.112.230.56 >> ~/.ssh/known_hosts
ssh-keyscan -H 82.112.230.97 >> ~/.ssh/known_hosts
```

Repeat for the remaining worker IP addresses.

### `known_hosts` vs SSH authentication

These are two different things:

```text
known_hosts
    |
    v
"Do I trust this server identity?"
```

and:

```text
SSH key / password
    |
    v
"Am I allowed to log in to this server?"
```

---

# 9. Create the Ansible Inventory

On the control server:

```bash
mkdir -p ~/ansible
cd ~/ansible
```

Create the inventory file:

```bash
nano inventory.ini
```

Example inventory:

```ini
[all_clients]
modi_ornaments_server
sandeep_jadhav_server
swaroopjewellers_server
nyra_jeweller_server
shubhsilverjewellery_server
vinayaka_jewels_server
bcg_server
vaishnavigems_server


[modi_ornaments]
modi_ornaments_server ansible_host=193.203.163.230 ansible_user=ansible

[sandeep_jadhav]
sandeep_jadhav_server ansible_host=200.234.44.54 ansible_user=ansible

[swaroopjewellers]
swaroopjewellers_server ansible_host=187.127.177.148 ansible_user=ansible

[nyra_jeweller]
nyra_jeweller_server ansible_host=200.234.46.35 ansible_user=ansible

[shubhsilverjewellery]
shubhsilverjewellery_server ansible_host=187.127.146.127 ansible_user=ansible

[vinayaka_jewels]
vinayaka_jewels_server ansible_host=62.72.31.140 ansible_user=ansible

[bcg]
bcg_server ansible_host=82.112.230.56 ansible_user=ansible

[vaishnavigems]
vaishnavigems_server ansible_host=82.112.230.97 ansible_user=ansible
```

Once SSH key authentication is configured, this inventory is sufficient for normal operation.

---

# 10. Understand the Inventory Structure

For example:

```ini
vinayaka_jewels_server ansible_host=62.72.31.140 ansible_user=ansible
```

means:

```text
vinayaka_jewels_server
        |
        +-- Ansible hostname
        |
        +-- ansible_host=62.72.31.140
        |      Actual VPS IP address
        |
        +-- ansible_user=ansible
               SSH login user
```

The `[all_clients]` group contains all workers.

The individual groups allow client-wise management.

---

# 11. Test Worker Connectivity

Test one worker first:

```bash
ansible -i inventory.ini vinayaka_jewels -m ping
```

Expected output:

```text
vinayaka_jewels_server | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
```

Then test all workers:

```bash
ansible -i inventory.ini all_clients -m ping
```

Expected result:

```text
modi_ornaments_server        | SUCCESS
sandeep_jadhav_server        | SUCCESS
swaroopjewellers_server      | SUCCESS
nyra_jeweller_server         | SUCCESS
shubhsilverjewellery_server  | SUCCESS
vinayaka_jewels_server       | SUCCESS
bcg_server                   | SUCCESS
vaishnavigems_server         | SUCCESS
```

---

# 12. Use `sudo` with the Ansible User

Because the `ansible` user is not root, use privilege escalation when installing or modifying system packages.

Example:

```bash
ansible -i inventory.ini all_clients -m apt \
  -a "update_cache=yes" \
  -b
```

Here:

```text
-b
```

means:

```text
Become root using sudo
```

### Install Git

```bash
ansible -i inventory.ini all_clients -m apt \
  -a "name=git state=present" \
  -b
```

Check Git:

```bash
ansible -i inventory.ini all_clients \
  -m command \
  -a "git --version"
```

---

# 13. Install Docker and Docker Compose

Once worker connectivity is working, Ansible can configure all VPS servers from the control server.

For example:

```text
Ansible Control Server
        |
        +---- Modi Ornaments
        +---- Sandeep Jadhav
        +---- Swaroop Jewellers
        +---- Nyra Jeweller
        +---- Shubh Silver Jewellery
        +---- Vinayaka Jewels
        +---- BCG
        +---- Vaishnavi Gems
```

A playbook can install:

```text
Docker
Docker Compose
Nginx
Git
PostgreSQL
Node.js
Python
Certbot
and other required software
```

This avoids manually logging into every VPS.

---

# 14. Check Docker on All Workers

After Docker installation:

```bash
ansible -i inventory.ini all_clients \
  -m command \
  -a "docker --version"
```

Check Docker Compose:

```bash
ansible -i inventory.ini all_clients \
  -m command \
  -a "docker compose version"
```

---

# 15. Run a Script on All Workers

Suppose you have:

```text
compose.sh
```

on your control server.

Copy it to all workers:

```bash
ansible -i inventory.ini all_clients -m copy \
  -a "src=compose.sh dest=/tmp/compose.sh mode=0755"
```

Execute it:

```bash
ansible -i inventory.ini all_clients -m shell \
  -a "/tmp/compose.sh" \
  -b
```

Verify Docker and Compose:

```bash
ansible -i inventory.ini all_clients -m shell \
  -a "docker --version && docker compose version"
```

---

# 16. Client-Wise Management

One of the main advantages of this inventory structure is that you can manage each client separately.

### All clients

```bash
ansible -i inventory.ini all_clients -m ping
```

### Vinayaka Jewels

```bash
ansible -i inventory.ini vinayaka_jewels -m ping
```

### BCG

```bash
ansible -i inventory.ini bcg -m ping
```

### Modi Ornaments

```bash
ansible -i inventory.ini modi_ornaments -m ping
```

### Shubh Silver Jewellery

```bash
ansible -i inventory.ini shubhsilverjewellery -m ping
```

---

# 17. Proper Production Directory Structure

For a larger environment, use a structured Ansible project:

```text
ansible/
├── ansible.cfg
├── inventory/
│   ├── production.ini
│   └── group_vars/
│
├── playbooks/
│   ├── setup-users.yml
│   ├── docker.yml
│   ├── nginx.yml
│   └── postgres.yml
│
└── roles/
    ├── docker/
    ├── nginx/
    └── postgres/
```

Run a playbook with:

```bash
ansible-playbook \
  -i inventory/production.ini \
  playbooks/docker.yml
```

You can target:

```text
all_clients
```

or an individual client group:

```text
vinayaka_jewels
bcg
modi_ornaments
```

---

# 18. Recommended Production Architecture

```text
                         ANSIBLE CONTROL SERVER
                              srv1128015
                                  |
                         SSH Key Authentication
                                  |
              +-------------------+-------------------+
              |         |         |         |          |
              v         v         v         v          v
            Modi     Sandeep   Swaroop     Nyra      Shubh
              |         |         |         |          |
              +---------+---------+---------+----------+
                                  |
                    +-------------+-------------+
                    |                           |
                    v                           v
                Vinayaka                      BCG
                    |
                    v
                Vaishnavi
```

---

# 19. Final Checklist

## Control Server

```text
[ ] Ansible installed
[ ] SSH client available
[ ] sshpass installed if using passwords
[ ] SSH key generated
[ ] known_hosts configured
[ ] inventory.ini created
```

## Worker Nodes

```text
[ ] SSH server installed and running
[ ] Python 3 installed
[ ] ansible user created
[ ] ansible user has sudo access
[ ] SSH public key added
```

## Connectivity

```bash
ansible -i inventory.ini all_clients -m ping
```

Expected:

```text
all workers | SUCCESS | pong
```

Once this works, the infrastructure is ready for centralized Ansible automation.

```

