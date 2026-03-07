# PCI DSS v4.0 Requirement Mapping for OpenShift

This document provides the complete mapping between PCI DSS v4.0 requirements and the OpenShift controls implemented in this blueprint. For the full detailed matrix, see `docs/compliance-matrix.md`.

## Quick Reference

| Req | Title | Key Controls | Status |
|-----|-------|-------------|--------|
| 1 | Network Security Controls | NetworkPolicy, Egress FW, Service Mesh | ✅ Implemented |
| 2 | Secure Configurations | CIS Benchmarks, SCC, RHCOS Hardening | ✅ Implemented |
| 3 | Protect Stored Data | LUKS2, etcd Encryption, Vault KMS | ✅ Implemented |
| 4 | Encrypt Transmissions | TLS 1.3, mTLS (Istio), cert-manager | ✅ Implemented |
| 5 | Malware Protection | ACS/StackRox, Falco, Image Scanning | ✅ Implemented |
| 6 | Secure Development | Tekton SAST/DAST, Cosign, SBOM | ✅ Implemented |
| 7 | Restrict Access | RBAC, Namespace Isolation, OPA | ✅ Implemented |
| 8 | Identify & Authenticate | OIDC/LDAP, MFA, Token Rotation | ✅ Implemented |
| 9 | Physical Access | Cloud Provider + Audit (Shared Model) | ✅ Documented |
| 10 | Log & Monitor | EFK, Prometheus, Audit Policy, Falco | ✅ Implemented |
| 11 | Test Security | Compliance Operator, CIS Scans | ✅ Implemented |
| 12 | Security Policies | Policy-as-Code, GitOps, Threat Model | ✅ Implemented |

## Compliance Score: 100% Control Coverage
