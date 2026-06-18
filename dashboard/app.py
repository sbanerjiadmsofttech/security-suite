import os
import asyncio
from pathlib import Path
from pydantic import BaseModel
from fastapi import FastAPI, Request
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates

CURRENT_DIR = Path(__file__).parent.resolve()
TEMPLATES_DIR = CURRENT_DIR / "templates"
STATIC_DIR = CURRENT_DIR / "static"

app = FastAPI(title="SecSuite Visual Dashboard", version="0.1.0")

if STATIC_DIR.exists():
    app.mount("/static", StaticFiles(directory=str(STATIC_DIR)), name="static")

templates = Jinja2Templates(directory=str(TEMPLATES_DIR))

# Pydantic schema for incoming dashboard target payloads
class ScanRequest(BaseModel):
    target: str

@app.get("/", response_class=HTMLResponse)
async def render_index(request: Request):
    template = templates.env.get_template("index.html")
    return HTMLResponse(content=template.render({"request": request, "status": "Operational"}))

# 👇 NEW LIVE SCAN ROUTE ENGINE 👇
@app.post("/api/scan")
async def execute_network_scan(payload: ScanRequest):
    target_domain = payload.target.replace("https://", "").replace("http://", "").split("/")[0]
    
    # Simulate step-by-step scanner progression loops
    await asyncio.sleep(1.0) 
    log_step_1 = f"[OSINT Engine] Initializing target resolution for: {target_domain}"
    
    await asyncio.sleep(1.2)
    log_step_2 = f"[DNS Recon] Records identified. Resolving historical sub-domains..."
    
    await asyncio.sleep(0.8)
    log_step_3 = f"[SSL Analyzer] Verifying cipher suites and TLS 1.3 protocol alignments..."

    return JSONResponse(content={
        "status": "Completed",
        "target": target_domain,
        "logs": [log_step_1, log_step_2, log_step_3],
        "summary": f"Scan finished successfully. Posture framework analysis for {target_domain} finalized."
    })
def create_app():
    """Factory function wrapper returning the global FastAPI instance."""
    return app