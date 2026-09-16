# DermaScanAI

AI-assisted skin condition scanning app (Django backend + React web + Flutter mobile).

**Features**: photo-based skin condition scan (local AI model), AI chat about results,
PDF export, dermatologist finder (GPS/city-based), bilingual EN/MK, admin panel.

**Not a medical diagnosis** - a preliminary estimate that points users to a dermatologist.

## Tech stack

Django REST Framework, PostgreSQL, JWT auth, PyTorch/EfficientNet-B3, Google Gemini API,
ReportLab, Gunicorn/WhiteNoise, React, Flutter, Docker, Docker Compose, Kubernetes,
GitHub Actions (CI/CD), Docker Hub, Azure Kubernetes Service (AKS)

## Structure

```
skin_backend/    Django REST API (auth, conditions, analyses, analytics, AI inference)
skin_web/        React web app (patient-facing pages + admin panel)
skin_mobile/     Flutter app for end users (scan a photo, see results + recommendations)
skin_disease_training.ipynb   Google Colab notebook to train/retrain the classifier
k8s/             Kubernetes manifests (namespace, ConfigMaps/Secrets, Deployments,
                 Services, StatefulSet, Ingress)
.github/workflows/  CI/CD pipeline (build, push to Docker Hub, deploy to K8s)
```

## Ways to run this project

Pick whichever fits what you're doing: plain local dev for coding, Docker Compose for a
quick full-stack run, or Kubernetes (local or Azure) to see the production-style setup.

### 1. Local dev (no Docker)

**Backend** (`skin_backend/`):

```
cd skin_backend
python -m venv .venv
.venv\Scripts\activate          # Windows
pip install -r requirements.txt
copy .env.example .env          # then fill in real values
python manage.py migrate
python manage.py seed_skin_conditions
python manage.py createsuperuser
python manage.py runserver
```

The AI model is not included in this repo (see `.gitignore` — it's a large binary
artifact, not source code). Train it yourself via `skin_disease_training.ipynb` in
Google Colab, then place the two output files here:

- `skin_backend/analyses/services/ai_model/skin_model.pt`
- `skin_backend/analyses/services/label_converter.json`

Until those exist, every other endpoint works normally except `/api/analyses/scan-skin/`,
which will return a clear `502` explaining the model is missing.

**Web** (`skin_web/`):

```
cd skin_web
npm install
npm start
```

**Mobile** (`skin_mobile/`):

```
cd skin_mobile
flutter pub get
```

Set the backend base URL in `lib/services/api_config.dart`:
- Android emulator: `http://10.0.2.2:8000/api` (default)
- Physical device: your computer's LAN IP, e.g. `http://192.168.1.23:8000/api`
  (and run Django with `python manage.py runserver 0.0.0.0:8000`, same WiFi network)

Open the folder in Android Studio and run.

### 2. Docker Compose (backend + web + Postgres)

```
copy .env.example .env          # then fill in real values
docker compose up --build
```

- Web: http://localhost:3000
- Backend API: http://localhost:8000/api
- Django admin: http://localhost:8000/admin

First run only, seed the fresh database:

```
docker compose exec backend python manage.py createsuperuser
docker compose exec backend python manage.py seed_skin_conditions
docker compose exec backend python manage.py scrape_dermatologists
```

### 3. Kubernetes — local (Docker Desktop)

Requires Docker Desktop with Kubernetes enabled, and the nginx ingress controller:

```
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.3/deploy/static/provider/cloud/deploy.yaml
```

Copy the two secret templates and fill in real values:

```
copy k8s\02-backend-secret.example.yaml k8s\02-backend-secret.yaml
copy k8s\07-postgres-secret.example.yaml k8s\07-postgres-secret.yaml
```

Apply everything and seed the database (first run only):

```
kubectl apply -f k8s/
kubectl exec -it <backend-pod-name> -n skinscan -- python manage.py createsuperuser
kubectl exec -it <backend-pod-name> -n skinscan -- python manage.py seed_skin_conditions
kubectl exec -it <backend-pod-name> -n skinscan -- python manage.py scrape_dermatologists
```

App: http://localhost (Ingress, port 80)

### 4. Kubernetes — Azure (AKS, real cloud deployment)

```
az login
az group create --name skinscan-rg --location polandcentral
az aks create --resource-group skinscan-rg --name skinscan-aks --location polandcentral --node-count 1 --node-vm-size Standard_B2s_v2 --generate-ssh-keys --tier free
az aks get-credentials --resource-group skinscan-rg --name skinscan-aks
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.3/deploy/static/provider/cloud/deploy.yaml
kubectl apply -f k8s/
```

Then seed the database the same way as the local K8s setup above. Get the public IP:

```
kubectl get svc -n ingress-nginx ingress-nginx-controller
```

App: `http://<EXTERNAL-IP>`

To save Azure credit when not in use:

```
az aks stop --resource-group skinscan-rg --name skinscan-aks
az aks start --resource-group skinscan-rg --name skinscan-aks   # before next use
```

## CI/CD

GitHub Actions (`.github/workflows/docker-publish.yml`):

- **CI**: on every push, builds the backend and web Docker images and pushes them to
  Docker Hub
- **CD** (bonus): a self-hosted runner (on a local machine, required because the target
  Kubernetes cluster is not publicly reachable) then rolls out the new images to the
  local Kubernetes deployment

Required repo secrets: `DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN`, `DJANGO_SECRET_KEY`,
`DB_PASSWORD`, `GEMINI_API_KEY`.
