import time
from celery import Celery

# Restore your working Celery configuration
celery_app = Celery(
    "tasks",
    broker="redis://redis:6379/0",
    backend="redis://redis:6379/0"
)

@celery_app.task(name="dashboard.tasks.run_security_task")
def run_security_task(target: str, modules: list):
    # Simulate the delay of a real scan
    time.sleep(5)
    
    # Return structured data formatted for the UI
    findings = [
        {"title": "Open Port 80", "severity": "yellow", "details": f"HTTP detected on {target}"},
        {"title": "SQL Injection", "severity": "red", "details": "Vulnerability found in login form"},
        {"title": "TLS 1.2", "severity": "green", "details": "Secure configuration verified"}
    ]
    
    return findings