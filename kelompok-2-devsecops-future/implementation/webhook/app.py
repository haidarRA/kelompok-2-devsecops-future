import logging
import time

import urllib3
from flask import Flask, request, jsonify
from kubernetes import client, config

app = Flask(__name__)

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("falco-webhook")

config.load_incluster_config()
cfg = client.Configuration.get_default_copy()
cfg.connection_pool_size = 10
cfg.retries = urllib3.Retry(
    total=2,
    backoff_factor=0.5,
    status_forcelist=[500, 502, 503, 504],
)
api = client.CoreV1Api(api_client=client.ApiClient(configuration=cfg))




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

    if rule != "Terminal shell in container":
        logger.info("Skipping non-shell rule=%s for %s/%s", rule, ns, pod)
        return jsonify({"status": "skipped_unrelated_rule", "pod": pod, "namespace": ns}), 200

    try:
        api.patch_namespaced_pod(
            pod, ns, {"metadata": {"labels": {"suspicious": "true"}}}
        )
    except client.exceptions.ApiException as e:
        if e.status == 404:
            logger.info("Pod %s already gone, skipping label", pod)
            return jsonify({"status": "already_remediated", "pod": pod, "namespace": ns}), 200
        logger.error("Gagal label pod %s: %s", pod, e)
        return jsonify({"error": "failed to label pod", "detail": str(e)}), 500

    t_labeled = time.time()
    logger.info(
        "POD LABELED | pod=%s ns=%s label_latency_ms=%.1f",
        pod, ns, (t_labeled - t_received) * 1000,
    )

    try:
        api.delete_namespaced_pod(pod, ns, grace_period_seconds=0)
    except client.exceptions.ApiException as e:
        if e.status == 404:
            logger.info("Pod %s already deleted, skipping", pod)
        else:
            logger.error("Gagal delete pod %s: %s", pod, e)
        return jsonify({
            "status": "labeled_but_delete_failed",
            "pod": pod, "namespace": ns,
            "label_latency_ms": round((t_labeled - t_received) * 1000, 1),
            "delete_error": str(e),
        }), 200

    t_deleted = time.time()
    logger.info(
        "POD DELETED | pod=%s ns=%s total_latency_ms=%.1f",
        pod, ns, (t_deleted - t_received) * 1000,
    )
    return jsonify({
        "status": "remediated",
        "pod": pod, "namespace": ns,
        "label_latency_ms": round((t_labeled - t_received) * 1000, 1),
        "delete_latency_ms": round((t_deleted - t_labeled) * 1000, 1),
        "total_latency_ms": round((t_deleted - t_received) * 1000, 1),
    }), 200


@app.route("/healthz", methods=["GET"])
def healthz():
    return jsonify({"status": "ok"}), 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
