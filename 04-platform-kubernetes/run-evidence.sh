#!/usr/bin/env bash
D=~/cloud-capstone-TIM/04-platform-kubernetes
IMG=capstone-app:v0.1.0
r(){ echo "\$ $1"; eval "$1"; }
panel(){ echo; read -rp ">>> Siap. Tekan Enter untuk panel: $1 (lalu screenshot)" _; clear; echo "== $1 =="; date; echo; }

cd "$D" || exit 1

# ---- file sumber (ikut jadi deliverable) ----
cat > default.conf <<'EOF'
server {
  listen 8080;
  location = /q/health/ready { default_type application/json; return 200 '{"status":"UP"}'; }
  location = /q/health/live  { default_type application/json; return 200 '{"status":"UP"}'; }
  location / { root /usr/share/nginx/html; }
}
EOF
echo "<h1>Online Exam Platform (stand-in)</h1>" > index.html
cat > Dockerfile <<'EOF'
FROM nginx:alpine
COPY default.conf /etc/nginx/conf.d/default.conf
COPY index.html /usr/share/nginx/html/index.html
EOF
cat > app.yaml <<'EOF'
apiVersion: v1
kind: Namespace
metadata: {name: capstone}
---
apiVersion: v1
kind: ConfigMap
metadata: {name: capstone-app-config, namespace: capstone}
data: {APP_ENV: "lab", TENANT_MODE: "shared-schema"}
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: capstone-app, namespace: capstone}
spec:
  replicas: 2
  selector: {matchLabels: {app: capstone-app}}
  template:
    metadata: {labels: {app: capstone-app}}
    spec:
      containers:
      - name: app
        image: registry:5000/capstone-app:v0.1.0
        ports: [{containerPort: 8080}]
        envFrom: [{configMapRef: {name: capstone-app-config}}]
        readinessProbe: {httpGet: {path: /q/health/ready, port: 8080}, initialDelaySeconds: 3, periodSeconds: 5}
        livenessProbe:  {httpGet: {path: /q/health/live,  port: 8080}, initialDelaySeconds: 10, periodSeconds: 10}
        resources:
          requests: {cpu: 100m, memory: 192Mi}
          limits: {cpu: 500m, memory: 512Mi}
---
apiVersion: v1
kind: Service
metadata: {name: capstone-app, namespace: capstone}
spec:
  selector: {app: capstone-app}
  ports: [{port: 80, targetPort: 8080}]
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata: {name: capstone-app, namespace: capstone}
spec:
  ingressClassName: traefik
  rules:
  - host: capstone.localhost
    http:
      paths:
      - {path: /, pathType: Prefix, backend: {service: {name: capstone-app, port: {number: 80}}}}
EOF

panel "1 Versi tools"
r "kubectl version; k3d version; docker --version"

panel "2 Cluster nodes"
r "kubectl get nodes -o wide | cut -c1-150"

panel "3 Dockerfile + build + push"
r "cat Dockerfile"
r "docker build --provenance=false -t localhost:5001/$IMG ."
r "docker push localhost:5001/$IMG"
r "curl -s http://127.0.0.1:5001/v2/capstone-app/tags/list"

panel "4 Deploy manifest"
r "kubectl apply -f app.yaml"
r "kubectl -n capstone rollout status deploy/capstone-app --timeout=120s"

panel "5 Semua objek"
r "kubectl -n capstone get all,ingress,configmap"

panel "6 Probes dan resources"
r "kubectl -n capstone describe deploy capstone-app | grep -A8 -E 'Image:|Liveness|Readiness|Limits|Requests'"

panel "7 Image di pod = image di registry"
r "kubectl -n capstone get deploy capstone-app -o wide"
r "kubectl -n capstone describe pod -l app=capstone-app | grep -E 'Image:|Image ID:'"

panel "8 Akses lewat ingress"
r "curl -i -H 'Host: capstone.localhost' http://127.0.0.1:8088/q/health/ready"

panel "9 Scale 2 ke 3 (readiness menahan pod baru)"
r "kubectl -n capstone scale deploy capstone-app --replicas=3"
r "kubectl -n capstone get pods -o wide"
r "sleep 12; kubectl -n capstone get pods"
r "kubectl -n capstone scale deploy capstone-app --replicas=2"
r "sleep 5; kubectl -n capstone get deploy capstone-app"

panel "10 Hapus 1 pod (self-healing)"
r 'POD=$(kubectl -n capstone get pod -l app=capstone-app -o name | head -1); echo $POD'
r 'kubectl -n capstone delete $POD --wait=false'
r "curl -s -o /dev/null -w 'HTTP %{http_code}\n' -H 'Host: capstone.localhost' http://127.0.0.1:8088/q/health/ready"
r "kubectl -n capstone get pods"
r "sleep 15; kubectl -n capstone get pods"

panel "11 Rolling restart + history"
r "kubectl -n capstone rollout restart deploy/capstone-app"
r "kubectl -n capstone rollout status deploy/capstone-app"
r "kubectl -n capstone rollout history deploy/capstone-app"

echo; echo "SELESAI. Screenshot disimpan di $D/shots"
