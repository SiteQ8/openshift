#!/bin/bash
# =============================================================================
# OpenShift Cluster Security Bootstrap
# Author: Ali AlEnezi (@SiteQ8)
# Run this after initial cluster installation
# =============================================================================

set -euo pipefail

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║       OpenShift Security Bootstrap v2.0                     ║"
echo "║       Author: Ali AlEnezi (@SiteQ8)                        ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "[1/9] Applying cluster hardening..."
oc apply -f "$SCRIPT_DIR/hardening/cluster-hardening.yaml"

echo "[2/9] Applying Security Context Constraints..."
oc apply -f "$SCRIPT_DIR/hardening/scc-profiles.yaml"

echo "[3/9] Enabling etcd encryption..."
oc apply -f "$SCRIPT_DIR/hardening/etcd-encryption.yaml"

echo "[4/9] Applying network policies..."
oc apply -f "$SCRIPT_DIR/policies/network-policies.yaml"

echo "[5/9] Configuring egress firewall..."
oc apply -f "$SCRIPT_DIR/network/egress-firewall.yaml"

echo "[6/9] Setting up RBAC..."
oc apply -f "$SCRIPT_DIR/rbac/cluster-roles.yaml"
oc apply -f "$SCRIPT_DIR/rbac/service-accounts.yaml"

echo "[7/9] Creating PCI CDE environment..."
oc apply -f "$SCRIPT_DIR/pci-dss/cde-namespace.yaml"
oc apply -f "$SCRIPT_DIR/pci-dss/access-controls.yaml"

echo "[8/9] Deploying monitoring..."
oc apply -f "$SCRIPT_DIR/monitoring/prometheus-rules.yaml"
oc apply -f "$SCRIPT_DIR/monitoring/audit-policy.yaml"

echo "[9/9] Generating node hardening configs..."
bash "$SCRIPT_DIR/hardening/node-hardening.sh"

echo ""
echo "✅ Security bootstrap complete!"
echo ""
echo "Next steps:"
echo "  1. Configure OAuth: oc apply -f rbac/oauth-config.yaml"
echo "  2. Remove kubeadmin: oc delete secret kubeadmin -n kube-system"
echo "  3. Deploy service mesh: oc apply -f network/service-mesh.yaml"
echo "  4. Install OPA Gatekeeper and apply constraints"
echo "  5. Run compliance check: ./scripts/compliance-check.sh"
