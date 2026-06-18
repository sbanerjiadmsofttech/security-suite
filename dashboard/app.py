"""FastAPI Web UI Dashboard for Security Suite."""

import os
from pathlib import Path
from fastapi import FastAPI, Request
from fastapi.responses import HTMLResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
app = FastAPI()

# Get the absolute path to the directory this file is in
BASE_DIR = os.path.dirname(os.path.abspath(__file__))

# Mount the static directory cleanly using the absolute path
app.mount(
    "/static", 
    StaticFiles(directory=os.path.join(BASE_DIR, "static")), 
    name="static"
)
class DashboardApp:
    """Manages the lifecycle and routing for the visual Security Workspace."""
    
    def __init__(self, host: str = "0.0.0.0", port: int = 8080):
        self.host = host
        self.port = port
        
        # Locate directories relative to this file
        current_dir = Path(__file__).parent.resolve()
        self.templates_dir = current_dir / "templates"
        self.static_dir = current_dir / "static"
        
        # Ensure directories exist
        self.templates_dir.mkdir(parents=True, exist_ok=True)
        self.static_dir.mkdir(parents=True, exist_ok=True)
        (self.static_dir / "js").mkdir(parents=True, exist_ok=True)

        self.app = FastAPI(
            title="SecSuite Visual Dashboard",
            description="Web user interface layout wrapper for security operations loop.",
            version="0.1.0"
        )
        
        self._setup_middleware_and_static()
        self._setup_routes()

    def _setup_middleware_and_static(self):
        """Mount local static assets layout folder."""
        if self.static_dir.exists():
            self.app.mount("/static", StaticFiles(directory=str(self.static_dir)), name="static")
        
        self.templates = Jinja2Templates(directory=str(self.templates_dir))

    def _setup_routes(self):
        """Map visual paths to rendered Jinja2 templates."""
        
        @self.app.get("/", response_class=HTMLResponse)
        async def render_index(request: Request):
            # Manually load and render the template to bypass the Starlette 3.14 cache bug
            template = self.templates.env.get_template("index.html")
            rendered_content = template.render({"request": request, "status": "Operational"})
            return HTMLResponse(content=rendered_content)

    async def run(self):
        """Launch uvicorn programmatically in sync loop context."""
        import uvicorn
        config = uvicorn.Config(
            self.app, 
            host=self.host, 
            port=self.port, 
            log_level="info"
        )
        server = uvicorn.Server(config)
        await server.serve()
        # Add this at the very bottom of dashboard/app.py

def create_app():
    """Factory function for the CLI / Uvicorn server entry point."""
    dashboard_instance = DashboardApp()
    return dashboard_instance.app