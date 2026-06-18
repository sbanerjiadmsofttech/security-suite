from fastapi import FastAPI, Request
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from pydantic import BaseModel # <--- ADD THIS IMPORT

app = FastAPI(title="Security Suite Dashboard")

app.mount("/static", StaticFiles(directory="dashboard/static"), name="static")
templates = Jinja2Templates(directory="dashboard/templates")

# Define what the incoming data looks like
class ScanRequest(BaseModel):
    target: str

@app.get("/", response_class=HTMLResponse)
async def root(request: Request):
    return templates.TemplateResponse(request, "index.html")

# Update the route to accept the payload
@app.post("/api/scan")
async def run_scan(payload: ScanRequest):
    # Now you have the domain!
    domain_to_scan = payload.target 
    
    # --- YOUR ORCHESTRATOR LOGIC GOES HERE ---
    # result = my_orchestrator.run(domain_to_scan)
    
    return JSONResponse({
        "status": "success", 
        "target": domain_to_scan,
        "message": f"Simulated orchestrator output for {domain_to_scan}.\nNo critical vulnerabilities detected in this loop."
    })