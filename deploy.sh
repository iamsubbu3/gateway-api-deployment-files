#!/bin/bash
set -euo pipefail

echo "=============================================="
echo "   Cilium Gateway + Observability Deployment"
echo "=============================================="

# ------------------------------------------------
# 0️⃣ Pre-checks
# ------------------------------------------------
echo "[INFO] Checking kubectl connectivity..."
kubectl cluster-info >/dev/null

echo "[INFO] Checking required namespaces..."
for ns in argocd monitoring observability kube-system; do
  kubectl get ns $ns >/dev/null
done

echo "[OK] Cluster connectivity verified."

# ------------------------------------------------
# 1️⃣ Apply Gateway API resources
# ------------------------------------------------
echo "----------------------------------------------"
echo "[STEP 1] Applying Gateway API resources"
echo "----------------------------------------------"

kubectl apply -f cilium-gateway-api/

# ------------------------------------------------
# 2️⃣ Apply Kubernetes configs ONLY
# ------------------------------------------------
echo "----------------------------------------------"
echo "[STEP 2] Applying app ConfigMaps"
echo "----------------------------------------------"

kubectl apply -f configs/argocd-cmd-params.yaml
kubectl apply -f configs/kibana-config.yaml

# ------------------------------------------------
# 3️⃣ Helm upgrade (Grafana + Prometheus)
# ------------------------------------------------
echo "----------------------------------------------"
echo "[STEP 3] Helm upgrade kube-prometheus-stack"
echo "----------------------------------------------"

helm upgrade monitoring prometheus-community/kube-prometheus-stack \
  -n monitoring \
  -f configs/grafana-values.yaml \
  -f configs/prometheus-values.yaml \
  --reuse-values

# ------------------------------------------------
# 4️⃣ Restart workloads
# ------------------------------------------------
echo "----------------------------------------------"
echo "[STEP 4] Restarting workloads"
echo "----------------------------------------------"

kubectl rollout restart deployment argocd-server -n argocd
kubectl rollout restart deployment monitoring-grafana -n monitoring
kubectl rollout restart deployment kibana -n observability

echo "[INFO] Waiting for rollouts..."

kubectl rollout status deployment argocd-server -n argocd
kubectl rollout status deployment monitoring-grafana -n monitoring
kubectl rollout status deployment kibana -n observability

# ------------------------------------------------
# 5️⃣ Validation
# ------------------------------------------------
echo "----------------------------------------------"
echo "[STEP 5] Gateway validation"
echo "----------------------------------------------"

kubectl get gateway -n monitoring
kubectl get httproute -A

GATEWAY_ADDR=$(kubectl get gateway monitoring-gateway \
  -n monitoring \
  -o jsonpath='{.status.addresses[0].value}')

echo ""
echo "=============================================="
echo "✅ DEPLOYMENT COMPLETE"
echo ""
echo "Gateway URL:"
echo "http://$GATEWAY_ADDR"
echo ""
echo "Access:"
echo "http://$GATEWAY_ADDR/argocd"
echo "http://$GATEWAY_ADDR/grafana"
echo "http://$GATEWAY_ADDR/prometheus"
echo "http://$GATEWAY_ADDR/kibana"
echo "=============================================="
