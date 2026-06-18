FROM python:3.12-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    gcc \
    nmap \
    && rm -rf /var/lib/apt/lists/*

# Copy everything from your local directory to the /app directory
COPY . .

# Install dependencies including jinja2 and essential web tools
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir . fastapi uvicorn jinja2 aiofiles python-multipart

# Set the path to the root so FastAPI can find the 'dashboard' package
ENV PYTHONPATH=/app

EXPOSE 8080

# Use the python module execution to avoid path issues
CMD ["python", "-m", "uvicorn", "dashboard.app:app", "--host", "0.0.0.0", "--port", "8080"]