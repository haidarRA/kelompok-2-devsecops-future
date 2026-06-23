# State of the Art — Current Landscape and Limitations

## 1. Policy-as-Code for Kubernetes

### Current Landscape

Policy-as-Code (PaC) has emerged as a standard practice for enforcing security and operational policies in Kubernetes environments. The dominant tools in this space are:

- **Open Policy Agent (OPA)** / **Conftest**: The de facto standard for writing policies as Rego rules. OPA decouples policy decision-making from policy enforcement, making it suitable for both admission control and CI pipeline integration.
- **Kyverno**: A Kubernetes-native policy engine that uses custom resources (`ClusterPolicy`, `Policy`) instead of a separate policy language. Kyverno supports validate, mutate, and generate rules.
- **KubeLinter**: A static analysis tool from StackRox (Red Hat) that checks Kubernetes YAML files against security best practices.
- **Checkov**: A broader infrastructure-as-code scanner that supports Kubernetes, Terraform, CloudFormation, and others.

Paper A (our reference) adopts OPA/Conftest for healthcare DevSecOps, citing its flexibility, ecosystem maturity, and ability to run both in CI pipelines and as a Kubernetes admission webhook. Their testbed used 50 Kubernetes manifest variations across 10 policy categories, achieving a 92% detection rate with an average policy evaluation time of 45 ms.

### Limitations of Current Approaches

1. **Limited policy scope**: Most PaC implementations focus on a narrow set of policies (typically image provenance and privilege mode). Paper A demonstrates that a broader scope—including resource limits, security context, and network policies—is necessary for compliance with standards like HIPAA and NIST.
2. **Pipeline integration friction**: Teams often skip PaC integration because it adds a new stage to existing CI pipelines. Paper A shows the overhead is only 3.5% of total pipeline time, but adoption remains low in practice.
3. **False positive management**: Overly strict policies can block legitimate deployments, causing developer frustration. Our approach mitigates this through the S4 (fully compliant) test suite, validating that legitimate manifests pass all policies.

---

## 2. Runtime Security for Containers

### Current Landscape

Runtime security in Kubernetes is primarily addressed through:

- **Falco**: The CNCF-graduated runtime security project that uses eBPF (or kernel modules) to intercept system calls. Falco rules detect shell spawning, file tampering, network anomalies, and privilege escalation.
- **Tracee**: An alternative runtime security tool from Aqua Security that uses eBPF for tracing and detection. Provides deeper visibility but steeper learning curve.
- **Sysdig Secure**: A commercial platform built on Falco's engine, adding compliance dashboards, incident response, and integration with SIEM systems.
- **Cilium Tetragon**: Uses eBPF for security observability and enforcement, with a focus on identity-aware policies.

Paper B (our reference) uses Falco with Falcosidekick for alert forwarding and Kyverno for automated remediation. Their architecture is notable for using Falcosidekick's webhook output to trigger a labeling mechanism, which Kyverno then detects and acts upon.

### Limitations of Current Approaches

1. **Detection-only, no response**: Many Falco deployments stop at alerting (via Slack, email, or SIEM). Paper B's contribution is closing the loop from detection to automated response, achieving near-real-time MTTR.
2. **Falco rule tuning**: Default Falco rules generate false positives in development environments. Our implementation uses a targeted custom rule that specifically watches for `bash` or `sh` processes spawned by user interaction (`proc.name in [bash, sh, zsh]`), reducing noise.
3. **Kyverno cleanup policy**: Standard Kyverno `ClusterPolicy` with `validate.deny` only blocks admission of new pods with matching labels. It does not delete running pods that acquire the label after creation. Paper B's approach requires either a `ClusterCleanupPolicy` (available in Kyverno 1.9+) or an external webhook to delete the pod directly. Our implementation uses both: the webhook deletes immediately, and the `ClusterCleanupPolicy` serves as a backup.

---

## 3. Automated Remediation in Kubernetes

### Current Landscape

Automated remediation for security incidents in Kubernetes is an active research area:

- **Kubernetes Event-Driven Autoscaling (KEDA)** can trigger responses based on events but is designed for scaling, not security.
- **Kyverno Generate rules** can create resources in response to events but do not support deletion of existing resources.
- **Custom webhooks** (as used in Paper B and our implementation) offer the fastest response but require additional infrastructure and RBAC.
- **Falcosidekick** provides multiple output mechanisms (webhook, Slack, AWS Lambda, GCP Cloud Functions), but none natively support pod deletion.



### Why Our Approach Advances the State of the Art

Our implementation combines three remediation layers for defense in depth:

1. **Immediate deletion** (webhook, sub-second MTTR): The Flask webhook receives the Falco alert and immediately deletes the compromised pod.
2. **Label-based backup** (Kyverno ClusterCleanupPolicy, ~1 min interval): Runs every minute to catch any pods that the webhook missed due to network issues or temporary failures.
3. **Admission prevention** (Kyverno ClusterPolicy with validate.deny): Prevents new pods with `suspicious=true` from being created, blocking potential re-deployment of compromised configurations.

This layered approach addresses a gap in both Paper A (no runtime response) and Paper B (relies on single-path remediation).


### Implementation in This Project

This project implements a **three-layer defense-in-depth remediation architecture**:

#### Layer 1: Immediate Webhook-Based Deletion

**Flask Webhook** (`implementation/webhook/app.py`):
- Receives real-time Falco alerts from Falcosidekick
- Extracts pod name and namespace from alert payload
- Labels pod with `suspicious=true` (first latency point)
- Immediately deletes pod with `grace_period_seconds=0` (force deletion)
- Logs all latency metrics for observability

**Response Latency Metrics** (from `evaluation/test-log-runtime.csv`):
- **Label Latency**: 0.244 seconds average (sub-second) — time from alert received to pod labeled
- **Delete Latency**: 0.119 seconds average — time from label applied to pod terminated
- **Total MTTR**: 0.844 seconds average (range: 0.568–1.477s)

#### Layer 2: Kyverno ClusterPolicy (Admission Prevention)

**Policy** (`implementation/kyverno/delete-suspicious-pods.yaml`):
```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: delete-suspicious-pods
spec:
  rules:
    - name: delete-pods-on-label
      match:
        any:
          - resources:
              kinds:
                - Pod
              selector:
                matchLabels:
                  suspicious: "true"
      validate:
        message: "Suspicious pod detected. Auto-remediation triggered by runtime threat mitigation policy."
        deny: {}
```
- Prevents creation of new pods with label suspicious=true
- Acts as a backup if webhook fails to delete a pod but successfully labels it
- Provides hard security boundary at admission controller

#### Layer 3: Kyverno ClusterCleanupPolicy (Scheduled Backup Cleanup)

**Policy** (`implementation/kyverno/terminate-compromised-pod.yaml`):
```yaml
apiVersion: kyverno.io/v2
kind: ClusterCleanupPolicy
metadata:
  name: terminate-compromised-pod
spec:
  schedule: "*/1 * * * *"
  deletionPropagationPolicy: Background
  match:
    any:
      - resources:
          kinds:
            - Pod
          selector:
            matchLabels:
              suspicious: "true"
```
- Runs every minute as a background cleanup task
- Catches pods the webhook missed due to network transients or timing issues
- Ensures no compromised pod survives beyond ~1 minute even if webhook fails
- Provides resilience through eventual consistency

        
