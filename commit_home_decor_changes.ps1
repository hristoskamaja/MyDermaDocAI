# Commits the un-committed Home page / hero wave decor / footer work that
# was sitting in the working directory before the docker-k8s branch was
# created (confirmed via `git log --oneline master` - none of this exists
# in any commit yet, on any branch). Run this BEFORE committing the
# Docker/K8s files, so the two unrelated pieces of work stay in separate,
# readable commits on the docker-k8s branch history.
#
# Run from the repo root:
#   .\commit_home_decor_changes.ps1

$ErrorActionPreference = "Stop"

# 1) Web: new Home page + hero wave decor component + patient footer
git add `
  skin_web/src/pages/Home/Home.jsx `
  skin_web/src/pages/Home/Home.css `
  skin_web/src/components/decor/PageHeroWave.jsx `
  skin_web/src/components/layout/PatientFooter.jsx `
  skin_web/src/components/layout/PatientFooter.css `
  skin_web/src/components/layout/PatientLayout.jsx `
  skin_web/src/components/layout/PatientLayout.css `
  skin_web/src/App.js `
  skin_web/src/index.css `
  skin_web/package-lock.json
git commit -m "Web: add patient Home page with hero wave decor and footer"

# 2) Web: apply the hero wave header to the other patient-facing pages
git add `
  skin_web/src/pages/History/History.jsx `
  skin_web/src/pages/History/History.css `
  skin_web/src/pages/Login/Login.jsx `
  skin_web/src/pages/Profile/Profile.jsx `
  skin_web/src/pages/Profile/Profile.css `
  skin_web/src/pages/Register/Register.jsx `
  skin_web/src/pages/Scan/Scan.jsx `
  skin_web/src/pages/Scan/Scan.css `
  skin_web/src/pages/Scan/ScanResult.css
git commit -m "Web: apply hero wave header styling across patient pages"

# 3) Mobile: matching hero wave / page header widgets
git add `
  skin_mobile/lib/widgets/hero_wave.dart `
  skin_mobile/lib/widgets/page_hero_header.dart `
  skin_mobile/lib/theme/app_theme.dart `
  skin_mobile/macos/Flutter/GeneratedPluginRegistrant.swift `
  skin_mobile/windows/flutter/generated_plugin_registrant.cc `
  skin_mobile/windows/flutter/generated_plugins.cmake
git commit -m "Mobile: add hero wave and page header widgets to match web"

# 4) Unrelated stray notebook change, kept separate on purpose
git add skin_disease_training.ipynb
git commit -m "Update training notebook"

Write-Host ""
Write-Host "Done. git log --oneline -6 to check:"
git log --oneline -6
