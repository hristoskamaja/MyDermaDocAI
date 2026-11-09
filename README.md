# DermaScanAI

AI-assisted skin condition scanning app (Django backend + React web + Flutter mobile).

**Features**: photo-based skin condition scan (local AI model), AI chat about results,
richer recommendations (what to do / what to avoid / when to see a doctor), PDF export,
dermatologist finder (GPS/city-based), bilingual EN/MK, light/dark theme, admin panel,
and a personal **skin tracker** (see below).

**Skin tracker** (web "Track" section and the mobile "Track" tab):

- **Daily check-in** - skin rating, breakout level and areas (face map), optional private
  photo, food and drink, sleep, stress, optional cycle phase, and a morning/evening routine
  checklist. One check-in per day, editable the same day.
- **Hub** - today's status, streak (current and best), "This week" strip, category tiles.
- **Timeline** - breakouts over 30/90 days with sleep, stress and cycle overlays, a
  before/after photo compare, and the scans you saved with "Save to tracking".
- **AI insights** - patterns found in your own check-ins (plain statistics, not a black
  box), a correlation explorer for sleep / stress / acne, and "Ask AI about my patterns".
  Insights need at least 7 logged days. The confidence score is a heuristic based on sample
  size and effect size, **not a probability**, and the wording describes patterns, never
  causes or medical advice.
- **Routine** - your skincare shelf (cleanse / treat / hydrate / protect, AM / PM).
- **Weekly report** - this week vs last week, shareable (text, or an image).
- **Reminders** - settings are saved to your account; notifications are coming soon.
- **Privacy** - tracking data is private to the user. Photos are stored outside the public
  media folder and are only served to their owner. Cycle tracking is opt-in. "Delete all my
  tracking data" is in Track > Reminders.

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

Open the folder in Android Studio and run, or use `flutter run` from `skin_mobile/`.

The weekly report uses `share_plus` (installed by `flutter pub get`). Local notifications for
reminders are not implemented yet.

#### Day-to-day commands (local, no Docker)

```
# Backend (from skin_backend/, venv active)
python manage.py runserver
python manage.py test                       # backend tests (Gemini and the AI model are mocked)

# Web (from skin_web/)
npm start
npm run build                               # production build check

# Mobile (from skin_mobile/)
flutter run
flutter analyze
flutter test
```

#### Useful backend commands

```
python manage.py seed_skin_conditions                  # 8 conditions with EN + MK text
python manage.py fill_missing_translations             # fill empty *_en fields (needs GEMINI_API_KEY)
python manage.py regenerate_recommendations --help     # rebuild cached recommendations for a condition
python manage.py seed_demo_tracking --email you@example.com --days 30 --reset
```

`seed_demo_tracking` is **dev only** (it refuses to run when `DEBUG` is False). It fills one
existing user's tracker with synthetic check-ins - including planted patterns such as poor
sleep followed by worse breakouts and luteal-phase flare-ups - plus a few products and
reminder settings with cycle tracking on. `--reset` first deletes only that user's tracking
data. Use it to see the timeline and insights without logging for weeks.

#### Trying the tracker

1. Start the backend, web and (optionally) the mobile app as above, and log in.
2. Either log a few check-ins yourself, or run `seed_demo_tracking` for your account.
3. Open **Track**: do a check-in, then look at Timeline, AI insights, Routine and Weekly
   report. On a scan result, use **Save to tracking** to add the scan to your timeline.
4. A brand-new account shows "Start tracking your skin", and insights show "Not enough data
   yet" until 7 days are logged.

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
