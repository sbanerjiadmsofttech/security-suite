FROM python:3.12-slim

WORKDIR /app

# 1. Install system compilation utilities AND the core network-scanning engine
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    gcc \
    nmap \
    && rm -rf /var/lib/apt/lists/*

# 2. Copy the full project workspace structure first
COPY . .

# 3. Upgrade pip and install the platform natively including its optional dependencies
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir ".[all]" ollama

ENV PYTHONPATH=/app
EXPOSE 8080

CMD ["uvicorn", "dashboard.app:app", "--host", "0.0.0.0", "--port", "8080"]