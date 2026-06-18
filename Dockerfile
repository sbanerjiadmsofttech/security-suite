FROM python:3.14-slim

# Set system & path parameters
WORKDIR /app
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV PYTHONPATH=/app

# Install native system network audit utilities
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    dnsutils \
    && rm -rf /var/lib/apt/lists/*

# Copy package requirements first to leverage Docker layer caching
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy all repository structures inside the app workspace
COPY . .

# Install the security suite package natively in editable mode 
RUN pip install -e .

# Expose ports for both services
EXPOSE 8000
EXPOSE 8080