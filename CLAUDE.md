# DermaScanAI / MyDermaDocAI
Monorepo: skin_backend (Django REST, PostgreSQL/SQLite, apps: accounts, core, analyses, analytics, jwt_auth),
skin_web (React CRA: patient pages + indigo/teal admin panel), skin_mobile (Flutter), k8s/, .github/.

## Run locally (no Docker/K8s)
- Backend: cd skin_backend; .venv\Scripts\activate; python manage.py migrate; python manage.py runserver
- Web: cd skin_web; npm start        - Mobile: cd skin_mobile; flutter run
- Checks: python manage.py test | npm run build | flutter analyze

## Rules
- All code comments in English. All user-facing strings need EN + MK (web: LanguageContext, mobile: l10n/app_strings.dart).
- Bilingual DB text uses paired fields (x and x_en); API takes ?lang=.
- NEVER commit, push, or create branches. I commit myself. Never add Co-Authored-By.
- Never read/print .env or secrets. Do not touch Dockerfile*, docker-compose.yml, k8s/, .github/.
- Do not change the admin panel look (indigo/teal) unless asked.
- Mock Gemini in tests; never call the real API from tests.
- No new heavy dependencies without asking first. Follow existing patterns.
- Work in small steps: show a short plan first, wait for approval, then implement and run the checks above.

## Design references
- design-reference/ holds WEB design screenshots only (flat folder, see design-reference/README.txt). It is git-ignored.
- There are no mobile screenshots: derive the Flutter screens from the web designs, using native mobile patterns
  (bottom tab bar, bottom sheets, safe areas) and the same design tokens.
