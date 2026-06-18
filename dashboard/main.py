from fastapi import FastAPI, Request
from fastapi.templating import Jinja2Templates
from fastapi.staticfiles import StaticFiles
from dashboard.tasks import run_security_task
import uuid

app = FastAPI(title="Security Suite Dashboard")
app.mount("/static", StaticFiles(directory="dashboard/static"), name="static")
templates = Jinja2Templates(directory="dashboard/templates")

@app.get("/")
async def root(request: Request):
    return templates.TemplateResponse("index.html", {"request": request})

@app.post("/api/v1/scans")
async def create_scan(request: dict):
    scan_id = str(uuid.uuid4())
    run_security_task.apply_async(
        args=[request['target'], request['modules'], request.get('dry_run', False)],
        task_id=scan_id
    )
    return {"id": scan_id, "status": "pending"}

@app.get("/api/v1/scans/{scan_id}")
async def get_scan_status(scan_id: str):
    task = run_security_task.AsyncResult(scan_id)
    return {"id": scan_id, "status": task.status, "result": task.result}