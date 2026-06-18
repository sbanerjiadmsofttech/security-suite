import uuid
from fastapi import FastAPI, Request
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates
from fastapi.staticfiles import StaticFiles
from dashboard.tasks import run_security_task, celery_app
from celery.result import AsyncResult

app = FastAPI(title="Security Suite Pro")
app.mount("/static", StaticFiles(directory="dashboard/static"), name="static")
templates = Jinja2Templates(directory="dashboard/templates")

@app.get("/", response_class=HTMLResponse)
async def root(request: Request):
    # Pass 'request' first as required by modern FastAPI
    return templates.TemplateResponse(request, "index.html")

@app.post("/api/v1/scans")
async def create_scan(request: Request):
    data = await request.json()
    target = data.get('target')
    modules = data.get('modules', ['osint'])
    
    # Trigger the Celery worker exactly like the working version
    task = run_security_task.delay(target, modules)
    return {"id": task.id}

@app.get("/api/v1/scans/{task_id}")
async def get_status(task_id: str):
    # Ask Celery for the real-time status of the job
    task_result = AsyncResult(task_id, app=celery_app)
    
    if task_result.state == 'SUCCESS':
        return {"status": "completed", "results": task_result.result}
    elif task_result.state == 'FAILURE':
        return {"status": "failed", "results": []}
    
    return {"status": "pending"}