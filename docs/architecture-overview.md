# OpenShift Enterprise Secure Architecture - Detailed Overview

## 1. Architecture Principles

### 1.1 Zero Trust Model
Every request is authenticated, authorized, and encrypted regardless of origin. No implicit trust is granted based on network location, user identity, or device status.

**Core Tenets:**
- Never trust, always verify
- Assume breach mentality
- Least privilege access
- Microsegmentation everywhere
- Continuous verification and monitoring

### 1.2 Defense in Depth (7 Layers)

```
Layer 7 ─ Application Security    → WAF, RASP, Input Validation
Layer 6 ─ Container Security      → Image Scanning, Runtime Protection
Layer 5 ─ Orchestration Security  → RBAC, PSP/SCC, Admission Control
Layer 4 ─ Network Security        → NetworkPolicy, mTLS, Egress Control
Layer 3 ─ Host Security           → RHCOS Hardening, SELinux, Seccomp
Layer 2 ─ Data Security           → Encryption at Rest/Transit, KMS
Layer 1 ─ Infrastructure Security → Cloud IAM, VPC, Security Groups
```

### 1.3 Shared Responsibility Matrix

| Domain | Platform Team | Application Team | Security Team |
|--------|:------------:|:----------------:|:-------------:|
| Infrastructure | ● | ○ | ◐ |
| Cluster Configuration | ● | ○ | ◐ |
| Namespace Management | ◐ | ● | ◐ |
| Network Policies | ◐ | ● | ● |
| Application Security | ○ | ● | ◐ |
| Vulnerability Management | ◐ | ◐ | ● |
| Incident Response | ◐ | ◐ | ● |
| Compliance Auditing | ○ | ○ | ● |

● = Primary   ◐ = Shared   ○ = Informed

---

## 2. Infrastructure Layer

### 2.1 Compute Architecture

**Control Plane (3 nodes minimum):**
- Instance type: 4 vCPU, 16 GB RAM, 120 GB SSD (minimum)
- Dedicated to control plane workloads only
- Spread across 3 availability zones
- No user workloads scheduled (taint: `node-role.kubernetes.io/master:NoSchedule`)

**Worker Nodes (Auto-scaled):**
- General workloads: 8 vCPU, 32 GB RAM
- PCI CDE workloads: Dedicated node pool with taints
- Infrastructure nodes: Monitoring, logging, router pods

**Infrastructure Nodes (3 nodes):**
- Router/Ingress pods
- Monitoring stack (Prometheus, Grafana)
- Logging stack (Elasticsearch, Fluentd, Kibana)
- Service mesh control plane

### 2.2 Storage Architecture

| Storage Class | Backend | Encryption | Use Case |
|--------------|---------|------------|----------|
| `ocs-storagecluster-ceph-rbd` | ODF/Ceph RBD | LUKS2 AES-256 | Block storage, databases |
| `ocs-storagecluster-cephfs` | ODF/CephFS | LUKS2 AES-256 | Shared filesystems |
| `ocs-storagecluster-ceph-rgw` | Ceph Object | SSE-S3 | Object storage, backups |

### 2.3 Operating System: RHCOS

Red Hat CoreOS is an immutable, container-optimized OS:
- Automatic updates via Machine Config Operator
- SELinux enforcing mode (mandatory)
- FIPS 140-2 validated cryptographic modules
- Read-only root filesystem
- Minimal attack surface (no SSH by default in production)

---

## 3. Cluster Security Architecture

### 3.1 API Server Hardening

```yaml
# Key API Server Flags
--anonymous-auth=false
--audit-log-maxage=30
--audit-log-maxbackup=10
--audit-log-maxsize=100
--audit-log-path=/var/log/kube-apiserver/audit.log
--encryption-provider-config=/etc/kubernetes/encryption-config.yaml
--enable-admission-plugins=NodeRestriction,PodSecurityPolicy
--profiling=false
--request-timeout=300s
--service-account-lookup=true
--tls-min-version=VersionTLS13
--tls-cipher-suites=TLS_AES_128_GCM_SHA256,TLS_AES_256_GCM_SHA384,TLS_CHACHA20_POLY1305_SHA256
```

### 3.2 etcd Security

- **Encryption at rest**: AES-256-GCM for all Kubernetes secrets
- **mTLS**: Client certificate authentication between API server and etcd
- **Access Control**: Only API server can communicate with etcd
- **Backup**: Automated encrypted backups every 6 hours
- **Defragmentation**: Scheduled maintenance to prevent performance degradation

### 3.3 Admission Control Pipeline

```
Request → Authentication → Authorization → Mutation Webhooks → Validation Webhooks → Persist
                                              │                      │
                                    ┌─────────┴──────┐    ┌────────┴──────────┐
                                    │ OPA Gatekeeper  │    │ Kyverno Policies  │
                                    │ - Resource Limits│    │ - Label Standards │
                                    │ - Image Sources  │    │ - Network Policy  │
                                    │ - Privilege Deny │    │ - Pod Annotations │
                                    └────────────────┘    └───────────────────┘
```

---

## 4. Network Security Architecture

### 4.1 Network Zones

```
┌─────────────────────────────────────────────────────┐
│ Zone 1: EXTERNAL (Untrusted)                        │
│   - Public internet traffic                         │
│   - WAF/DDoS protection layer                       │
├─────────────────────────────────────────────────────┤
│ Zone 2: DMZ (Semi-Trusted)                          │
│   - Ingress controllers, API gateway                │
│   - TLS termination point                           │
├─────────────────────────────────────────────────────┤
│ Zone 3: APPLICATION (Internal)                      │
│   - Application workloads                           │
│   - Service mesh (mTLS enforced)                    │
├─────────────────────────────────────────────────────┤
│ Zone 4: DATA (Restricted)                           │
│   - Databases, caches, message queues               │
│   - Encrypted storage only                          │
├─────────────────────────────────────────────────────┤
│ Zone 5: PCI CDE (Highly Restricted)                 │
│   - Cardholder data processing                      │
│   - Dedicated nodes, maximum isolation              │
├─────────────────────────────────────────────────────┤
│ Zone 6: MANAGEMENT (Isolated)                       │
│   - Monitoring, logging, CI/CD                      │
│   - Admin access only                               │
└─────────────────────────────────────────────────────┘
```

### 4.2 Traffic Flow Rules

| Source Zone | Destination Zone | Protocol | Allowed |
|-------------|-----------------|----------|---------|
| External | DMZ | HTTPS/443 | ✅ |
| External | Application | Any | ❌ |
| DMZ | Application | HTTP/8080 | ✅ |
| Application | Data | DB Ports | ✅ |
| Application | PCI CDE | mTLS Only | ✅ (Restricted) |
| PCI CDE | External | None | ❌ |
| Management | All Zones | Monitoring | ✅ (Read-Only) |

---

## 5. Identity & Access Management

### 5.1 Authentication Flow

```
User/Service → OAuth Server → Identity Provider (LDAP/OIDC/AD)
                    │
                    ├── MFA Challenge (TOTP/WebAuthn)
                    │
                    ├── Token Issuance (JWT, short-lived)
                    │
                    └── RBAC Evaluation → Namespace Access
```

### 5.2 Role Hierarchy

```
cluster-admin (Break-Glass Only)
  └── cluster-security-admin
       ├── namespace-admin (per team)
       │    ├── developer (deploy, debug)
       │    └── viewer (read-only)
       ├── network-admin
       ├── storage-admin
       └── audit-viewer
```

### 5.3 Privileged Access Management

- **Just-In-Time (JIT)**: Cluster-admin access granted on-demand, auto-expires in 4 hours
- **Approval Workflow**: Requires 2-person approval for elevated privileges
- **Session Recording**: All privileged sessions recorded and auditable
- **Break-Glass**: Emergency access with mandatory post-incident review

---

## 6. Monitoring & Incident Response

### 6.1 Security Monitoring Stack

| Component | Purpose | Data Retention |
|-----------|---------|---------------|
| Prometheus | Metrics collection, alerting | 15 days (local), 1 year (Thanos) |
| Grafana | Visualization, dashboards | N/A |
| Elasticsearch | Log aggregation, search | 90 days (hot), 1 year (cold) |
| Fluentd | Log collection, forwarding | Buffer only |
| Jaeger | Distributed tracing | 7 days |
| Falco | Runtime threat detection | Real-time + forwarded |
| StackRox/ACS | Container security platform | Configurable |

### 6.2 Incident Response Workflow

```
Detection → Triage → Containment → Eradication → Recovery → Lessons Learned
    │          │          │              │            │              │
  Falco     Severity   Isolate       Patch/Fix    Restore        Post-
  ACS       Rating     Namespace     Rebuild      Service        Mortem
  SIEM      Assignment  Revoke       Image        Verify         Update
                        Access                    Compliance     Runbooks
```

---

## 7. Compliance Continuous Monitoring

### 7.1 Automated Compliance Checks

- **OpenShift Compliance Operator**: CIS Benchmark scanning every 24h
- **OPA/Gatekeeper Audit**: Policy violation detection in real-time
- **Trivy Operator**: CVE scanning for all running containers
- **Custom CronJobs**: PCI DSS specific checks weekly

### 7.2 Evidence Collection

All compliance evidence is automatically collected and stored:
- API server audit logs → Elasticsearch
- Node-level audit logs → Centralized syslog
- Compliance scan results → S3-compatible object storage
- Access reviews → ServiceNow/Jira integration
- Change management → Git history (immutable)

---

*Document Version: 2.0 | Last Updated: March 2026 | Author: Ali AlEnezi*
