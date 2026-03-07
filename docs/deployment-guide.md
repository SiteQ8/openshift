# OpenShift Secure Deployment Guide

## Prerequisites

### Infrastructure Requirements

| Component | Minimum | Recommended (Production) |
|-----------|---------|-------------------------|
| Control Plane Nodes | 3 | 3 (dedicated, multi-AZ) |
| Worker Nodes | 3 | 6+ (auto-scaled) |
| Infrastructure Nodes | 0 | 3 (dedicated) |
| PCI CDE Nodes | 0 | 2+ (dedicated, tainted) |
| vCPU per Master | 4 | 8 |
| RAM per Master | 16 GB | 32 GB |
| vCPU per Worker | 4 | 16 |
| RAM per Worker | 16 GB | 64 GB |
| Storage (etcd) | 40 GB SSD | 120 GB NVMe |
| Network | 1 Gbps | 10 Gbps |

### Software Requirements

- Red Hat OpenShift Container Platform 4.12+
- Red Hat Enterprise Linux CoreOS (RHCOS)
- `oc` CLI v4.12+
- `helm` v3.x
- `kustomize` v5.x
- HashiCorp Vault 1.12+
- Git 2.x

---

## Phase 1: Pre-Installation Security Hardening

### 1.1 Enable FIPS Mode

```yaml
# install-config.yaml
apiVersion: v1
metadata:
  name: secure-cluster
fips: true
baseDomain: enterprise.example.com
compute:
  - name: worker
    replicas: 3
    hyperthreading: Enabled
controlPlane:
  name: master
  replicas: 3
networking:
  networkType: OVNKubernetes
  clusterNetwork:
    - cidr: 10.128.0.0/14
      hostPrefix: 23
  serviceNetwork:
    - 172.30.0.0/16
platform:
  # Configure per your cloud provider
```

### 1.2 Configure Disk Encryption

```yaml
# MachineConfig for LUKS encryption
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  name: worker-luks-encryption
  labels:
    machineconfiguration.openshift.io/role: worker
spec:
  config:
    ignition:
      version: 3.2.0
    storage:
      luks:
        - name: root
          device: /dev/disk/by-partlabel/root
          clevis:
            tang:
              - url: https://tang.enterprise.example.com
                thumbprint: <TANG_THUMBPRINT>
```

---

## Phase 2: Post-Installation Hardening

### 2.1 Apply Security Context Constraints

```bash
# Apply restrictive SCCs
oc apply -f hardening/scc-profiles.yaml

# Verify no pods run as privileged
oc get pods --all-namespaces -o json | \
  jq '.items[] | select(.spec.containers[].securityContext.privileged==true) | .metadata.name'
```

### 2.2 Configure Authentication

```bash
# Apply OAuth configuration
oc apply -f rbac/oauth-config.yaml

# Remove default kubeadmin
oc delete secret kubeadmin -n kube-system
```

### 2.3 Enable etcd Encryption

```bash
# Apply encryption configuration
oc apply -f hardening/etcd-encryption.yaml

# Monitor encryption migration
oc get openshiftapiserver -o=jsonpath='{range .items[0].status.conditions[?(@.type=="Encrypted")]}{.reason}{"\n"}{.message}{"\n"}'
```

---

## Phase 3: Network Security Setup

### 3.1 Default Deny All

```bash
# Apply default deny policies to all namespaces
oc apply -f policies/network-policies.yaml
```

### 3.2 Deploy Service Mesh

```bash
# Install Operators
oc apply -f network/service-mesh.yaml

# Verify mTLS enforcement
oc get peerauthentication --all-namespaces
```

### 3.3 Configure Egress Controls

```bash
# Apply egress firewall rules
oc apply -f network/egress-firewall.yaml
```

---

## Phase 4: PCI CDE Environment Setup

### 4.1 Create Dedicated CDE Namespace

```bash
# Create and configure PCI CDE namespace
oc apply -f pci-dss/cde-namespace.yaml

# Verify isolation
oc describe namespace pci-cde
```

### 4.2 Taint CDE Nodes

```bash
# Taint dedicated PCI nodes
oc adm taint nodes <node-name> pci-cde=true:NoSchedule

# Label PCI nodes
oc label nodes <node-name> node-role.kubernetes.io/pci-cde=true
```

---

## Phase 5: Monitoring & Compliance

### 5.1 Deploy Security Monitoring

```bash
# Apply Prometheus alerting rules
oc apply -f monitoring/prometheus-rules.yaml

# Deploy Falco
oc apply -f monitoring/falco-rules.yaml

# Configure audit policy
oc apply -f monitoring/audit-policy.yaml
```

### 5.2 Run Initial Compliance Scan

```bash
# Execute compliance check
chmod +x scripts/compliance-check.sh
./scripts/compliance-check.sh

# Review results
cat /tmp/openshift-compliance-report.txt
```

---

## Phase 6: CI/CD Pipeline Security

### 6.1 Deploy Secure Pipeline

```bash
# Install Tekton pipeline
oc apply -f ci-cd/tekton-pipeline.yaml

# Configure ArgoCD
oc apply -f ci-cd/argocd-config.yaml

# Setup image signing
oc apply -f ci-cd/image-signing.yaml
```

---

## Validation Checklist

- [ ] FIPS mode enabled on all nodes
- [ ] etcd encryption verified
- [ ] kubeadmin removed
- [ ] LDAP/OIDC authentication working
- [ ] MFA enforced for all users
- [ ] Default deny NetworkPolicies in all namespaces
- [ ] Service mesh with mTLS operational
- [ ] Egress firewall rules applied
- [ ] PCI CDE namespace isolated with dedicated nodes
- [ ] Prometheus alerting configured
- [ ] Falco runtime detection active
- [ ] Audit logging enabled and forwarded
- [ ] CI/CD pipeline with image scanning operational
- [ ] Backup and DR procedures tested
- [ ] Compliance scan passing

---

*Document Version: 2.0 | Last Updated: March 2026 | Author: Ali AlEnezi*
