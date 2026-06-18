import os
from fastapi import FastAPI, Request
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from modules.orchestrator.loop import RedBlueOrchestrator

# Initialize the FastAPI app instance
app = FastAPI(title="SecSuite Operations Control Dashboard")

# Determine paths
BASE_DIR = os.path.dirname(os.path.abspath(__file__))

# Mount static files and templates
app.mount("/static", StaticFiles(directory=os.path.join(BASE_DIR, "static")), name="static")
templates = Jinja2Templates(directory=os.path.join(BASE_DIR, "templates"))

@app.get("/")
async def root(request: Request):
    return templates.TemplateResponse("index.html", {"request": request})

@app.post("/api/scan")
async def execute_scan(target: str):
    # This route uses your RedBlueOrchestrator as defined in your modules
    orchestrator = RedBlueOrchestrator(profile="default")
    report = await orchestrator.run(target=target)
    return {"status": "success", "data": report}