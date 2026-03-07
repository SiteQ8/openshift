# PCI DSS v4.0 Compliance Matrix for OpenShift

## Overview

This document maps all 12 PCI DSS v4.0 requirements to specific OpenShift controls implemented in this blueprint.

---

## Requirement 1: Install and Maintain Network Security Controls

| Sub-Req | Control Description | OpenShift Implementation | File Reference |
|---------|-------------------|------------------------|----------------|
| 1.2.1 | Network security controls configuration standards | NetworkPolicy manifests with default deny | `policies/network-policies.yaml` |
| 1.2.5 | All services, protocols, and ports allowed are identified | Egress firewall with explicit port allowlist | `network/egress-firewall.yaml` |
| 1.2.8 | Configuration files for NSCs are secured | GitOps-managed policies in version control | `ci-cd/argocd-config.yaml` |
| 1.3.1 | Inbound traffic to CDE is restricted | PCI namespace NetworkPolicy - ingress restricted | `pci-dss/cde-namespace.yaml` |
| 1.3.2 | Outbound traffic from CDE is restricted | PCI namespace egress deny-all + explicit allowlist | `pci-dss/cde-namespace.yaml` |
| 1.4.1 | NSCs between trusted and untrusted networks | Service mesh mTLS between zones | `network/service-mesh.yaml` |
| 1.4.2 | Inbound traffic from untrusted networks restricted | Ingress controller with WAF integration | `network/ingress-config.yaml` |

## Requirement 2: Apply Secure Configurations

| Sub-Req | Control Description | OpenShift Implementation | File Reference |
|---------|-------------------|------------------------|----------------|
| 2.2.1 | Configuration standards for all system components | CIS Benchmark hardening manifests | `hardening/cluster-hardening.yaml` |
| 2.2.2 | Vendor default accounts removed/disabled | kubeadmin removed post-install | `docs/deployment-guide.md` |
| 2.2.4 | Only necessary services enabled | Minimal RHCOS, no SSH | `hardening/node-hardening.sh` |
| 2.2.5 | Insecure services/protocols removed | TLS 1.3 minimum, insecure ports blocked | `hardening/cluster-hardening.yaml` |
| 2.2.7 | Non-console admin access encrypted | API server TLS, encrypted etcd | `hardening/etcd-encryption.yaml` |

## Requirement 3: Protect Stored Account Data

| Sub-Req | Control Description | OpenShift Implementation | File Reference |
|---------|-------------------|------------------------|----------------|
| 3.1.1 | Stored account data minimized | Ephemeral containers, no persistent CHD unless required | `pci-dss/encryption-config.yaml` |
| 3.5.1 | PAN rendered unreadable wherever stored | Encryption at rest with LUKS2 + etcd encryption | `hardening/etcd-encryption.yaml` |
| 3.6.1 | Cryptographic key management procedures | HashiCorp Vault with auto-rotation | `pci-dss/encryption-config.yaml` |
| 3.7.1 | Key management policies documented | Vault policies and rotation schedule | `pci-dss/encryption-config.yaml` |

## Requirement 4: Protect Cardholder Data with Strong Cryptography During Transmission

| Sub-Req | Control Description | OpenShift Implementation | File Reference |
|---------|-------------------|------------------------|----------------|
| 4.2.1 | Strong cryptography for CHD transmission | mTLS via service mesh, TLS 1.3 | `network/service-mesh.yaml` |
| 4.2.1.1 | Certificates trusted and valid | cert-manager with automated renewal | `network/ingress-config.yaml` |
| 4.2.2 | PAN secured when sent via end-user messaging | Application-level encryption enforcement | `pci-dss/encryption-config.yaml` |

## Requirement 5: Protect All Systems from Malicious Software

| Sub-Req | Control Description | OpenShift Implementation | File Reference |
|---------|-------------------|------------------------|----------------|
| 5.2.1 | Anti-malware deployed on all systems | StackRox/ACS runtime protection | `monitoring/falco-rules.yaml` |
| 5.2.2 | Anti-malware performs periodic evaluations | Continuous image scanning (Trivy Operator) | `ci-cd/tekton-pipeline.yaml` |
| 5.3.1 | Anti-malware mechanisms actively running | Falco daemonset on all nodes | `monitoring/falco-rules.yaml` |
| 5.3.2 | Anti-malware logs retained | Falco alerts forwarded to SIEM | `monitoring/prometheus-rules.yaml` |

## Requirement 6: Develop and Maintain Secure Systems and Software

| Sub-Req | Control Description | OpenShift Implementation | File Reference |
|---------|-------------------|------------------------|----------------|
| 6.2.1 | Custom software developed securely | Secure CI/CD with SAST/DAST | `ci-cd/tekton-pipeline.yaml` |
| 6.2.3 | Software reviewed before production release | Pipeline gates: scan, sign, review | `ci-cd/tekton-pipeline.yaml` |
| 6.3.1 | Security vulnerabilities identified and managed | Trivy + Grype vulnerability scanning | `ci-cd/sbom-generation.yaml` |
| 6.3.2 | Software inventory maintained | SBOM generation with Syft | `ci-cd/sbom-generation.yaml` |
| 6.4.1 | Public-facing web apps protected | WAF + OpenShift router hardening | `network/ingress-config.yaml` |

## Requirement 7: Restrict Access by Business Need to Know

| Sub-Req | Control Description | OpenShift Implementation | File Reference |
|---------|-------------------|------------------------|----------------|
| 7.2.1 | Access control model defined | RBAC with namespace isolation | `rbac/cluster-roles.yaml` |
| 7.2.2 | Access assigned based on job function | Role-based ClusterRoles and RoleBindings | `rbac/namespace-roles.yaml` |
| 7.2.4 | All user accounts reviewed periodically | Automated RBAC audit script | `scripts/security-audit.sh` |
| 7.2.5 | All access privileges assigned and managed | Service account management policies | `rbac/service-accounts.yaml` |

## Requirement 8: Identify Users and Authenticate Access

| Sub-Req | Control Description | OpenShift Implementation | File Reference |
|---------|-------------------|------------------------|----------------|
| 8.2.1 | Unique ID assigned to each user | LDAP/OIDC identity provider integration | `rbac/oauth-config.yaml` |
| 8.3.1 | All user access authenticated via MFA | MFA enforced at identity provider level | `rbac/oauth-config.yaml` |
| 8.3.6 | MFA for all access to CDE | OIDC + MFA for PCI namespace access | `pci-dss/access-controls.yaml` |
| 8.3.9 | Passwords meet minimum complexity | IDP policy enforcement | `rbac/oauth-config.yaml` |
| 8.6.1 | System/application accounts managed | Service account automation, no default SA | `rbac/service-accounts.yaml` |

## Requirement 9: Restrict Physical Access

| Sub-Req | Control Description | OpenShift Implementation | File Reference |
|---------|-------------------|------------------------|----------------|
| 9.1.1 | Physical security controls in place | Cloud provider responsibility (shared model) | `docs/architecture-overview.md` |
| 9.4.1 | Media with cardholder data secured | Encrypted PVs, secure deletion | `pci-dss/encryption-config.yaml` |

## Requirement 10: Log and Monitor All Access

| Sub-Req | Control Description | OpenShift Implementation | File Reference |
|---------|-------------------|------------------------|----------------|
| 10.2.1 | Audit logs capture required events | API server audit policy (RequestResponse) | `monitoring/audit-policy.yaml` |
| 10.2.2 | Audit logs for all system components in CDE | Comprehensive audit for PCI namespaces | `monitoring/audit-policy.yaml` |
| 10.3.1 | Audit log fields include required data | User, timestamp, action, resource, outcome | `monitoring/audit-policy.yaml` |
| 10.4.1 | Audit logs reviewed at least daily | Prometheus alerting on anomalies | `monitoring/prometheus-rules.yaml` |
| 10.5.1 | Audit log access restricted | RBAC on log namespaces, external SIEM | `monitoring/prometheus-rules.yaml` |
| 10.6.1 | Time synchronization technology | Chrony NTP on all RHCOS nodes | `hardening/node-hardening.sh` |
| 10.7.1 | Failures of critical controls detected and reported | Alert rules for logging/monitoring failures | `monitoring/prometheus-rules.yaml` |

## Requirement 11: Test Security Regularly

| Sub-Req | Control Description | OpenShift Implementation | File Reference |
|---------|-------------------|------------------------|----------------|
| 11.2.1 | Wireless access points managed | N/A (container platform) | - |
| 11.3.1 | Vulnerability scans performed quarterly | Compliance Operator scheduled scans | `scripts/compliance-check.sh` |
| 11.4.1 | Penetration testing performed annually | Scope defined, procedures documented | `docs/threat-model.md` |
| 11.5.1 | Network intrusion detection | Falco + ACS runtime detection | `monitoring/falco-rules.yaml` |
| 11.6.1 | Change detection for payment pages | GitOps drift detection via ArgoCD | `ci-cd/argocd-config.yaml` |

## Requirement 12: Support Information Security with Policies and Programs

| Sub-Req | Control Description | OpenShift Implementation | File Reference |
|---------|-------------------|------------------------|----------------|
| 12.1.1 | Security policy established and maintained | Policy-as-code in Git, version controlled | All policy files |
| 12.3.1 | Risk assessment performed annually | Threat model maintained in repository | `docs/threat-model.md` |
| 12.5.1 | Security responsibilities assigned | Shared responsibility matrix documented | `docs/architecture-overview.md` |
| 12.6.1 | Security awareness program | Access to compliance dashboard | `gui/index.html` |
| 12.10.1 | Incident response plan established | DR runbook and IR procedures | `disaster-recovery/dr-runbook.md` |

---

*Document Version: 2.0 | Last Updated: March 2026 | Author: Ali AlEnezi*
