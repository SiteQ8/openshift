# Security Policy

## Reporting Vulnerabilities

1. Do not open a public GitHub issue.
2. Email **Site@hotmail.com** with subject: `[OpenShift Blueprint Security] Brief description`
3. Include the affected file, steps to reproduce, and potential impact.

Response: Acknowledgment 48h, status 7d, resolution 30d.

## Scope

**In scope:** Misconfiguration in YAML manifests that could weaken cluster security, secrets exposed in configuration files, overly permissive RBAC roles, network policy gaps.

**Out of scope:** OpenShift platform vulnerabilities (report to Red Hat), third-party operator issues.

## Important

This repository contains security configuration templates. Always review and adapt all manifests to your environment before applying to production clusters. Test in non-production first.
