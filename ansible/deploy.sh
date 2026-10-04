#!/usr/bin/env bash
set -euo pipefail

echo "=== Checking Ansible ==="

if ! command -v ansible-playbook >/dev/null 2>&1; then
    echo "Ansible not found. Installing..."

    sudo apt-get update
    sudo apt-get install -y ansible
fi

echo
echo "=== Installing Ansible collections ==="

ansible-galaxy collection install -r collections/requirements.yml

echo
echo "=== Deploying project ==="

ansible-playbook playbook.yml

echo
echo "=== Deployment completed successfully ==="
