FROM python:3.12-slim

# Set the working directory inside the container
WORKDIR /app

# 1. Install system compilation utilities AND the core network-scanning engine
# - build-essential & gcc: Needed for compiling python-whois/lxml/cryptography extensions
# - nmap: Absolutely required by the 'python-nmap' module in your dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    gcc \
    nmap \
    && rm -rf /var/lib/apt/lists/*

# 2. Copy the entire repository layout into the container space first
# This allows hatchling to see the 'core', 'modules', 'cli', and 'dashboard' folders
COPY . .

# 3. Upgrade pip and install the platform natively including all its optional features
# - ".[all]" installs core dependencies plus the optional AI and dashboard engines
# - jinja2, ollama, and typer are added explicitly to ensure smooth operation
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir ".[all]" jinja2 ollama typer

# Set up the environment paths so Python looks for modules in the root directory
ENV PYTHONPATH=/app

# Expose the default FastAPI port
EXPOSE 8080

# Spin up the Uvicorn ASGI server pointing to your dashboard application
CMD ["uvicorn", "dashboard.app:app", "--host", "0.0.0.0", "--port", "8080"]