#!/bin/bash

# Define user to create
var_username=ansible

# Create new user
sudo useradd -m -s /bin/bash ${var_username}

# Copy Ansible SSH pub
sudo /usr/bin/mkdir /home/${var_username}/.ssh
sudo /usr/bin/chmod 700 /home/${var_username}/.ssh
sudo /usr/bin/echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOb9RNnRbyNZbTGGcX2wm0qvURoOKh80FBmipmUah433 ansible@krathwohl.io" > /home/${var_username}/.ssh/authorized_keys
sudo /usr/bin/chmod 600 /home/${var_username}/.ssh/authorized_keys
sudo /usr/bin/chown -R ${var_username}:${var_username} /home/${var_username}/.ssh

# Allow user to sudo with NOPASSWD
sudo /usr/bin/echo "${var_username} ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/010_${var_username}-nopasswd
sudo /usr/bin/chmod 0440 /etc/sudoers.d/010_${var_username}-nopasswd

#
# Test after running
# ansible -i [HOST_IP], all -m ping -u ansible --private-key=~/.ssh/ansible_id_rsa
#