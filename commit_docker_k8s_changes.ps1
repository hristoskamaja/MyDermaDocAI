# Commits all the Docker / Compose / CI / Kubernetes work for the DevOps
# assignment, in logical groups, on the docker-k8s branch.
#
# Run from the repo root:
#   .\commit_docker_k8s_changes.ps1

$ErrorActionPreference = "Stop"

# 1) Backend Dockerization
git add `
  skin_backend/Dockerfile `
  skin_backend/entrypoint.sh `
  skin_backend/.dockerignore `
  skin_backend/requirements.txt `
  skin_backend/skin_scan/settings.py
git commit -m "Backend: Dockerize (gunicorn, whitenoise, entrypoint, prod settings)"

# 2) Frontend Dockerization
git add `
  skin_web/Dockerfile `
  skin_web/nginx.conf `
  skin_web/.dockerignore
git commit -m "Web: Dockerize with nginx reverse proxy to backend"

# 3) Local orchestration (Docker Compose) + supporting repo config
git add `
  docker-compose.yml `
  .env.example `
  .gitattributes `
  .gitignore
git commit -m "Add docker-compose.yml for local orchestration"

# 4) CI/CD pipeline
git add .github/
git commit -m "Add GitHub Actions CI/CD: build+push images, deploy to K8s"

# 5) Kubernetes manifests
git add k8s/
git commit -m "Add Kubernetes manifests (namespace, app + Postgres, ingress)"

# 6) Guide
git add DOCKER_K8S_GUIDE.md
git commit -m "Add step-by-step Docker/K8s run and demo guide"

Write-Host ""
Write-Host "Done. git log --oneline -8 to check:"
git log --oneline -8

Write-Host ""
Write-Host "Remaining (should be empty or just leftover helper scripts):"
git status --short
