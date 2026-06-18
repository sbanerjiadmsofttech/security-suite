import os
from pathlib import Path
from fastapi import FastAPI, Request
from fastapi.responses import HTMLResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates

# 1. Setup exact directory path structures
CURRENT_DIR = Path(__file__).parent.resolve()
TEMPLATES_DIR = CURRENT_DIR / "templates"
STATIC_DIR = CURRENT_DIR / "static"

# Ensure directories exist right away
TEMPLATES_DIR.mkdir(parents=True, exist_ok=True)
STATIC_DIR.mkdir(parents=True, exist_ok=True)
(STATIC_DIR / "js").mkdir(parents=True, exist_ok=True)

# 2. Initialize a SINGLE global FastAPI app instance
app = FastAPI(
    title="SecSuite Visual Dashboard",
    description="Web user interface layout wrapper for security operations loop.",
    version="0.1.0"
)

# 3. Mount static folder mapping safely
if STATIC_DIR.exists():
    app.mount("/static", StaticFiles(directory=str(STATIC_DIR)), name="static")

templates = Jinja2Templates(directory=str(TEMPLATES_DIR))

# 4. Standard global routes (No hidden nested functions)
@app.get("/", response_class=HTMLResponse)
async def render_index(request: Request):
    # Fallback if index.html is missing
    index_file = TEMPLATES_DIR / "index.html"
    if not index_file.exists():
        return HTMLResponse(content="<h1>Dashboard Active</h1><p>Please create templates/index.html</p>")
        
    template = templates.env.get_template("index.html")
    rendered_content = template.render({"request": request, "status": "Operational"})
    return HTMLResponse(content=rendered_content)

# 5. Simple factory fallback wrapper for your CLI/Docker build
def create_app():
    return app