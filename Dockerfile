FROM python:3.12-slim

WORKDIR /app

# Install system-level dependencies required by your modules
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    gcc \
    nmap \
    && rm -rf /var/lib/apt/lists/*

# Copy your full local code structure
COPY . .

# Install the Python package and its requirements
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir .

ENV PYTHONPATH=/app
EXPOSE 8080

CMD ["uvicorn", "dashboard.app:app", "--host", "0.0.0.0", "--port", "8080"]