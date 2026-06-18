FROM python:3.12-slim

WORKDIR /app

# Install necessary Linux compilation dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# 👇 1. Copy the native Python packaging configuration files
COPY pyproject.toml ./

# 👇 2. Install the suite's dependencies and missing modules directly via pip
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir . ollama typer

# 3. Copy the rest of the security suite workspace repository structures
COPY . .

ENV PYTHONPATH=/app
EXPOSE 8080

CMD ["uvicorn", "dashboard.app:app", "--host", "0.0.0.0", "--port", "8080"]