package k8s.security_context

# ============================================================
# Security Context Policy - berdasarkan Paper A
# Menutup gap: container bisa berjalan sebagai root / privileged
# tanpa ada yang mencegah
# ============================================================

# S2-01: Container TIDAK BOLEH eksplisit jalan sebagai root (uid 0)
deny[msg] {
    resource := input.review.object
    resource.kind == "Deployment"
    container := resource.spec.template.spec.containers[_]
    container.securityContext.runAsUser == 0
    msg := sprintf(
        "FAIL [security-context]: Container '%s' dikonfigurasi berjalan sebagai root (runAsUser: 0).",
        [container.name]
    )
}

# S2-02: Container WAJIB punya securityContext.runAsNonRoot: true
deny[msg] {
    resource := input.review.object
    resource.kind == "Deployment"
    container := resource.spec.template.spec.containers[_]
    not container.securityContext.runAsNonRoot == true
    msg := sprintf(
        "FAIL [security-context]: Container '%s' tidak memiliki runAsNonRoot: true.",
        [container.name]
    )
}

# S2-04: Container TIDAK BOLEH privileged
deny[msg] {
    resource := input.review.object
    resource.kind == "Deployment"
    container := resource.spec.template.spec.containers[_]
    container.securityContext.privileged == true
    msg := sprintf(
        "FAIL [security-context]: Container '%s' berjalan dalam mode privileged.",
        [container.name]
    )
}

# S2-05: Container TIDAK BOLEH mengizinkan privilege escalation
deny[msg] {
    resource := input.review.object
    resource.kind == "Deployment"
    container := resource.spec.template.spec.containers[_]
    container.securityContext.allowPrivilegeEscalation == true
    msg := sprintf(
        "FAIL [security-context]: Container '%s' mengizinkan allowPrivilegeEscalation.",
        [container.name]
    )
}

# S2-03: Lolos jika runAsNonRoot: true DAN runAsUser bukan 0
