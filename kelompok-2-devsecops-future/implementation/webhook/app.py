"""
Flask webhook server - berdasarkan Paper B (Shenoy et al., 2025)

Menerima alert JSON dari Falcosidekick, lalu memberi label
`suspicious=true` pada pod yang terdeteksi -- label inilah yang
kemudian dibaca oleh Kyverno ClusterPolicy untuk menghapus pod
secara otomatis.

Alur lengkap:
  Falco deteksi shell spawn
    -> Falcosidekick forward alert ke webhook ini (POST /)
    -> Webhook label pod sebagai suspicious=true
    -> Kyverno ClusterPolicy hapus pod berlabel suspicious=true
"""

import logging
import subprocess
import time

from flask import Flask, request, jsonify

app = Flask(__name__)

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("falco-webhook")


@app.route("/", methods=["POST"])
def alert():
    t_received = time.time()
    data = request.get_json(force=True, silent=True)

    if not data:
        logger.warning("Menerima payload kosong atau bukan JSON")
        return jsonify({"error": "invalid payload"}), 400

    try:
        pod = data["output_fields"]["k8s.pod.name"]
        ns = data["output_fields"]["k8s.ns.name"]
    except KeyError:
        # Fallback untuk variasi field name pada versi Falco berbeda
        try:
            pod = data["output_fields"]["k8s.pod.name"]
            ns = data["output_fields"]["k8s.namespace.name"]
        except KeyError:
            logger.error("Payload tidak memiliki field pod/namespace yang diharapkan: %s", data)
            return jsonify({"error": "missing pod/namespace fields"}), 400

    rule = data.get("rule", "unknown")
    priority = data.get("priority", "unknown")

    logger.info(
        "ALERT RECEIVED | rule=%s priority=%s pod=%s ns=%s t=%.3f",
        rule, priority, pod, ns, t_received,
    )

    result = subprocess.run(
        ["kubectl", "label", "pod", pod, "suspicious=true", f"-n{ns}", "--overwrite"],
        capture_output=True,
        text=True,
    )

    t_labeled = time.time()

    if result.returncode != 0:
        logger.error("Gagal label pod %s: %s", pod, result.stderr)
        return jsonify({"error": "failed to label pod", "detail": result.stderr}), 500

    logger.info(
        "POD LABELED | pod=%s ns=%s label_latency_ms=%.1f",
        pod, ns, (t_labeled - t_received) * 1000,
    )

    # Also delete pod immediately for automated remediation (MTTR)
    result = subprocess.run(
        ["kubectl", "delete", "pod", pod, f"-n{ns}", "--grace-period=0", "--force", "--wait=false"],
        capture_output=True, text=True,
    )
    t_deleted = time.time()
    if result.returncode != 0:
        logger.error("Gagal delete pod %s: %s", pod, result.stderr)
        return jsonify({
            "status": "labeled_but_delete_failed",
            "pod": pod,
            "namespace": ns,
            "label_latency_ms": round((t_labeled - t_received) * 1000, 1),
            "delete_error": result.stderr,
        }), 200

    logger.info(
        "POD DELETED | pod=%s ns=%s total_latency_ms=%.1f",
        pod, ns, (t_deleted - t_received) * 1000,
    )
    return jsonify({
        "status": "remediated",
        "pod": pod,
        "namespace": ns,
        "label_latency_ms": round((t_labeled - t_received) * 1000, 1),
        "delete_latency_ms": round((t_deleted - t_labeled) * 1000, 1),
        "total_latency_ms": round((t_deleted - t_received) * 1000, 1),
    }), 200


@app.route("/healthz", methods=["GET"])
def healthz():
    return jsonify({"status": "ok"}), 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
