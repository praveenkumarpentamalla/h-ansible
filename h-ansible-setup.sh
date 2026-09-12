Yes. The most important concept first:

**Ansible is normally installed only on the control server. You do not install Ansible on the worker nodes.**

The workers only need SSH access and Python for most Ansible modules.

Your setup should look like:

```text
                    CONTROL NODE
                srv1128015
              ansible user
                    |
                    | SSH
       +------------+------------+
       |            |            |
       v            v            v
   Worker 1     Worker 2     Worker 3
   Hostinger    Hostinger    Hostinger
   VPS          VPS          VPS
```

## 1. Control server

Your control server is:

```text
srv1128015
```

You are already using:

```text
ansible@srv1128015
```

### Install Ansible

On the control server:

```bash
sudo apt update
sudo apt install -y ansible
```

Check:

```bash
ansible --version
```

You should see something similar to:

```text
ansible [core ...]
  python version = ...
```

Also install SSH/password helper if you want to initially use passwords:

```bash
sudo apt install -y sshpass
```

Verify:

```bash
sshpass -V
```

You already completed this part.

---

# 2. Why Ansible is not installed on workers

You do **not** need to run:

```bash
sudo apt install ansible
```

on every worker.

Ansible works approximately like this:

```text
Control Server
     |
     | sends Python/modules over SSH
     v
Worker Server
     |
     | executes task
     v
Result returned to Control Server
```

Therefore:

```text
Control server:
Ansible      ✅
sshpass      ✅ optional, for password SSH
SSH client   ✅

Worker:
Ansible      ❌ not required
SSH server   ✅ required
Python       ✅ recommended/usually required
```

---

# 3. Prepare each worker node

For each Hostinger VPS, log in using the root credentials.

For example:

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

Check:

```bash
python3 --version
```

### Check SSH server

```bash
systemctl status ssh
```

It should be active.

If not:

```bash
apt install -y openssh-server
systemctl enable --now ssh
```

That's basically all Ansible needs on the worker.

---

# 4. Create an Ansible user — recommended

You can initially use `root`, as you're doing now, but for a proper setup I recommend creating an `ansible` user on each worker.

On every worker:

```bash
adduser ansible
```

Then give it sudo privileges:

```bash
usermod -aG sudo ansible
```

Verify:

```bash
id ansible
```

You should see `sudo` in the groups.

### Why create `ansible`?

Instead of:

```text
Ansible → root
```

you can use:

```text
Ansible → ansible user → sudo
```

This is a safer and more standard setup.

---

# 5. SSH authentication

This is the most important part.

Ansible needs to connect from:

```text
control server
```

to:

```text
worker server
```

You have two approaches.

## Option A — SSH password

You are currently doing:

```bash
ansible -i inventory.ini all_clients -m ping --ask-pass
```

This requires:

```text
sshpass
```

on the control server.

The worker does **not** need `sshpass`.

Your current successful servers prove this works:

```text
Vinayaka        ✅
BCG             ✅
Vaishnavi Gems  ✅
```

---

# 6. Recommended: SSH key authentication

For production, use SSH keys instead of passwords.

On the control server:

```bash
ssh-keygen -t ed25519
```

Press Enter to accept the default location:

```text
/home/ansible/.ssh/id_ed25519
```

You'll get:

```text
~/.ssh/id_ed25519
~/.ssh/id_ed25519.pub
```

The private key stays on the control server.

The public key goes to the worker.

---

# 7. Copy SSH key to worker

For example:

```bash
ssh-copy-id ansible@62.72.31.140
```

Enter the `ansible` user's password once.

Then test:

```bash
ssh ansible@62.72.31.140
```

You should be able to log in without a password.

Repeat for every worker.

---

# 8. `known_hosts`

The control server should also know the SSH host keys of the workers.

Create the directory:

```bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh
touch ~/.ssh/known_hosts
chmod 600 ~/.ssh/known_hosts
```

Add servers:

```bash
ssh-keyscan -H 62.72.31.140 >> ~/.ssh/known_hosts
ssh-keyscan -H 82.112.230.56 >> ~/.ssh/known_hosts
ssh-keyscan -H 82.112.230.97 >> ~/.ssh/known_hosts
```

And your other worker IPs.

This is separate from authentication.

Think of it as:

```text
known_hosts
    ↓
"Do I trust this server identity?"

SSH key/password
    ↓
"Can I log in to this server?"
```

---

# 9. Create inventory

On your control server:

```bash
mkdir -p ~/ansible
cd ~/ansible
```

Create:

```bash
nano inventory.ini
```

For your current environment:

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

Once you're ready to use SSH keys, this is all you need.

---

# 10. Test worker connectivity

Start with one:

```bash
ansible -i inventory.ini vinayaka_jewels -m ping
```

Expected:

```text
vinayaka_jewels_server | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
```

Then:

```bash
ansible -i inventory.ini all_clients -m ping
```

Expected:

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

# 11. Because `ansible` user is not root

When you use:

```bash
ansible_user=ansible
```

and want to install software, use privilege escalation:

```bash
ansible -i inventory.ini all_clients -m apt \
  -a "update_cache=yes" \
  -b
```

`-b` means **become root using sudo**.

For example, install Git:

```bash
ansible -i inventory.ini all_clients -m apt \
  -a "name=git state=present" \
  -b
```

Check Git:

```bash
ansible -i inventory.ini all_clients -m command -a "git --version"
```

---

# 12. Install Docker on workers

Once connectivity is working, Ansible can configure every VPS.

For example:

```text
Ansible control server
        |
        +---- Modi
        +---- Sandeep
        +---- Swaroop
        +---- Nyra
        +---- Shubh Silver
        +---- Vinayaka
        +---- BCG
        +---- Vaishnavi
```

Then one playbook can install:

```text
Docker
Docker Compose
Nginx
Git
PostgreSQL
Node.js
Python
Certbot
etc.
```

You don't have to manually log into every VPS.

---

# 13. Proper production setup

For your use case, I would build it like this:

```text
ansible/
├── ansible.cfg
├── inventory/
│   ├── production.ini
│   └── group_vars/
├── playbooks/
│   ├── setup-users.yml
│   ├── docker.yml
│   ├── nginx.yml
│   └── postgres.yml
└── roles/
    ├── docker/
    ├── nginx/
    └── postgres/
```

Then:

```bash
ansible-playbook -i inventory/production.ini playbooks/docker.yml
```

And you can target:

```text
all_clients
```

or a specific client:

```text
vinayaka_jewels
bcg
modi_ornaments
```

---
