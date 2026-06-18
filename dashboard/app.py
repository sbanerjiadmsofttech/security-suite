from fastapi import FastAPI, Request
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from pydantic import BaseModel

# --- IMPORT YOUR ACTUAL ENGINE ---
from modules.orchestrator.loop import RedBlueOrchestrator 

app = FastAPI(title="Security Suite Dashboard")

app.mount("/static", StaticFiles(directory="dashboard/static"), name="static")
templates = Jinja2Templates(directory="dashboard/templates")

class ScanRequest(BaseModel):
    target: str

@app.get("/", response_class=HTMLResponse)
async def root(request: Request):
    return templates.TemplateResponse(request, "index.html")

@app.post("/api/scan")
async def run_scan(payload: ScanRequest):
    domain_to_scan = payload.target
    
    try:
        # --- THE REAL SCAN INITIATION ---
        # 1. Initialize your orchestrator
        orchestrator = RedBlueOrchestrator()
        
        # 2. Run the actual scan loop (this will take time!)
        # Assuming your run() method returns a report or string
        scan_report = orchestrator.run(domain_to_scan) 
        
        return JSONResponse({
            "status": "success", 
            "target": domain_to_scan,
            "message": str(scan_report) # Send the real AI output to the screen
        })
        
    except Exception as e:
        # If the AI or scan fails, tell the user gracefully
        return JSONResponse({
            "status": "error",
            "message": f"Orchestrator Error: {str(e)}"
        }, status_code=500)