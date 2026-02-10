FROM python:3-slim

ENV PYTHONUNBUFFERED=1

# Required dependencies
#   python3-dev required by psycopg-c to build (need python headers)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    python3-dev \
    build-essential \
    libproj-dev \
    gdal-bin \
    git \
    libpq-dev

COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

WORKDIR /piptmp

ENV PATH="/piptmp/.venv/bin:$PATH"

COPY pyproject.toml uv.lock ./

RUN uv sync --locked

WORKDIR /workspace

COPY . .

CMD ["python", "manage.py", "runserver", "0.0.0.0:8000"]
