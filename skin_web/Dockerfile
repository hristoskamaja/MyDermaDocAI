# syntax=docker/dockerfile:1

# ---- build stage: compile the React app into static files ----
FROM node:20-alpine AS build
WORKDIR /app

# package*.json copied first so `npm ci` only re-runs (slow) when
# dependencies actually change, not on every source edit.
COPY package.json package-lock.json* ./
RUN npm ci

COPY . .

# Relative path, not an absolute host:port - nginx below proxies /api/ to
# the backend, so the browser calls same-origin /api/... regardless of
# what host actually serves the page. That's what lets this exact same
# built image work unchanged in docker-compose AND behind a Kubernetes
# Ingress (different hostnames, zero rebuild) - CRA bakes REACT_APP_*
# vars into the JS bundle at build time, so this has to be set here, not
# read from the environment at container start.
ENV REACT_APP_API_URL=/api
RUN npm run build

# ---- serve stage: a plain static file + reverse-proxy server ----
FROM nginx:1.27-alpine
COPY --from=build /app/build /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
