# Kubernetes Templates

This directory contains reusable Kubernetes manifest templates used by Ansible playbooks.

## Purpose

Instead of defining Kubernetes resources inline within Ansible playbooks using the `definition:` parameter, all manifests are stored as separate template files. This approach provides:

- **Better organization**: All Kubernetes manifests in one place
- **Easier maintenance**: Edit manifests without touching playbook logic
- **Reusability**: Same templates can be used across multiple playbooks
- **Version control**: Track changes to manifests separately from automation logic
- **Standard format**: `.yml` files that can be validated with `kubectl --dry-run`

## Template Format

Templates use Jinja2 syntax for variable substitution:

```yaml
---
apiVersion: v1
kind: Namespace
metadata:
  name: {{ namespace_name }}
  labels:
    name: {{ namespace_name }}
```

Variables are passed from Ansible playbooks via the `vars:` section.

## Available Templates

### Infrastructure

- **namespace.yml** - Generic namespace template
  - Variables: `namespace_name`
  - Used by: `setup-infra-node.yml`, `setup-apps-node.yml`, `infisical_integration` role

### MetalLB

- **metallb-ipaddresspool.yml** - MetalLB IP address pool configuration
  - Variables: `metallb_ip_range`
  - Used by: `setup-infra-node.yml`

- **metallb-l2advertisement.yml** - MetalLB L2 advertisement configuration
  - Used by: `setup-infra-node.yml`

### cert-manager

- **cert-manager-clusterissuer.yml** - Let's Encrypt ClusterIssuer
  - Variables: `acme_email`
  - Used by: `setup-infra-node.yml`

### Secrets

- **registry-auth-secret.yml** - Docker Registry authentication secret
  - Variables: `registry_htpasswd`, `registry_password`, `docker_hub_username`
  - Used by: `setup-infra-node.yml`

- **infisical-secrets.yml** - Infisical application secrets
  - Variables: `infisical_encryption_key`, `infisical_auth_secret`, `infisical_db_password`
  - Used by: `setup-infra-node.yml`

### ConfigMaps

- **infrastructure-configmap.yml** - Infrastructure configuration
  - Variables: `infra_domain`, `registry_domain`, `infisical_domain`, `team_name`, `version`
  - Used by: `setup-infra-node.yml`

## Usage in Ansible

### Basic Example

```yaml
- name: Create namespace
  kubernetes.core.k8s:
    state: present
    template: "{{ playbook_dir }}/../../global/kubernetes-templates/namespace.yml"
  vars:
    namespace_name: my-namespace
```

### With Additional Parameters

```yaml
- name: Create infrastructure namespace
  kubernetes.core.k8s:
    state: present
    template: "{{ playbook_dir }}/../../global/kubernetes-templates/namespace.yml"
  delegate_to: localhost
  become: false
  environment:
    KUBECONFIG: /tmp/infra-kubeconfig
  vars:
    namespace_name: infrastructure
```

## Path Resolution

From Ansible playbooks in `ansible/playbooks/`:
```yaml
template: "{{ playbook_dir }}/../../global/kubernetes-templates/template-name.yml"
```

From Ansible roles in `ansible/roles/*/tasks/`:
```yaml
template: "{{ playbook_dir }}/../../global/kubernetes-templates/template-name.yml"
```

Note: Always use `playbook_dir` for consistent path resolution.

## Adding New Templates

1. Create template file in this directory with `.yml` extension
2. Use Jinja2 syntax for variables: `{{ variable_name }}`
3. Update this README with template documentation
4. Update playbooks to use the template instead of inline `definition:`

## Testing Templates

Test template rendering locally:

```bash
# Render template with ansible
ansible all -i "localhost," -c local -m template \
  -a "src=global/kubernetes-templates/namespace.yml dest=/tmp/test.yml" \
  -e "namespace_name=test"

# Validate with kubectl
kubectl apply --dry-run=client -f /tmp/test.yml
```

## Migration from Inline Definitions

**Before** (inline definition):
```yaml
- name: Create namespace
  kubernetes.core.k8s:
    state: present
    definition:
      apiVersion: v1
      kind: Namespace
      metadata:
        name: infrastructure
```

**After** (template):
```yaml
- name: Create namespace
  kubernetes.core.k8s:
    state: present
    template: "{{ playbook_dir }}/../../global/kubernetes-templates/namespace.yml"
  vars:
    namespace_name: infrastructure
```

## Notes

- All templates use standard YAML format (not `.j2` extension)
- Templates are processed by Ansible's Jinja2 engine before being applied to Kubernetes
- Variables must be defined either in playbook `vars:`, role `defaults/`, or passed via `-e` flag
- Templates follow Kubernetes API conventions and can be validated with `kubectl`
