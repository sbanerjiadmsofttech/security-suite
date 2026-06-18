FROM python:3.12-slim

WORKDIR /app

# 👇 1. Install necessary Linux system build dependencies cleanly
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# 2. Copy package requirements first
COPY requirements.txt .

# 3. Upgrade pip and install requirements
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# 4. Copy all repository structures inside the app workspace
COPY . .

ENV PYTHONPATH=/app
EXPOSE 8080

CMD ["uvicorn", "dashboard.app:app", "--host", "0.0.0.0", "--port", "8080"]