#!/bin/bash
# =============================================================================
# OpenShift Security Posture Audit Script
# Author: Ali AlEnezi (@SiteQ8)
# =============================================================================

set -euo pipefail

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║          OpenShift Security Posture Audit v2.0              ║"
echo "║                   Author: Ali AlEnezi                       ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

echo "[*] Cluster Information"
echo "    API Server: $(oc whoami --show-server)"
echo "    User: $(oc whoami)"
echo "    Version: $(oc version -o json 2>/dev/null | jq -r '.openshiftVersion // "unknown"')"
echo ""

echo "[*] RBAC Audit - Cluster Admin Bindings"
echo "    Users/Groups with cluster-admin:"
oc get clusterrolebindings -o json | \
  jq -r '.items[] | select(.roleRef.name=="cluster-admin") | .subjects[]? | "    - \(.kind): \(.name)"'
echo ""

echo "[*] Service Account Audit"
echo "    Service accounts with automountServiceAccountToken:"
oc get serviceaccounts --all-namespaces -o json | \
  jq -r '.items[] | select(.automountServiceAccountToken != false) | "    - \(.metadata.namespace)/\(.metadata.name)"' | head -20
echo "    (showing first 20)"
echo ""

echo "[*] Pod Security Audit"
echo "    Pods running as root (non-system namespaces):"
oc get pods --all-namespaces -o json | \
  jq -r '.items[] | select(.metadata.namespace | startswith("openshift-") | not) | select(.metadata.namespace | startswith("kube-") | not) | select(.spec.securityContext.runAsNonRoot != true) | "    - \(.metadata.namespace)/\(.metadata.name)"' | head -20
echo ""

echo "[*] Network Policy Coverage"
for ns in $(oc get namespaces -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | grep -v '^openshift-' | grep -v '^kube-'); do
  NP_COUNT=$(oc get networkpolicies -n "$ns" --no-headers 2>/dev/null | wc -l)
  if [ "$NP_COUNT" -eq 0 ]; then
    echo "    ⚠ $ns: NO network policies"
  else
    echo "    ✓ $ns: $NP_COUNT policies"
  fi
done
echo ""

echo "[*] Certificate Expiry Check"
oc get certificates --all-namespaces -o json 2>/dev/null | \
  jq -r '.items[] | "    - \(.metadata.namespace)/\(.metadata.name): Expires \(.status.notAfter // "unknown")"' || \
  echo "    cert-manager not installed or no certificates found"
echo ""

echo "[*] Image Registry Sources"
echo "    Unique registries in use:"
oc get pods --all-namespaces -o jsonpath='{range .items[*]}{range .spec.containers[*]}{.image}{"\n"}{end}{end}' | \
  sed 's|/.*||' | sort -u | while read reg; do
    echo "    - $reg"
  done
echo ""

echo "Audit complete: $(date)"
