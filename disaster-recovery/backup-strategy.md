# Backup and Disaster Recovery Strategy

## Overview

This document outlines the backup and disaster recovery procedures for the OpenShift enterprise cluster, aligned with PCI DSS v4.0 requirements for business continuity.

## Backup Schedule

| Component | Frequency | Retention | Method | Encryption |
|-----------|-----------|-----------|--------|------------|
| etcd | Every 6 hours | 30 days | Snapshot + GPG | AES-256 |
| PVCs (PCI CDE) | Every 4 hours | 90 days | Velero + Restic | AES-256 |
| PVCs (Other) | Daily | 30 days | Velero + Restic | AES-256 |
| Cluster Config | On change (GitOps) | Indefinite | Git | SSH/GPG |
| Secrets | Daily | 30 days | Vault backup | Vault seal |
| Certificates | Weekly | 90 days | Automated export | TLS |

## Recovery Time Objectives

| Scenario | RTO | RPO |
|----------|-----|-----|
| Single pod failure | < 1 min | 0 (stateless) |
| Node failure | < 5 min | 0 (rescheduling) |
| Namespace corruption | < 30 min | 4 hours |
| Full cluster rebuild | < 4 hours | 6 hours |
| Cross-region failover | < 1 hour | 4 hours |

## Recovery Procedures

### Procedure 1: Restore from etcd Backup
```bash
# Stop API server on all masters
# Restore etcd snapshot
etcdctl snapshot restore /backup/latest/snapshot.db \
  --data-dir=/var/lib/etcd-restored

# Verify and restart
```

### Procedure 2: Restore Namespace with Velero
```bash
velero restore create --from-backup daily-backup-YYYYMMDD \
  --include-namespaces pci-cde \
  --restore-volumes=true
```

### Procedure 3: Full Cluster Recovery
1. Re-provision infrastructure (IaC)
2. Install OpenShift from saved install-config
3. Restore etcd from latest backup
4. Apply GitOps configurations (ArgoCD auto-sync)
5. Restore PVC data with Velero
6. Verify compliance scan passes
7. Validate PCI CDE functionality

---

*Last tested: March 2026 | Next DR test: June 2026*
