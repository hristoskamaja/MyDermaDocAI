# Docker + Docker Compose + CI + Kubernetes — упатство

Ова е водич чекор-по-чекор за DevOps задачата, врз основа на веќе
изработените фајлови во овој репо (`Dockerfile`-и, `docker-compose.yml`,
`.github/workflows/docker-publish.yml`, `k8s/`).

## 0. Гранка (да не се допира главната работа)

```powershell
git checkout -b docker-k8s
```

Сите промени од тука натаму (Dockerfile-и, compose, CI, k8s) одат во оваа
гранка. Главната (`master`) си останува недопрена.

## 1. Локално тестирање со Docker Compose

```powershell
copy .env.example .env
```

Отвори `.env` и пополни:
- `DJANGO_SECRET_KEY` — произволен долг стринг
- `POSTGRES_PASSWORD` — произволна лозинка
- `GEMINI_API_KEY` — опционално (без него, препораките/чатот паѓаат на fallback текст)

Потоа:

```powershell
docker compose up --build
```

Прв пат ќе трае подолго (torch/torchvision се големи). Кога ќе заврши:
- Апликација: http://localhost:3000
- Backend директно: http://localhost:8000/api/
- Django admin: http://localhost:3000/admin/

Проверка дека базата е Postgres не SQLite: `docker compose exec backend python manage.py showmigrations` треба да работи без грешки.

Ако сакаш supseruser за Django admin:
```powershell
docker compose exec backend python manage.py createsuperuser
```

Стопирање: `Ctrl+C`, па `docker compose down` (додај `-v` само ако сакаш да ги избришеш и податоците во базата).

## 2. Docker Hub

1. Направи бесплатна сметка на https://hub.docker.com ако немаш.
2. Оди во **Account Settings → Security → New Access Token**, копирај го токенот (се прикажува само еднаш).
3. Во GitHub repo-то: **Settings → Secrets and variables → Actions → New repository secret**, додади:
   - `DOCKERHUB_USERNAME` = твоето Docker Hub корисничко име
   - `DOCKERHUB_TOKEN` = токенот од чекор 2

## 3. CI (GitHub Actions)

Веќе постои `.github/workflows/docker-publish.yml` — се активира на секој push кон `main`/`master`. Ако работиш на `docker-k8s` гранка и сакаш да го тестираш CI пред merge, привремено додади ја и таа гранка во `on: push: branches:` во тој фајл, или користи "Run workflow" копчето рачно (workflow_dispatch е веќе овозможено).

По push, оди во GitHub repo → **Actions** таб, следи го progress-от. Кога ќе заврши успешно, имиџите се на:
- `docker.io/<твое-корисничко-име>/skinscan-backend:latest`
- `docker.io/<твое-корисничко-име>/skinscan-web:latest`

### AI моделот во CI-имиџот

`skin_model.pt` е намерно исклучен од git (голем бинарен фајл, види `skin_backend/.gitignore`) — значи GitHub Actions (кој прави чист `git clone`) не би го имал. Решено е преку **GitHub Release**: Dockerfile-от прво провери дали фајлот е локално присутен (при `docker compose build` — тогаш е таму, од твојот диск), а само ако НЕ е (случајот во CI), го превзема од Release-от.

Еднократна поставка:

1. Оди во твојот GitHub repo → **Releases** → **Create a new release**.
2. Тег: `model-v1` (или како сакаш), наслов произволен.
3. Влечи го `skin_backend/analyses/services/ai_model/skin_model.pt` во "Attach binaries" делот и објави го releaseот.
4. Кликни on самиот прикачен фајл во releaseот — копирај го директниот линк (завршува на `.../releases/download/model-v1/skin_model.pt`).
5. Во `skin_backend/Dockerfile`, замени ја `ARG MODEL_URL="..."` вредноста со тој линк.

Од тука натаму, и локален build и CI build завршуваат со работен модел — AI скенирањето работи насекаде.

## 4. Kubernetes (Docker Desktop)

### 4.1 Вклучи Kubernetes

Docker Desktop → Settings (ѕупчаник) → **Kubernetes** → штиклирај **Enable Kubernetes** → Apply & Restart. Почекај додека статусот не стане зелен.

### 4.2 Инсталирај ingress controller

Docker Desktop нема вграден Ingress controller — треба да се додаде еднаш:

```powershell
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.3/deploy/static/provider/cloud/deploy.yaml
```

Провери дека тргна:
```powershell
kubectl get pods -n ingress-nginx
```
Почекај додека `ingress-nginx-controller-...` не стане `Running`.

### 4.3 Пополни ги secret-ите

Во `k8s/` папката имаш `.example.yaml` темплејти (безбедни, се комитираат) — направи ги реалните копии (тие се веќе во `.gitignore`, никогаш не се комитираат):

```powershell
copy k8s\02-backend-secret.example.yaml k8s\02-backend-secret.yaml
copy k8s\07-postgres-secret.example.yaml k8s\07-postgres-secret.yaml
```

Отвори ги двата и стави реални вредности — **`DB_PASSWORD`** (во backend-secret) и **`POSTGRES_PASSWORD`** (во postgres-secret) мора да се ИСТИ.

### 4.4 Стави го твоето Docker Hub корисничко име

Во `k8s/04-backend-deployment.yaml` и `k8s/10-web-deployment.yaml`, замени `YOUR_DOCKERHUB_USERNAME` со твоето реално корисничко име (истото од чекор 2).

### 4.5 Примени ги манифестите

```powershell
kubectl apply -f k8s/00-namespace.yaml
kubectl apply -f k8s/
```

(Втората команда ќе се обиде повторно да го примени namespace-от, тоа е безопасно.)

### 4.6 Провери дека работи

```powershell
kubectl get all -n skinscan
```

Сите подови треба да станат `Running` (Postgres прв, потоа backend, потоа web — почекај 1-2 минути). Ако некој pod е `CrashLoopBackOff` или `Pending`, погледни зошто:

```powershell
kubectl describe pod <име-на-pod> -n skinscan
kubectl logs <име-на-pod> -n skinscan
```

Кога сите се `Running`, отвори во browser: **http://localhost/**

Тоа е — Ingress → web Service → backend Service → Postgres StatefulSet, целосно во посебен `skinscan` namespace.

### 4.7 Демонстрација / чистење

За да покажеш дека работи (пред одбрана):
```powershell
kubectl get all -n skinscan
kubectl get ingress -n skinscan
kubectl get configmap,secret -n skinscan
```

За да го тргнеш целосно:
```powershell
kubectl delete namespace skinscan
```

## 5. CD (бонус)

GitHub-овите сервери не можат да стигнат до Kubernetes-от на твојот лаптоп (тој е локален, нема јавна адреса) — затоа CD чекорот мора физички да се изврши НА твојот лаптоп. Тоа се прави со **self-hosted runner**: мал агент што го инсталираш еднаш, се регистрира на твојот GitHub repo, и GitHub му праќа "изврши го овој job" наместо да го извршува сам на своите машини.

### 5.1 Регистрирај self-hosted runner

1. Во GitHub repo → **Settings → Actions → Runners → New self-hosted runner**.
2. Избери **Windows**. GitHub ќе ти прикаже точни команди (со твој уникатен токен) — копирај ги и изврши ги во PowerShell, во произволна папка (пр. `C:\actions-runner`):
   ```powershell
   # (точните команди се на страницата, овие се пример)
   ./config.cmd --url https://github.com/<твое-корисничко-име>/<repo> --token <ТОКЕН>
   ```
3. Кога ќе те праша, остави го default label-от (`self-hosted`) — workflow-от веќе го користи истото.
4. **Не** го инсталирај како Windows service (`svc.cmd install`) — по default тоа работи под SYSTEM корисник, кој НЕМА пристап до твојот `kubectl`/Docker Desktop контекст, па CD ќе паѓа со "connection refused". Наместо тоа, само пушти:
   ```powershell
   ./run.cmd
   ```
   и остави го тој прозорец отворен додека сакаш CD да работи (доволно е за демонстрација/одбрана — не мора да работи постојано).

### 5.2 Додади ги преостанатите GitHub Actions secrets

Веќе имаш `DOCKERHUB_USERNAME`/`DOCKERHUB_TOKEN` (чекор 2). Додади уште три, со ИСТИТЕ вредности што ги стави во `k8s/02-backend-secret.yaml` / `k8s/07-postgres-secret.yaml`:

- `DJANGO_SECRET_KEY`
- `DB_PASSWORD`
- `GEMINI_API_KEY`

### 5.3 Овозможи CD

**Settings → Secrets and variables → Actions → Variables таб → New repository variable**:
- Име: `CD_ENABLED`
- Вредност: `true`

Без ова, deploy job-от секогаш се прескокнува (безбедно да push-аш и без runner да работи во моментот).

### 5.4 Тестирај

Со `./run.cmd` пуштен во еден прозорец, направи мала промена и push:
```powershell
git add .
git commit -m "test CD"
git push
```

Следи го во GitHub → **Actions** таб — по `build-and-push`, треба да тргне и `deploy` job-от. Кога ќе заврши, `kubectl get pods -n skinscan` треба да покаже свежо рестартирани подови (нова возраст/AGE), а промената да е видлива на http://localhost/.

## Преглед на фајловите

| Фајл | Што покрива |
|---|---|
| `skin_backend/Dockerfile`, `entrypoint.sh` | Докеризација на backend |
| `skin_web/Dockerfile`, `nginx.conf` | Докеризација на frontend (+ reverse proxy кон backend) |
| `docker-compose.yml`, `.env.example` | Оркестрација (compose) |
| `.github/workflows/docker-publish.yml` (`build-and-push` job) | CI — build + push на Docker Hub |
| `.github/workflows/docker-publish.yml` (`deploy` job, бонус) | CD — self-hosted runner применува `k8s/` и деплојува на твојот локален кластер |
| `k8s/00-namespace.yaml` | Посебен namespace |
| `k8s/01-04` + `k8s/10` | Deployment + ConfigMap/Secret за апликацијата (backend + web) |
| `k8s/05`, `k8s/11` | Service за апликацијата |
| `k8s/12-ingress.yaml` | Ingress за апликацијата |
| `k8s/06-09` | StatefulSet + ConfigMap/Secret за базата (Postgres) |
