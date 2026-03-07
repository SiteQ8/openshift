#!/bin/bash
# =============================================================================
# OpenShift Security Compliance Check Script
# Author: Ali AlEnezi (@SiteQ8)
# Checks: CIS Benchmark, PCI DSS v4.0, NIST SP 800-53
# =============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0
REPORT="/tmp/openshift-compliance-report.txt"

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║     OpenShift Security Compliance Scanner v2.0              ║"
echo "║     Author: Ali AlEnezi (@SiteQ8)                          ║"
echo "║     Standards: CIS Benchmark | PCI DSS v4.0 | NIST 800-53 ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "Scan started: $(date)" | tee "$REPORT"
echo "=============================================" | tee -a "$REPORT"

check() {
  local desc="$1"
  local result="$2"
  local ref="$3"
  
  if [ "$result" = "PASS" ]; then
    echo -e "  ${GREEN}[PASS]${NC} $desc ($ref)" | tee -a "$REPORT"
    ((PASS++))
  elif [ "$result" = "FAIL" ]; then
    echo -e "  ${RED}[FAIL]${NC} $desc ($ref)" | tee -a "$REPORT"
    ((FAIL++))
  else
    echo -e "  ${YELLOW}[WARN]${NC} $desc ($ref)" | tee -a "$REPORT"
    ((WARN++))
  fi
}

# ─── 1. Authentication & Access ─────────────────────────────────
echo ""
echo -e "${BLUE}[1/8] Authentication & Access Controls${NC}" | tee -a "$REPORT"

# Check kubeadmin removed
if oc get secret kubeadmin -n kube-system 2>/dev/null; then
  check "kubeadmin account removed" "FAIL" "CIS 3.1.1 / PCI 8.2.2"
else
  check "kubeadmin account removed" "PASS" "CIS 3.1.1 / PCI 8.2.2"
fi

# Check OAuth configured
OAUTH_IDP=$(oc get oauth cluster -o jsonpath='{.spec.identityProviders}' 2>/dev/null || echo "")
if [ -n "$OAUTH_IDP" ] && [ "$OAUTH_IDP" != "null" ]; then
  check "Identity provider configured" "PASS" "PCI 8.2.1"
else
  check "Identity provider configured" "FAIL" "PCI 8.2.1"
fi

# Check token timeout
TOKEN_TIMEOUT=$(oc get oauth cluster -o jsonpath='{.spec.tokenConfig.accessTokenInactivityTimeout}' 2>/dev/null || echo "")
if [ -n "$TOKEN_TIMEOUT" ]; then
  check "Token inactivity timeout configured" "PASS" "PCI 8.2.8"
else
  check "Token inactivity timeout configured" "WARN" "PCI 8.2.8"
fi

# ─── 2. Network Security ────────────────────────────────────────
echo ""
echo -e "${BLUE}[2/8] Network Security Controls${NC}" | tee -a "$REPORT"

# Check default NetworkPolicies
NS_WITHOUT_NETPOL=0
for ns in $(oc get namespaces -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | grep -v '^openshift-' | grep -v '^kube-'); do
  NETPOL_COUNT=$(oc get networkpolicies -n "$ns" --no-headers 2>/dev/null | wc -l)
  if [ "$NETPOL_COUNT" -eq 0 ]; then
    ((NS_WITHOUT_NETPOL++))
  fi
done

if [ "$NS_WITHOUT_NETPOL" -eq 0 ]; then
  check "All namespaces have NetworkPolicies" "PASS" "PCI 1.2.1"
else
  check "All namespaces have NetworkPolicies ($NS_WITHOUT_NETPOL missing)" "FAIL" "PCI 1.2.1"
fi

# ─── 3. Cluster Hardening ───────────────────────────────────────
echo ""
echo -e "${BLUE}[3/8] Cluster Hardening${NC}" | tee -a "$REPORT"

# Check etcd encryption
ETCD_ENC=$(oc get apiserver cluster -o jsonpath='{.spec.encryption.type}' 2>/dev/null || echo "")
if [ "$ETCD_ENC" = "aesgcm" ] || [ "$ETCD_ENC" = "aescbc" ]; then
  check "etcd encryption enabled ($ETCD_ENC)" "PASS" "PCI 3.5.1"
else
  check "etcd encryption enabled" "FAIL" "PCI 3.5.1"
fi

# Check audit logging
AUDIT_PROFILE=$(oc get apiserver cluster -o jsonpath='{.spec.audit.profile}' 2>/dev/null || echo "")
if [ "$AUDIT_PROFILE" = "AllRequestBodies" ] || [ "$AUDIT_PROFILE" = "WriteRequestBodies" ]; then
  check "API server audit logging ($AUDIT_PROFILE)" "PASS" "PCI 10.2.1"
else
  check "API server audit logging" "FAIL" "PCI 10.2.1"
fi

# Check TLS version
TLS_MIN=$(oc get apiserver cluster -o jsonpath='{.spec.tlsSecurityProfile.custom.minTLSVersion}' 2>/dev/null || echo "")
if [ "$TLS_MIN" = "VersionTLS12" ] || [ "$TLS_MIN" = "VersionTLS13" ]; then
  check "Minimum TLS version ($TLS_MIN)" "PASS" "PCI 4.2.1"
else
  check "Minimum TLS version" "WARN" "PCI 4.2.1"
fi

# ─── 4. Pod Security ────────────────────────────────────────────
echo ""
echo -e "${BLUE}[4/8] Pod Security${NC}" | tee -a "$REPORT"

# Check for privileged containers
PRIV_PODS=$(oc get pods --all-namespaces -o json 2>/dev/null | \
  python3 -c "
import sys, json
data = json.load(sys.stdin)
count = 0
for pod in data.get('items', []):
  ns = pod['metadata'].get('namespace', '')
  if ns.startswith('openshift-') or ns.startswith('kube-'):
    continue
  for c in pod['spec'].get('containers', []):
    sc = c.get('securityContext', {})
    if sc.get('privileged', False):
      count += 1
print(count)
" 2>/dev/null || echo "0")

if [ "$PRIV_PODS" -eq 0 ]; then
  check "No privileged containers in user namespaces" "PASS" "CIS 5.2.1"
else
  check "Privileged containers found: $PRIV_PODS" "FAIL" "CIS 5.2.1"
fi

# Check self-provisioner removed
SELF_PROV=$(oc get clusterrolebinding self-provisioners -o jsonpath='{.subjects}' 2>/dev/null || echo "null")
if [ "$SELF_PROV" = "null" ] || [ -z "$SELF_PROV" ]; then
  check "Self-provisioner role removed" "PASS" "CIS 5.1.1"
else
  check "Self-provisioner role removed" "FAIL" "CIS 5.1.1"
fi

# ─── 5. Image Security ──────────────────────────────────────────
echo ""
echo -e "${BLUE}[5/8] Image & Supply Chain Security${NC}" | tee -a "$REPORT"

# Check for latest tag usage
LATEST_IMGS=$(oc get pods --all-namespaces -o jsonpath='{range .items[*]}{range .spec.containers[*]}{.image}{"\n"}{end}{end}' 2>/dev/null | \
  grep -c ':latest$' || echo "0")

if [ "$LATEST_IMGS" -eq 0 ]; then
  check "No containers using :latest tag" "PASS" "PCI 6.3.1"
else
  check "Containers using :latest tag: $LATEST_IMGS" "WARN" "PCI 6.3.1"
fi

# ─── 6. Monitoring ──────────────────────────────────────────────
echo ""
echo -e "${BLUE}[6/8] Monitoring & Logging${NC}" | tee -a "$REPORT"

# Check Prometheus running
PROM_PODS=$(oc get pods -n openshift-monitoring -l app.kubernetes.io/name=prometheus --no-headers 2>/dev/null | grep -c "Running" || echo "0")
if [ "$PROM_PODS" -ge 1 ]; then
  check "Prometheus monitoring active ($PROM_PODS pods)" "PASS" "PCI 10.4.1"
else
  check "Prometheus monitoring active" "FAIL" "PCI 10.4.1"
fi

# ─── 7. PCI CDE Checks ─────────────────────────────────────────
echo ""
echo -e "${BLUE}[7/8] PCI CDE Environment${NC}" | tee -a "$REPORT"

# Check PCI CDE namespace exists
if oc get namespace pci-cde 2>/dev/null > /dev/null; then
  check "PCI CDE namespace exists" "PASS" "PCI 1.3.1"
  
  # Check PCI CDE has restricted PSS
  PSS_ENFORCE=$(oc get namespace pci-cde -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}' 2>/dev/null || echo "")
  if [ "$PSS_ENFORCE" = "restricted" ]; then
    check "PCI CDE namespace enforces restricted PSS" "PASS" "PCI 2.2.4"
  else
    check "PCI CDE namespace enforces restricted PSS" "FAIL" "PCI 2.2.4"
  fi
else
  check "PCI CDE namespace exists" "WARN" "PCI 1.3.1"
fi

# ─── 8. Admission Control ───────────────────────────────────────
echo ""
echo -e "${BLUE}[8/8] Admission Control & Policy Enforcement${NC}" | tee -a "$REPORT"

# Check OPA Gatekeeper
if oc get pods -n gatekeeper-system --no-headers 2>/dev/null | grep -q "Running"; then
  check "OPA Gatekeeper operational" "PASS" "PCI 6.2.1"
else
  check "OPA Gatekeeper operational" "WARN" "PCI 6.2.1"
fi

# ─── Results Summary ────────────────────────────────────────────
echo ""
echo "=============================================" | tee -a "$REPORT"
echo "COMPLIANCE SCAN RESULTS" | tee -a "$REPORT"
echo "=============================================" | tee -a "$REPORT"
echo -e "  ${GREEN}PASS: $PASS${NC}" | tee -a "$REPORT"
echo -e "  ${RED}FAIL: $FAIL${NC}" | tee -a "$REPORT"
echo -e "  ${YELLOW}WARN: $WARN${NC}" | tee -a "$REPORT"
TOTAL=$((PASS + FAIL + WARN))
SCORE=$(( (PASS * 100) / TOTAL ))
echo "  SCORE: $SCORE% ($PASS/$TOTAL)" | tee -a "$REPORT"
echo "" | tee -a "$REPORT"
echo "Report saved: $REPORT"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
