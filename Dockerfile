# IMPORTANT NOTE:
#
#   Django Sites with Django SASS require a PostgreSQL database to build the image
#       Simply run the following steps to build images :
#           - docker compose up db -d
#           - docker buildx build --network=host --target=frontend -t recocos:frontend .
#           - docker buildx build --network=host --target=backend -t recocos:backend .
# 
# ------------------------------------------------------------------------------
# Stage 1: Builder
# Installs Python & Node dependencies, builds frontend, and collects static files.
# ------------------------------------------------------------------------------
FROM python:3.13-slim AS builder

# Install system dependencies
# - build-essential, libproj-dev, gdal-bin, git: for python dependencies (geo, git based)
# - curl, gnupg, ca-certificates: for installing nodejs
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential \
    libproj-dev \
    gdal-bin \
    git \
    curl \
    gnupg \
    ca-certificates \
    libpq-dev \
    libmagic1t64 && \
    rm -rf /var/lib/apt/lists/*

COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

RUN mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list && \
    apt-get update && \
    apt-get install -y nodejs && \
    npm install -g yarn

WORKDIR /app

COPY pyproject.toml uv.lock ./
ENV UV_COMPILE_BYTECODE=1
ENV UV_LINK_MODE=copy
RUN uv sync --locked --no-dev

COPY . .

WORKDIR /app/recoco/frontend
RUN yarn install && yarn build

WORKDIR /app
RUN cp recoco/settings/production.py.docker_example recoco/settings/production.py

ENV PATH="/app/.venv/bin:$PATH"
ENV DJANGO_SETTINGS_MODULE=recoco.settings.production

# SAFETY: Only required to build the static files. Required by Django.
ENV SECRET_KEY=secret_key_for_build
ENV DJANGO_DB_NAME=postgres
ENV DJANGO_DB_USER=postgres
ENV DJANGO_DB_PASSWORD=postgres
RUN python manage.py migrate
RUN python manage.py compilescss
RUN python manage.py collectstatic

# ------------------------------------------------------------------------------
# Stage 2: Frontend
# Uses Nginx to serve the static files built in the previous stage.
# ------------------------------------------------------------------------------
FROM nginx:alpine AS frontend

COPY --from=builder --chown=www-data /app/static /usr/share/nginx/html/static

# ------------------------------------------------------------------------------
# Stage 3: Backend
# Serves the Python program using the environment prepared in builder.
# ------------------------------------------------------------------------------
FROM python:3.13-slim AS backend

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    libproj-dev \
    gdal-bin \
    libpq-dev \
    libmagic1t64 && \
    rm -rf /var/lib/apt/lists/*

COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

WORKDIR /app

COPY --from=builder /app/.venv /app/.venv
COPY --from=builder /app/recoco/frontend/dist/.vite/manifest.json /app/static/

COPY . .

RUN cp recoco/settings/production.py.docker_example recoco/settings/production.py

ENV PATH="/app/.venv/bin:$PATH"
ENV PYTHONUNBUFFERED=1
ENV DJANGO_SETTINGS_MODULE=recoco.settings.production

EXPOSE 8000

CMD ["uv", "run", "python", "manage.py", "runserver", "0.0.0.0:8000"]
