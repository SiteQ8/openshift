#!/bin/bash
# =============================================================================
# RHCOS Node Hardening Script
# Author: Ali AlEnezi (@SiteQ8)
# Standard: CIS Benchmark for RHCOS + NIST SP 800-53
# =============================================================================

set -euo pipefail

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║          RHCOS Node Hardening - OpenShift Blueprint         ║"
echo "║                   Author: Ali AlEnezi                       ║"
echo "╚══════════════════════════════════════════════════════════════╝"

# Note: This script generates MachineConfig resources to be applied
# via the Machine Config Operator. Do NOT run directly on nodes.

OUTPUT_DIR="/tmp/node-hardening-configs"
mkdir -p "$OUTPUT_DIR"

# ─────────────────────────────────────────────────────────────────
# 1. Kernel Hardening Parameters (sysctl)
# ─────────────────────────────────────────────────────────────────
cat > "$OUTPUT_DIR/99-sysctl-hardening.yaml" << 'EOF'
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  name: 99-worker-sysctl-hardening
  labels:
    machineconfiguration.openshift.io/role: worker
spec:
  config:
    ignition:
      version: 3.2.0
    storage:
      files:
        - path: /etc/sysctl.d/99-security-hardening.conf
          mode: 0644
          contents:
            source: data:text/plain;charset=utf-8;base64,IyBLZXJuZWwgSGFyZGVuaW5nIC0gQ0lTIEJlbmNobWFyawojIERpc2FibGUgSVAgZm9yd2FyZGluZwpuZXQuaXB2NC5pcF9mb3J3YXJkID0gMApuZXQuaXB2Ni5jb25mLmFsbC5mb3J3YXJkaW5nID0gMAoKIyBEaXNhYmxlIHNvdXJjZSByb3V0aW5nCm5ldC5pcHY0LmNvbmYuYWxsLmFjY2VwdF9zb3VyY2Vfcm91dGUgPSAwCm5ldC5pcHY2LmNvbmYuYWxsLmFjY2VwdF9zb3VyY2Vfcm91dGUgPSAwCgojIEVuYWJsZSBUQ1AgU1lOIGNvb2tpZXMKbmV0LmlwdjQuY29uZi5hbGwuc3luY29va2llcyA9IDEKCiMgRGlzYWJsZSBJQ01QIHJlZGlyZWN0cwpuZXQuaXB2NC5jb25mLmFsbC5hY2NlcHRfcmVkaXJlY3RzID0gMApuZXQuaXB2NC5jb25mLmFsbC5zZW5kX3JlZGlyZWN0cyA9IDAKbmV0LmlwdjYuY29uZi5hbGwuYWNjZXB0X3JlZGlyZWN0cyA9IDAKCiMgRW5hYmxlIHJldmVyc2UgcGF0aCBmaWx0ZXJpbmcKbmV0LmlwdjQuY29uZi5hbGwucnBfZmlsdGVyID0gMQpuZXQuaXB2NC5jb25mLmRlZmF1bHQucnBfZmlsdGVyID0gMQoKIyBJZ25vcmUgSUNNUCBicm9hZGNhc3RzCm5ldC5pcHY0Lmljbm1wX2VjaG9faWdub3JlX2Jyb2FkY2FzdHMgPSAxCgojIEtlcm5lbCBBU0xSCmtlcm5lbC5yYW5kb21pemVfdmFfc3BhY2UgPSAyCgojIFJlc3RyaWN0IGRtZXNnCmtlcm5lbC5kbWVzZ19yZXN0cmljdCA9IDEKCiMgUmVzdHJpY3Qga2VybmVsIHBvaW50ZXJzCmtlcm5lbC5rcHRyX3Jlc3RyaWN0ID0gMgoKIyBEaXNhYmxlIGNvcmUgZHVtcHMKZnMuc3VpZF9kdW1wYWJsZSA9IDAK
EOF

# ─────────────────────────────────────────────────────────────────
# 2. Audit Configuration (auditd)
# ─────────────────────────────────────────────────────────────────
cat > "$OUTPUT_DIR/99-auditd-config.yaml" << 'EOF'
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  name: 99-worker-auditd
  labels:
    machineconfiguration.openshift.io/role: worker
spec:
  config:
    ignition:
      version: 3.2.0
    storage:
      files:
        - path: /etc/audit/rules.d/99-openshift-security.rules
          mode: 0640
          contents:
            inline: |
              # OpenShift Security Audit Rules
              # PCI DSS Requirement 10 - Log and Monitor

              # Monitor file changes to critical paths
              -w /etc/kubernetes/ -p wa -k kubernetes-config
              -w /etc/origin/ -p wa -k openshift-config
              -w /var/lib/etcd/ -p wa -k etcd-data

              # Monitor authentication events
              -w /var/log/auth.log -p wa -k authentication
              -w /var/log/secure -p wa -k authentication

              # Monitor privilege escalation
              -w /usr/bin/sudo -p x -k privilege-escalation
              -w /usr/bin/su -p x -k privilege-escalation

              # Monitor container runtime
              -w /usr/bin/crio -p x -k container-runtime
              -w /etc/crio/ -p wa -k container-runtime-config

              # Monitor network configuration changes
              -w /etc/sysconfig/network -p wa -k network-config
              -w /etc/NetworkManager/ -p wa -k network-config

              # Ensure audit logs are not automatically deleted
              -e 2
EOF

# ─────────────────────────────────────────────────────────────────
# 3. Chrony NTP Configuration (PCI DSS 10.6.1)
# ─────────────────────────────────────────────────────────────────
cat > "$OUTPUT_DIR/99-chrony-config.yaml" << 'EOF'
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  name: 99-worker-chrony
  labels:
    machineconfiguration.openshift.io/role: worker
spec:
  config:
    ignition:
      version: 3.2.0
    storage:
      files:
        - path: /etc/chrony.conf
          mode: 0644
          overwrite: true
          contents:
            inline: |
              # Chrony NTP Configuration - PCI DSS 10.6.1
              # Use internal NTP servers only
              server ntp1.enterprise.example.com iburst
              server ntp2.enterprise.example.com iburst
              server ntp3.enterprise.example.com iburst

              # Record the rate at which the system clock gains/losses time
              driftfile /var/lib/chrony/drift

              # Allow the system clock to be stepped in first three updates
              makestep 1.0 3

              # Enable kernel synchronization
              rtcsync

              # Specify directory for log files
              logdir /var/log/chrony

              # Enable logging
              log measurements statistics tracking
EOF

echo ""
echo "✅ Node hardening MachineConfig manifests generated in: $OUTPUT_DIR"
echo ""
echo "Apply with:"
echo "  oc apply -f $OUTPUT_DIR/"
echo ""
echo "Monitor rollout:"
echo "  oc get mcp worker -w"
