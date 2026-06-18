import uuid
from fastapi import FastAPI, Request, BackgroundTasks
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates
from fastapi.staticfiles import StaticFiles
from dashboard.tasks import execute_security_scan

app = FastAPI(title="Security Suite Pro")
app.mount("/static", StaticFiles(directory="dashboard/static"), name="static")
templates = Jinja2Templates(directory="dashboard/templates")

scan_db = {} # In-production, use Redis or a DB

@app.get("/", response_class=HTMLResponse)
async def root(request: Request):
    return templates.TemplateResponse(request=request, name="index.html")

@app.post("/api/v1/scans")
async def create_scan(request: Request, background_tasks: BackgroundTasks):
    data = await request.json()
    scan_id = str(uuid.uuid4())
    scan_db[scan_id] = {"status": "pending", "results": []}
    
    background_tasks.add_task(execute_security_scan, scan_id, data['target'], data['modules'])
    return {"id": scan_id}

@app.get("/api/v1/scans/{scan_id}")
async def get_status(scan_id: str):
    return scan_db.get(scan_id, {"status": "not_found"})