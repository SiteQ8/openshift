# Disaster Recovery Runbook

## Incident Classification

| Level | Description | Response Time | Escalation |
|-------|-------------|---------------|------------|
| P1 - Critical | Full cluster down, PCI data at risk | < 15 min | CISO + CTO immediately |
| P2 - Major | Partial outage, CDE degraded | < 30 min | Platform Lead + Security Lead |
| P3 - Minor | Single service affected | < 2 hours | On-call engineer |
| P4 - Low | Non-critical component failure | Next business day | Team lead |

## Contact List

| Role | Name | Contact |
|------|------|---------|
| Security Lead | Ali AlEnezi | Site@hotmail.com |
| Platform Lead | TBD | TBD |
| On-Call | Rotation | PagerDuty |

## Runbook: Full Cluster Recovery

### Phase 1: Assessment (0-15 min)
1. Confirm the outage scope and impact
2. Notify incident commander
3. Activate war room / communication channel
4. Determine root cause category (infrastructure, security breach, configuration)

### Phase 2: Containment (15-30 min)
1. If security breach: isolate affected nodes/namespaces
2. Preserve evidence (do not destroy logs)
3. Revoke compromised credentials
4. Activate secondary site if available

### Phase 3: Recovery (30 min - 4 hours)
1. Provision new infrastructure (Terraform/IaC)
2. Install OpenShift from saved configuration
3. Restore etcd from latest verified backup
4. Wait for ArgoCD to sync all policies
5. Restore PVC data via Velero
6. Verify all security controls operational
7. Run compliance scan

### Phase 4: Validation (Post-Recovery)
1. Verify all PCI CDE workloads functional
2. Confirm network policies enforced
3. Validate mTLS in service mesh
4. Check audit logging operational
5. Run full compliance check script
6. Notify stakeholders of recovery

### Phase 5: Post-Incident (Within 48 hours)
1. Conduct post-mortem meeting
2. Document root cause analysis
3. Update runbooks with lessons learned
4. File PCI DSS incident report if CDE was affected
5. Schedule follow-up review

---

*Last Review: March 2026 | Owner: Ali AlEnezi*
