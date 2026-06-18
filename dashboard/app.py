import os
from fastapi import FastAPI, Request
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from pydantic import BaseModel

# Import the authentic orchestrated core engine class
from modules.orchestrator.loop import RedBlueOrchestrator

# Determine base paths relative to this file's location
BASE_DIR = os.path.dirname(os.path.abspath(__file__))

class ScanRequest(BaseModel):
    target: str

# 👇 Wrap everything inside a create_app factory function
def create_app() -> FastAPI:
    app = FastAPI(title="SecSuite Operations Control Dashboard")

    # Mount static folders for JS, CSS, and UI assets
    app.mount("/static", StaticFiles(directory=os.path.join(BASE_DIR, "static")), name="static")

    # Initialize Jinja2 HTML templates engine layout
    templates = Jinja2Templates(directory=os.path.join(BASE_DIR, "templates"))

    # --- UI FRONTEND ROUTES ---
    @app.get("/", response_class=HTMLResponse)
    async def render_dashboard_home(request: Request):
        return templates.TemplateResponse("index.html", {"request": request})

    # --- API BACKEND CORE ROUTER ---
    @app.post("/api/scan")
    async def execute_network_scan(payload: ScanRequest):
        target_domain = payload.target.replace("https://", "").replace("http://", "").split("/")[0]
        
        if not target_domain:
            return JSONResponse(status_code=400, content={"detail": "Target address cannot be empty."})
            
        try:
            orchestrator = RedBlueOrchestrator(profile="default")
            report = await orchestrator.run(target=target_domain)
            report_data = report.to_dict() if hasattr(report, "to_dict") else {}
            
            return JSONResponse(content={
                "status": "Completed",
                "target": target_domain,
                "summary": report_data.get("summary", "Analysis finalized successfully."),
                "findings": report_data.get("findings", [])
            })
            
        except Exception as e:
            return JSONResponse(status_code=500, content={"detail": f"Suite execution fault: {str(e)}"})

    return app

# 👇 Create the global instance fallback just in case other modules look for it directly
app = create_app()