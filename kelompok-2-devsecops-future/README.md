# Kelompok 2 — Future of DevSecOps: Research-Driven Enhancement

## Overview

This repository implements two security enhancements on a Kubernetes-based DevSecOps pipeline using a **research-driven approach**. Each enhancement is grounded in a published academic paper and validated empirically using quantitative metrics.

This is the **enhanced** version of the baseline Week 12 project (`week12-devops-kelompok2`). The baseline provided the CI/CD pipeline, Kubernetes manifests, and deployment scripts. This repository adds:
- **Paper A:** OPA/Conftest policy-as-code enforcement in the CI pipeline (`policy-check` stage)
- **Paper B:** Runtime threat detection (Falco) + automated remediation (Webhook + Kyverno)

The complete merged `.gitlab-ci.yml` (baseline + Paper A addition) is at the repository root. Baseline K8s manifests (`kubernetes/`) and the deploy script (`deploy.sh`) are also included for completeness.

**Stack:** Minikube (local K8s), Falco + Falcosidekick, Kyverno, OPA/Conftest, GitLab CI, Python/Flask

---

## Table of Contents

- [Repository Structure](#repository-structure)
- [Prerequisites](#prerequisites)
- [Setup from Scratch](#setup-from-scratch)
- [Enhancement A: Policy-as-Code (OPA/Conftest)](#enhancement-a-policy-as-code-opaconftest)
- [Enhancement B: Runtime Threat Mitigation (Falco + Kyverno)](#enhancement-b-runtime-threat-mitigation-falco--kyverno)
- [Running Tests](#running-tests)
- [Results Summary](#results-summary)
- [References](#references)

---

## Repository Structure

```
kelompok-2-devsecops-future/
├── README.md                          ← This file
├── papers/                            ← Reference papers (PDF)
│   ├── paper-1-*.pdf                  [Paper A] Automated Security Validation...
│   └── paper-2-*.pdf                  [Paper B] Runtime Threat Mitigation...
├── research/
│   ├── 01-gap-analysis.md             Gap analysis between papers & our baseline
│   ├── 02-state-of-the-art.md         Current landscape & limitations
│   └── 03-design-decisions.md         Design rationale
├── implementation/
│   ├── falco/custom-rules.yaml         Custom Falco rules for shell detection
│   ├── kyverno/
│   │   ├── delete-suspicious-pods.yaml          ClusterPolicy (validate.deny)
│   │   └── terminate-compromised-pod.yaml       ClusterCleanupPolicy (backup)
│   └── webhook/
│       ├── Dockerfile                          Flask webhook container image
│       ├── app.py                              Webhook: labels + deletes pods
│       ├── requirements.txt                    Python dependencies
│       └── webhook-manifests.yaml              K8s manifests for webhook
├── policies/opa/
│   ├── image-policy.rego              Rego policy: untrusted registries
│   ├── resource-policy.rego           Rego policy: CPU/RAM limits
│   └── security-context-policy.rego   Rego policy: privilege & user context
├── scripts/
│   ├── run-opa-tests.sh               Runs 20 OPA test scenarios
│   └── run-runtime-tests.sh           Runs 5 runtime attack-remediation cycles
├── evaluation/
│   ├── metrics-before.md              Baseline metrics (before enhancement)
│   ├── metrics-after.md               Post-enhancement metrics
│   ├── analysis.md                    Comparative analysis & discussion
│   ├── test-log-opa.csv               Raw OPA test results (20 scenarios)
│   ├── test-log-runtime.csv           Raw runtime test results (5 runs)
│   └── test-manifests/                YAML manifests for testing
│       ├── opa/                       20 test manifests (S1-S4)
│       └── runtime/ubuntu-attacker.yaml
    ├── .gitlab-ci.yml                    Complete merged CI pipeline (baseline + Paper A)
    ├── ci/gitlab-ci-additions.yml        Reference: snippet of Paper A addition
    ├── kubernetes/                       Baseline K8s manifests (from week12)
    │   ├── deployment.yaml
    │   ├── service.yaml
    │   ├── namespace-dev.yaml
    │   └── namespace-prod.yaml
    ├── deploy.sh                         Baseline deployment script
    └── docs/
        └── refleksi-kelompok.md           Group reflection (3 questions)
```

---

## Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| Minikube | v1.30+ | Local Kubernetes cluster |
| kubectl | matching | K8s CLI |
| Helm | v3.x | Package manager for Kyverno |
| Docker | latest | Building webhook image |
| conftest | v0.55+ | OPA policy testing |
| Python | 3.11+ | Webhook server |
| bc / python3 | any | Timestamp precision |

---

## Setup from Scratch

### 1. Start Minikube

```bash
minikube start --driver=docker --cpus=2 --memory=4096
minikube status
```

### 2. Install Falco + Falcosidekick

```bash
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo update

helm install falco falcosecurity/falco -n falco --create-namespace \
  --set driver.kind=modern_ebpf \
  --set falcosidekick.enabled=true \
  --set falcosidekick.webhook.enabled=true \
  --set falcosidekick.config.webhook.address=http://falco-webhook.falco:5000/ \
  --wait
```

Copy custom Falco rules into the running DaemonSet pod:

```bash
FALCO_POD=$(kubectl get pods -n falco -l app.kubernetes.io/name=falco -o name | head -1)
kubectl cp implementation/falco/custom-rules.yaml $FALCO_POD:/etc/falco/rules.d/ -n falco
kubectl exec -n falco $FALCO_POD -- kill -HUP 1
```

### 3. Build & Deploy Webhook

```bash
eval $(minikube docker-env)
docker build -t falco-webhook:v4 implementation/webhook/
kubectl apply -f implementation/webhook/webhook-manifests.yaml
kubectl set image deployment/falco-webhook -n falco webhook=falco-webhook:v4
kubectl patch deployment falco-webhook -n falco -p \
  '{"spec":{"template":{"spec":{"containers":[{"name":"webhook","imagePullPolicy":"Never"}]}}}}'
kubectl rollout status deployment/falco-webhook -n falco
```

### 4. Configure Falcosidekick → Webhook Forwarding

```bash
WEBHOOK_URL=$(echo -n 'http://falco-webhook.falco:5000/' | base64)
kubectl patch secret -n falco falco-falcosidekick --type='json' \
  -p="[{\"op\": \"replace\", \"path\": \"/data/WEBHOOK_ADDRESS\", \"value\": \"$WEBHOOK_URL\"}]"
kubectl rollout restart deployment/falco-falcosidekick -n falco
```

### 5. Install Kyverno

```bash
helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo update
helm install kyverno kyverno/kyverno -n kyverno --create-namespace \
  --set cleanupController.enabled=true --wait

# Give cleanup controller pod delete permission
cat <<'RBAC' | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: kyverno-cleanup-pod-deleter
  labels:
    rbac.kyverno.io/aggregate-to-cleanup-controller: "true"
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list", "watch", "delete"]
RBAC

kubectl apply -f implementation/kyverno/terminate-compromised-pod.yaml
```

### 6. CI Pipeline (OPA Policy Check)

This repository already includes a complete merged `.gitlab-ci.yml` at the root, combining the baseline pipeline with the Paper A `validate-k8s-manifest` job. The `policy-check` stage runs `conftest test kubernetes/deployment.yaml --policy policies/opa/` and blocks non-compliant manifests before image build.

If you are integrating into a different baseline, see `ci/gitlab-ci-additions.yml` for the snippet to add.

---

## Enhancement A: Policy-as-Code (OPA/Conftest)

**Reference Paper:** Paper A — *Automated Security Validation in Healthcare DevSecOps: A Policy-as-Code Implementation for Kubernetes Environments*

Three Rego policies block non-compliant Kubernetes manifests at CI time:

| Policy | Rule | What It Blocks |
|--------|------|----------------|
| `image-policy.rego` | Only `registry.gitlab.com/*` allowed, `:latest` tag forbidden | Untrusted registries, mutable tags |
| `security-context-policy.rego` | Requires `runAsNonRoot: true`, blocks privileged containers | Root execution, privilege escalation |
| `resource-policy.rego` | Requires both `requests` and `limits`, max CPU 2000m | Unbounded resource usage |

The GitLab CI stage `validate-k8s-manifest` runs `conftest test` before image build, failing the pipeline on any violation.

---

## Enhancement B: Runtime Threat Mitigation (Falco + Kyverno)

**Reference Paper:** Paper B — *Runtime Threat Mitigation in Kubernetes Using Falco, Falcosidekick, and Kyverno*

End-to-end pipeline:

```
Falco (ebpf) → Falcosidekick → Webhook (label + delete pod) → Kyverno (backup cleanup)
```

1. **Falco** listens for shell spawns inside containers via `modern_ebpf` driver
2. **Falcosidekick** receives alerts and forwards them to the webhook
3. **Webhook** (Flask, port 5000):
   - Labels the compromised pod `suspicious=true`
   - Immediately deletes the pod with `--grace-period=0 --force`
4. **Kyverno ClusterCleanupPolicy** runs every minute as a backup to catch any missed pods

---

## Running Tests

### OPA Policy Tests (20 Scenarios)

```bash
chmod +x scripts/run-opa-tests.sh
./scripts/run-opa-tests.sh
cat evaluation/test-log-opa.csv
```

Expected: 20/20 PASS. Tests cover 4 categories:

- **S1** (5 tests): Image registry & tag policies
- **S2** (5 tests): Security context policies
- **S3** (5 tests): Resource limit policies
- **S4** (5 tests): Fully compliant manifests (ALLOW)

### Runtime Threat Tests (5 Iterations)

```bash
chmod +x scripts/run-runtime-tests.sh
./scripts/run-runtime-tests.sh 5
cat evaluation/test-log-runtime.csv
```

Each iteration:

1. Deploys `ubuntu-attacker` pod
2. Waits for Ready state
3. Executes `bash -c "echo simulated-attack"` (simulates shell spawn)
4. Measures **T1** (Falco detection time) and **T2** (pod deletion time)
5. Reports **MTTD = T1 - T0** and **MTTR = T2 - T1**

---

## Results Summary

### OPA Policy Enforcement

| Metric | Result |
|--------|--------|
| Test scenarios | 20 |
| Detection Rate | 100% (15/15 DENY correct) |
| False Positive Rate | 0% (5/5 ALLOW correct) |
| Avg Response Time | 54 ms |
| Pipeline Overhead | +1 stage (~2s) |

### Runtime Threat Mitigation

| Metric | Average |
|--------|---------|
| MTTD (Mean Time to Detect) | 0.60 s |
| MTTR (Mean Time to Remediate) | 0.24 s |
| Total (Attack → Pod Deleted) | 0.84 s |

---

## References

- Paper A: Automated Security Validation in Healthcare DevSecOps — A Policy-as-Code Implementation for Kubernetes Environments
- Paper B: Runtime Threat Mitigation in Kubernetes Using Falco, Falcosidekick, and Kyverno — An Automated Pod Deletion Approach
- [OPA / Conftest Documentation](https://www.openpolicyagent.org/docs/latest/)
- [Falco Documentation](https://falco.org/docs/)
- [Kyverno Documentation](https://kyverno.io/docs/)
