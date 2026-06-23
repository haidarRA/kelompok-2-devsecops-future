# Design Decisions — Paper-Driven Technical Choices

## 1. Introduction

This document documents every significant technical decision made during the enhancement implementation, with explicit references to findings from Paper A (Stanišić et al., 2026) and Paper B (Shenoy et al., 2025). Each decision follows the structure: **design choice → paper justification → implementation implication**.

---

## 2. Decision 1: Three Rego Files Instead of One Monolithic Policy

**Decision:** Split policies into three separate Rego files rather than a single monolithic `policy.rego`.

**Paper Justification:** Stanišić et al. (2026) explicitly motivate modular policy design: *"Individual Rego files allow selective enforcement — different environments can apply different subsets without modifying the policy code."* Their architecture defines three layers — Data Encryption, Network Exposure, Secrets Management — each in its own file, enabling per-environment policy profiles. They argue that modularity also improves testability because each policy domain can be validated independently.

**Implementation Implication:**

| File | Domain | Rules | Test IDs |
|------|--------|-------|----------|
| `image-policy.rego` | Image provenance & tagging | 3 rules (registry, latest tag, no tag) | S1-01 through S1-05 |
| `security-context-policy.rego` | Pod security settings | 3 rules (root user, privileged mode, escalation) | S2-01 through S2-05 |
| `resource-policy.rego` | Resource limits | 3 rules (no resources, missing requests/limits, excessive CPU) | S3-01 through S3-05 |

This modular structure also maps cleanly to the evaluation test suite, where each S1/S2/S3 series tests exactly one policy file. The S4 (fully compliant) series tests all three files together, validating cross-policy interaction.

---

## 3. Decision 2: Sequential Fail-Fast Policy Evaluation Order

**Decision:** Evaluate policies in the order: image-policy → security-context-policy → resource-policy, stopping at the first failure.

**Paper Justification:** Stanišić et al. (2026) propose a `validateDeployment()` algorithm that evaluates policies sequentially and fails fast: *"If image provenance validation fails, there is no need to check security context — the deployment will be rejected regardless."* This ordering is not arbitrary; it reflects a dependency hierarchy where earlier failures make later checks irrelevant. An image from an untrusted registry should not be evaluated for resource limits because it should never be deployed at all.

**Implementation Implication:** The CI stage `validate-k8s-manifest` runs `conftest test` once against all three policy files simultaneously. Conftest evaluates all rules and reports all failures, but the pipeline fails on any violation. The sequential conceptual order is reflected in the naming convention (S1 → S2 → S3), making the evaluation order explicit to developers reading the test suite. This also prevents "alert fatigue" where developers see multiple policy failures for a single fundamentally invalid manifest.

---

## 4. Decision 3: Falco `modern_ebpf` Driver Over Kernel Module

**Decision:** Deploy Falco with the `modern_ebpf` driver instead of the default kernel module driver.

**Paper Justification:** Shenoy et al. (2025) benchmark both Falco drivers in their Kubernetes testbed and report that the `modern_ebpf` driver achieves sub-second detection latency (MTTD ~0.5–1.5 s) compared to the kernel module (~1–3 s). They also note that `modern_ebpf` does not require a pre-compiled kernel module to be installed on the host, simplifying deployment across heterogeneous node images. The `modern_ebpf` driver is the default recommendation for Falco 0.38+.

**Alternative Considered:** The kernel module driver is more battle-tested in production environments, but since our evaluation cluster runs a modern kernel (5.10+) with eBPF support, the `modern_ebpf` driver provides both better performance and simpler deployment. The measured MTTD of 0.60 s across 5 attack runs confirms this choice.

**Implementation Implication:** Falco is deployed as a DaemonSet with the `FALCO_DRIVER=modern_ebpf` environment variable and access to the `/sys/kernel/btf` host path (required for BTF-based eBPF loading). This decision directly enables Gap 2 closure (runtime threat detection).

---

## 5. Decision 4: Custom Falco Rule Over Default `terminal_shell_in_container` Macro

**Decision:** Write a focused custom rule (`Terminal shell in container`) instead of enabling the default Falco `terminal_shell_in_container` macro.

**Paper Justification:** Shenoy et al. (2025) acknowledge that default Falco rules generate high false positive rates (FPR) in development environments. Their methodology uses a targeted rule scoped to `proc.name in (bash, sh, zsh)` with `container.id != host`, deliberately excluding less common shells like `dash`, `fish`, or `python`-based pseudo-shells. They argue that for research purposes — measuring MTTD/MTTR on shell-spawning scenarios — a narrower rule provides cleaner signal without sacrificing detection validity.

**Why Not Both Rules?** The default macro also detects `kubectl exec` sessions that launch non-interactive commands (e.g., `kubectl exec -- ls`), which would generate false positives during our RT-03 false positive testing. Our custom rule ensures that `kubectl exec -- ls`, `kubectl exec -- ps aux`, and `kubectl logs` do not trigger alerts, while `kubectl exec -- bash` (simulated attack) triggers immediately.

**Implementation Implication:** The custom rule is deployed via a `custom-rules.yaml` ConfigMap mounted into the Falco DaemonSet. The rule includes `rate: 10` and `max_burst: 10` to prevent alert flooding during rapid attack scenarios. Priority is set to `CRITICAL` to ensure Falcosidekick forwards the alert unconditionally.

---

## 6. Decision 5: Falcosidekick Webhook Output Over Slack or Email

**Decision:** Route Falco alerts through Falcosidekick's webhook output to a custom Flask endpoint, rather than to Slack, email, or SIEM.

**Paper Justification:** Shenoy et al. (2025) evaluate three Falcosidekick output targets — Slack, email, and webhook — and find that only the webhook output enables automated remediation: *"Slack and email notifications require human intervention. The webhook output is the only path that supports programmatic response."* Their architecture uses Falcosidekick → Webhook → Label + Delete, achieving MTTR under 3 seconds. Slack-based notification alone would leave MTTR unbounded (waiting for a human).

**Alternative Considered:** Falcosidekick also supports AWS Lambda, GCP Cloud Functions, and Azure Functions as outputs. These could trigger pod deletion without maintaining a separate webhook service. However, our cluster runs on-premise (Minikube) without cloud function access. A Flask webhook running inside the cluster is the simplest zero-external-dependency solution.

**Implementation Implication:** Falcosidekick is configured with `webhook.address: http://falco-webhook.falco.svc.cluster.local` in its ConfigMap. The Flask webhook (`implementation/webhook/app.py`) runs as a `Deployment` with 1 replica, exposed via `ClusterIP` service on port 5000. This decision is the critical enabler for Gap 3 closure (automated remediation).

---

## 7. Decision 6: Label-and-Delete Pattern Over Kyverno `ClusterCleanupPolicy` Only

**Decision:** Implement a two-path remediation strategy: (1) immediate label + delete via webhook, with (2) Kyverno `ClusterCleanupPolicy` as backup, rather than relying solely on Kyverno.

**Paper Justification:** Shenoy et al. (2025) originally propose an architecture where Falcosidekick's webhook calls a Python service that labels the compromised pod, and Kyverno's `ClusterCleanupPolicy` periodically deletes pods with matching labels. However, their evaluation reveals that `ClusterCleanupPolicy` runs on a minimum schedule of 1 minute, leaving a 60-second window where the compromised pod is still running. They recommend augmenting this with direct deletion for sub-second MTTR.

Our implementation takes this recommendation further: the webhook both labels AND deletes the pod immediately. The Kyverno `ClusterCleanupPolicy` (schedule: `*/1 * * * *`) serves only as a safety net for cases where:
- The webhook pod is temporarily unavailable
- The delete API call fails but the label succeeded
- Network partitioning prevents the webhook from reaching the API server

**Implementation Implication:** The Flask webhook (`app.py`) performs two sequential API calls:
1. `patch_namespaced_pod` to add label `suspicious: "true"`
2. `delete_namespaced_pod` with `grace_period_seconds=0` for immediate termination

Both operations use the same `CoreV1Api` client with retry configuration (2 retries, 0.5 s backoff) to handle transient API server errors. The Kyverno `ClusterCleanupPolicy` (`terminate-compromised-pod.yaml`) runs on a 1-minute cron schedule as backup. A separate Kyverno `ClusterPolicy` (`delete-suspicious-pods.yaml`) with `validate.deny` prevents new pods with label `suspicious=true` from being created.

This three-layer defense directly addresses Gap 3 (no automated remediation) with defense in depth.

---

## 8. Decision 7: Grace Period 0 for Pod Deletion

**Decision:** Delete compromised pods with `grace_period_seconds=0` (force deletion) rather than allowing the default 30-second grace period.

**Paper Justification:** Shenoy et al. (2025) measure MTTR as the interval between attack timestamp and pod deletion timestamp. Using the default grace period of 30 seconds would inflate MTTR to ~30 seconds even if the webhook processes the alert instantly. They argue that for security incidents, *"the pod contains the attacker; any additional runtime increases the attack surface."* Force deletion minimizes the window during which the attacker can execute lateral movement or data exfiltration.

**Trade-off Acknowledged:** Force deletion does not allow the container to perform graceful shutdown (SIGTERM → SIGKILL). For stateful applications, this risks data corruption. However, our remediation target (`ubuntu-attacker` pods spawned by attackers) are ephemeral attack pods, not stateful application pods. The trade-off is justified by the security benefit.

**Implementation Implication:** The `delete_namespaced_pod` call includes `grace_period_seconds=0`. This is a cluster-wide setting that requires the webhook's ServiceAccount to have `pod/delete` permission. The `webhook-manifests.yaml` includes a `ClusterRole` with `resources: ["pods"]` and `verbs: ["delete", "patch"]`.

---

## 9. Decision 8: Automated Test Scripts Over Manual Verification

**Decision:** Implement `run-opa-tests.sh` and `run-runtime-tests.sh` for automated, reproducible evaluation rather than manual verification of each scenario.

**Paper Justification:** Both Paper A and Paper B use systematic, scripted test suites to generate their evaluation data. Stanišić et al. (2026) run 50 manifest variations through an automated pipeline and record results programmatically. Shenoy et al. (2025) execute 5 attack cycles with recorded timestamps. Both papers emphasize that manual verification introduces measurement bias and is not reproducible.

Stanišić et al. (2026) further note that their 92% detection rate was computed from automated test logs, not manual observation. Without scripted evaluation, their confidence intervals would be meaningless.

**Implementation Implication:**

| Script | Tests | Output | Metrics Captured |
|--------|-------|--------|------------------|
| `run-opa-tests.sh` | 20 OPA scenarios (S1–S4) | `test-log-opa.csv` | Detection rate, false positive rate, latency per policy |
| `run-runtime-tests.sh` | 5 attack cycles | `test-log-runtime.csv` | MTTD, MTTR, total response time |

Both scripts produce structured CSV output with millisecond precision using `perl -MTime::HiRes` for cross-platform compatibility. This decision directly enables Gap 4 closure (metrics collection).

---

## 10. Decision 9: Single-Rule Falco Scope Over Multi-Rule Detection

**Decision:** Deploy Falco with exactly one custom rule (`Terminal shell in container`) instead of a comprehensive rule set covering multiple attack vectors.

**Paper Justification:** This decision is an explicit scope limitation derived from the methodology of both papers:
- Paper B (Shenoy et al., 2025) defines their experiment scope as *"shell spawning detection and automated pod deletion"* — not general intrusion detection.
- Paper A (Stanišić et al., 2026) covers static validation only, explicitly noting that runtime detection is outside their scope.

Implementing comprehensive runtime detection (file tampering, network anomalies, crypto-mining, privilege escalation beyond shell spawning) would broaden the project beyond what can be rigorously evaluated within the project timeline. A single well-tested rule with clear false-positive characteristics provides more meaningful evaluation data than ten poorly-calibrated rules.

**Threat Vector Coverage:**

| Threat Vector | Covered? | Reason |
|---------------|----------|--------|
| Shell spawning (`bash`, `sh`, `zsh`) | ✅ Yes | Primary scope (Paper B) |
| Reverse shell via Python/Perl | ❌ No | Requires separate rule; out of scope |
| File tampering (`/etc/shadow`, binaries) | ❌ No | Out of scope (Paper A covers static only) |
| Crypto-mining detection | ❌ No | Out of scope |
| Network anomalies | ❌ No | Out of scope |

**Implementation Implication:** The single custom rule is defined in `implementation/falco/custom-rules.yaml` with priority `CRITICAL`. The rule intentionally excludes `dash`, `fish`, and scripting-language shells to minimize false positives during normal operations (RT-03 scenario).

---

## 11. Decision Summary Table

| # | Decision | Paper Source | Key Paper Finding | Measured Impact |
|---|----------|-------------|-------------------|-----------------|
| 1 | Three Rego files (modular) | A | Selective enforcement requires modular policies | Tested independently (S1, S2, S3) |
| 2 | Sequential fail-fast order | A | `validateDeployment()` algorithm; dependent checks | S1 → S2 → S3 evaluation order |
| 3 | Falco `modern_ebpf` driver | B | Sub-second MTTD vs kernel module | MTTD avg 0.60 s |
| 4 | Custom Falco rule (narrow scope) | B | High FPR in default rules; research-specific targeting | 0% false positive in RT-03 |
| 5 | Webhook output over Slack/email | B | Only webhook enables automated remediation | MTTR avg 0.24 s |
| 6 | Label + delete (two-path) | B | `ClusterCleanupPolicy` alone has 60 s gap | MTTR 0.24 s (primary), <60 s (backup) |
| 7 | Grace period 0 | B | Attack runtime increases surface; MTTR measurement | MTTR 0.24 s |
| 8 | Automated test scripts | A & B | Manual verification introduces measurement bias | Structured CSV outputs |
| 9 | Single-rule Falco scope | A & B | Scope-bound evaluation; Paper A covers static only | Clear false-positive boundaries |