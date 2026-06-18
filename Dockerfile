# 1. Start with a lean Python runtime
FROM python:3.12-slim

# 2. Set the work directory
WORKDIR /app

# 3. Install system-level tools (nmap is required for your vulnscan modules)
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    gcc \
    nmap \
    && rm -rf /var/lib/apt/lists/*

# 4. Copy your project code into the container
COPY . .

# 5. Upgrade pip and install the package with all necessary runtime dependencies
# This ensures that uvicorn and fastapi are installed in the same Python environment 
# as the main application
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir . fastapi uvicorn

# 6. Set the path so that modules are discoverable
ENV PYTHONPATH=/app

# 7. Expose the dashboard port
EXPOSE 8080

# 8. Start the application using the explicit module path
CMD ["python", "-m", "uvicorn", "dashboard.app:app", "--host", "0.0.0.0", "--port", "8080"]