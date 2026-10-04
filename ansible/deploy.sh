#!/usr/bin/env bash
set -euo pipefail

echo "=== Installing Ansible collections ==="

ansible-galaxy collection install -r collections/requirements.yml

echo
echo "=== Deploying project ==="

ansible-playbook playbook.yml

echo
echo "=== Deployment completed successfully ==="
