package main

resource := input.review.object if input.review.object
resource := input if not input.review.object

# ============================================================
# Resource Limits Policy - berdasarkan Paper A
# Menutup gap: container bisa deploy tanpa batas CPU/memory,
# berisiko satu pod menghabiskan seluruh resource node
# ============================================================

# S3-01: Container WAJIB punya blok resources
deny contains msg if {
    resource.kind == "Deployment"
    container := resource.spec.template.spec.containers[_]
    not container.resources
    msg := sprintf(
        "FAIL [resource-policy]: Container '%s' tidak memiliki blok resources sama sekali.",
        [container.name]
    )
}

# S3-02: Container WAJIB punya resources.limits (bukan cuma requests)
deny contains msg if {
    resource.kind == "Deployment"
    container := resource.spec.template.spec.containers[_]
    container.resources
    not container.resources.limits
    msg := sprintf(
        "FAIL [resource-policy]: Container '%s' tidak memiliki resources.limits.",
        [container.name]
    )
}

# S3-03: Container WAJIB punya resources.requests (bukan cuma limits)
deny contains msg if {
    resource.kind == "Deployment"
    container := resource.spec.template.spec.containers[_]
    container.resources
    not container.resources.requests
    msg := sprintf(
        "FAIL [resource-policy]: Container '%s' tidak memiliki resources.requests.",
        [container.name]
    )
}

# S3-05: CPU limit TIDAK BOLEH lebih dari 2 core (2000m) -- batas wajar untuk pipeline kelompok ini
deny contains msg if {
    resource.kind == "Deployment"
    container := resource.spec.template.spec.containers[_]
    limit := container.resources.limits.cpu
    endswith(limit, "m")
    value := to_number(trim_suffix(limit, "m"))
    value > 2000
    msg := sprintf(
        "FAIL [resource-policy]: Container '%s' meminta CPU limit %s, melebihi batas wajar 2000m.",
        [container.name, limit]
    )
}

# S3-04: Lolos jika requests DAN limits ada dengan nilai wajar
