from fastapi import FastAPI, Request
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates

app = FastAPI(title="Security Suite Dashboard")

# 1. Mount static files correctly
app.mount("/static", StaticFiles(directory="dashboard/static"), name="static")

# 2. Setup templates
templates = Jinja2Templates(directory="dashboard/templates")

# --- UI Routes ---
@app.get("/", response_class=HTMLResponse)
async def root(request: Request):
    # FIXED: In the newest Starlette version, 'request' must be passed directly as the first argument
    return templates.TemplateResponse(request, "index.html")

# --- API Routes ---
@app.post("/api/scan")
async def run_scan():
    # This is where your RedBlueOrchestrator logic will eventually hook in
    # For now, it returns a safe JSON response to prove the frontend is connected
    return JSONResponse({
        "status": "success", 
        "message": "Scan completed successfully! No critical vulnerabilities found in the current loop."
    })