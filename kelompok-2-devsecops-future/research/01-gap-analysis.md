# Gap Analysis — From Baseline to Research-Driven Enhancement

## 1. Introduction

This document identifies the security gaps present in the baseline DevSecOps pipeline (Week 12) and maps each gap to a research-driven enhancement drawn from Paper A and Paper B. The analysis follows the structure: **current state → gap → proposed solution → expected improvement**.

---

## 2. Gap 1: No Automated Policy Enforcement at CI Stage

**Current State (Baseline):** The GitLab CI pipeline in Week 12 builds, packages, and deploys the `taskflow-api` application. There is no automated validation of Kubernetes manifests before deployment. Developers can accidentally deploy pods with root privileges, images from untrusted registries, or containers without resource limits. These violations are only caught—if ever—during manual review.

**Gap Identified:** The pipeline lacks a "shift-left" security gate. Vulnerable configurations reach the cluster before anyone notices. Paper A reports that 92% of Kubernetes misconfigurations in their study were detectable at CI time using OPA/Conftest, yet the baseline pipeline catches 0%.

**Proposed Solution (from Paper A):** Integrate a `validate-k8s-manifest` stage using OPA/Conftest with three Rego policies: image trust, security context, and resource limits. The policy check runs before the image is built, failing the pipeline immediately on violation.

**Expected Improvement:** 100% of tested misconfigurations blocked before deployment. Pipeline overhead of approximately 54 ms per manifest (negligible).

---

## 3. Gap 2: No Runtime Threat Detection

**Current State (Baseline):** Once a pod is running in the cluster, there is no mechanism to detect attacker behavior such as shell spawning, privilege escalation, or file tampering. A developer who gains `exec` access to a container can run arbitrary commands without any alert being generated.

**Gap Identified:** The baseline has zero runtime visibility. Paper B demonstrates that Falco with the `modern_ebpf` driver can detect shell spawning events within 1–2 seconds of occurrence with a criticality priority, but the baseline has no such capability.

**Proposed Solution (from Paper B):** Deploy Falco as a DaemonSet with `modern_ebpf` driver, configured with custom rules to detect `Terminal shell in container` events. Route alerts through Falcosidekick to a webhook service.

**Expected Improvement:** MTTD (Mean Time to Detect) under 1 second for shell spawning attacks.

---

## 4. Gap 3: No Automated Remediation

**Current State (Baseline):** Even if a runtime threat is detected (which it cannot be in the baseline), there is no mechanism to automatically respond. A compromised pod can continue running indefinitely, giving an attacker persistent access.

**Gap Identified:** The gap between detection and response is infinite in the baseline. Paper B proposes an automated pod deletion pipeline—Falco → Falcosidekick → Webhook (label + delete) → Kyverno (backup)—with measured MTTR under 3 seconds.

**Proposed Solution (from Paper B):** Deploy a Flask webhook that receives Falco alerts, labels the compromised pod `suspicious=true`, and immediately deletes it with `--grace-period=0 --force`. Deploy Kyverno with a `ClusterCleanupPolicy` as a backup that runs every minute to catch any pods the webhook missed.

**Expected Improvement:** MTTR (Mean Time to Remediate) under 3 seconds for detected attacks.

---

## 5. Gap 4: No Security Metrics Collection

**Current State (Baseline):** There is no systematic collection of security metrics—no detection rate, no false positive rate, no response time. Without metrics, it is impossible to evaluate whether a security investment is effective.

**Gap Identified:** The project cannot demonstrate improvement without before/after measurement. Both Paper A and Paper B use quantitative metrics (detection rate, latency, overhead) to validate their approaches.

**Proposed Solution:** Implement automated test scripts (`run-opa-tests.sh` for 20 OPA scenarios, `run-runtime-tests.sh` for 5 runtime attack cycles) that produce structured CSV output for analysis.

**Expected Improvement:** Measurable baseline (before) and post-enhancement (after) metrics across all dimensions.

---

## 6. Gap Summary Table

| # | Gap | Severity | Paper | Solution | Key Metric |
|---|-----|----------|-------|----------|------------|
| 1 | No CI policy gate | High | A | OPA/Conftest stage | Detection Rate → 100% |
| 2 | No runtime detection | Critical | B | Falco + Falcosidekick | MTTD → < 1s |
| 3 | No auto-remediation | Critical | B | Webhook + Kyverno | MTTR → < 3s |
| 4 | No metrics | Medium | A & B | Test scripts + CSV | Before/After comparison |
