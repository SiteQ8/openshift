# Threat Model - OpenShift Secure Architecture

## Methodology: STRIDE + MITRE ATT&CK for Containers

---

## 1. Asset Inventory

| Asset | Classification | Impact if Compromised |
|-------|---------------|----------------------|
| etcd datastore | Critical | Full cluster compromise |
| API Server | Critical | Unauthorized cluster control |
| Container Images | High | Supply chain attack |
| Secrets/Credentials | Critical | Data breach, lateral movement |
| Cardholder Data (PCI) | Critical | Regulatory violation, fines |
| Worker Nodes | High | Workload compromise |
| Service Mesh Certificates | High | mTLS bypass |
| CI/CD Pipeline | High | Malicious code injection |

---

## 2. STRIDE Threat Analysis

### 2.1 Spoofing

| Threat | Attack Vector | Mitigation |
|--------|--------------|------------|
| Impersonate cluster admin | Stolen kubeconfig/token | MFA, short-lived tokens, JIT access |
| Spoofed service identity | Compromised service account | mTLS via service mesh, token audience binding |
| Rogue container registry | DNS poisoning/typosquatting | Allowlisted registries only, image signature verification |
| Forged webhook responses | Man-in-the-middle | Webhook TLS validation, certificate pinning |

### 2.2 Tampering

| Threat | Attack Vector | Mitigation |
|--------|--------------|------------|
| Modified container images | Registry compromise | Image signing (Cosign), admission controller verification |
| etcd data manipulation | Direct etcd access | etcd encryption, mTLS, restricted network access |
| ConfigMap/Secret alteration | Compromised RBAC | Audit logging, OPA policies, GitOps drift detection |
| Node filesystem tampering | Container escape | Read-only rootfs, SELinux, immutable RHCOS |

### 2.3 Repudiation

| Threat | Attack Vector | Mitigation |
|--------|--------------|------------|
| Untracked admin actions | Disabled audit logging | Mandatory audit policy, immutable log forwarding |
| Deleted evidence | Log tampering | External log shipping, WORM storage |
| Anonymous API access | Misconfigured auth | Disable anonymous auth, enforce authentication |

### 2.4 Information Disclosure

| Threat | Attack Vector | Mitigation |
|--------|--------------|------------|
| Secret exposure in logs | Application logging secrets | OPA policy blocking secret env vars, log scrubbing |
| etcd data leak | Unencrypted backup | Encrypted backups, access-controlled storage |
| Container environment leak | `kubectl exec` abuse | RBAC restrictions, audit all exec commands |
| Network sniffing | Unencrypted east-west traffic | mTLS everywhere via service mesh |

### 2.5 Denial of Service

| Threat | Attack Vector | Mitigation |
|--------|--------------|------------|
| Resource exhaustion | Fork bomb, crypto mining | Resource quotas, LimitRanges, CPU/memory limits |
| etcd overload | Excessive API requests | API priority and fairness, rate limiting |
| Node pressure | Noisy neighbor pods | Pod priority classes, node affinity, PCI node isolation |
| Network flooding | DDoS attack | WAF, external DDoS protection, ingress rate limiting |

### 2.6 Elevation of Privilege

| Threat | Attack Vector | Mitigation |
|--------|--------------|------------|
| Container breakout | Kernel exploit | Seccomp, AppArmor, no privileged containers, patching |
| RBAC escalation | Wildcard permissions | Least privilege RBAC, regular access reviews |
| Service account abuse | Default SA with permissions | Disable automount, dedicated SAs per workload |
| Node-level access | SSH to worker nodes | No SSH in production, MachineConfig for all changes |

---

## 3. MITRE ATT&CK for Containers - Coverage

### Initial Access
- ✅ T1190 - Exploit Public-Facing Application → WAF, patching, vulnerability scanning
- ✅ T1133 - External Remote Services → VPN-only management access
- ✅ T1078 - Valid Accounts → MFA, JIT access, monitoring

### Execution
- ✅ T1610 - Deploy Container → Admission control, image allowlists
- ✅ T1609 - Container Administration Command → Audit logging, RBAC

### Persistence
- ✅ T1053 - Scheduled Task/Job → CronJob monitoring, OPA policies
- ✅ T1078 - Valid Accounts → Token rotation, session limits

### Privilege Escalation
- ✅ T1611 - Escape to Host → SCC restrictions, Seccomp, SELinux
- ✅ T1548 - Abuse Elevation Control → No privileged containers, PSP

### Defense Evasion
- ✅ T1070 - Indicator Removal → Immutable audit logs, external shipping
- ✅ T1036 - Masquerading → Image signature verification

### Credential Access
- ✅ T1552 - Unsecured Credentials → Vault integration, encrypted secrets
- ✅ T1528 - Steal Application Access Token → Short-lived tokens, audience binding

### Lateral Movement
- ✅ T1021 - Remote Services → Network segmentation, mTLS
- ✅ T1550 - Use Alternate Auth Material → Token invalidation, monitoring

### Impact
- ✅ T1485 - Data Destruction → RBAC, backups, WORM storage
- ✅ T1496 - Resource Hijacking → Resource quotas, runtime detection (Falco)

---

## 4. Risk Register

| Risk ID | Description | Likelihood | Impact | Risk Score | Mitigation Status |
|---------|-------------|-----------|--------|-----------|-------------------|
| R001 | Container escape to host | Low | Critical | High | Mitigated (SCC, SELinux) |
| R002 | Supply chain image compromise | Medium | Critical | Critical | Mitigated (Cosign, scanning) |
| R003 | Credential theft via log exposure | Medium | High | High | Mitigated (Vault, OPA) |
| R004 | etcd data breach | Low | Critical | High | Mitigated (encryption, mTLS) |
| R005 | DDoS against ingress | High | Medium | High | Mitigated (WAF, rate limiting) |
| R006 | Insider threat - admin abuse | Low | Critical | High | Mitigated (JIT, audit, MFA) |
| R007 | PCI data exfiltration | Low | Critical | Critical | Mitigated (egress FW, DLP) |
| R008 | Unpatched CVE exploitation | Medium | High | High | Mitigated (auto-patching, scanning) |

---

*Document Version: 2.0 | Last Updated: March 2026 | Author: Ali AlEnezi*
