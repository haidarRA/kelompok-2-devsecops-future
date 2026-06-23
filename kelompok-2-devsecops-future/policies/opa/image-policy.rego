package main

resource := input.review.object if input.review.object
resource := input if not input.review.object

# ============================================================
# Image Policy - berdasarkan Paper A (Stanišić et al., 2026)
# Menutup gap: tidak ada validasi sumber & tag image sebelum deploy
# ============================================================

# S1-01, S1-04: Image HARUS berasal dari registry resmi tim
deny contains msg if {
    resource.kind == "Deployment"
    container := resource.spec.template.spec.containers[_]
    not startswith(container.image, "registry.gitlab.com/")
    msg := sprintf(
        "FAIL [image-policy]: Container '%s' menggunakan image dari registry tidak resmi: %s. Hanya registry.gitlab.com/* yang diizinkan.",
        [container.name, container.image]
    )
}

# S1-02: Image TIDAK BOLEH menggunakan tag ':latest' (tidak reproducible)
deny contains msg if {
    resource.kind == "Deployment"
    container := resource.spec.template.spec.containers[_]
    endswith(container.image, ":latest")
    msg := sprintf(
        "FAIL [image-policy]: Container '%s' menggunakan tag ':latest'. Gunakan tag SHA commit (sha-xxxxxxx) agar reproducible.",
        [container.name]
    )
}

# S1-05: Image WAJIB punya tag eksplisit (tidak boleh kosong)
deny contains msg if {
    resource.kind == "Deployment"
    container := resource.spec.template.spec.containers[_]
    not contains(container.image, ":")
    msg := sprintf(
        "FAIL [image-policy]: Container '%s' tidak memiliki tag image yang eksplisit: %s",
        [container.name, container.image]
    )
}

# S1-03: Lolos jika image dari registry.gitlab.com DENGAN tag sha-xxxxxxx
# (tidak perlu rule eksplisit -- otomatis lolos kalau tidak kena deny di atas)
