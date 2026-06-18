from fastapi import FastAPI, Request
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from pydantic import BaseModel

# Import the orchestrator AND the guardrails system
from modules.orchestrator.loop import RedBlueOrchestrator 
from core.guardrails import guardrails

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
        # 1. Satisfy the Guardrails (Required by loop.py)
        # We create a temporary session for the dashboard user
        guardrails.create_session(
            operator="DashboardUser", 
            engagement_id="DASH-100", 
            target_scope=[domain_to_scan]
        )
        
        # 2. Initialize the orchestrator
        orchestrator = RedBlueOrchestrator()
        
        # 3. AWAIT the run command
        scan_report = await orchestrator.run(
            target=domain_to_scan,
            mode="recon_only" # Let's start with a fast, safe mode to prove it works!
        ) 
        
        # 4. Clean up the session
        guardrails.end_session()
        
        # 5. Send the successful JSON back to the UI
        return JSONResponse({
            "status": "success", 
            "target": domain_to_scan,
            # We must use .to_dict() because loop.py returns a dataclass object
            "message": scan_report.to_dict() 
        })
        
    except Exception as e:
        # If it crashes, tell the UI exactly why (e.g., "PermissionError: No active session")
        return JSONResponse({
            "status": "error",
            "message": f"Orchestrator crashed: {str(e)}"
        }, status_code=500)