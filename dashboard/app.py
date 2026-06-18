from fastapi import FastAPI, Request
from fastapi.responses import HTMLResponse, JSONResponse
from pydantic import BaseModel
# 👇 Import the actual suite core report objects and orchestration loop
from modules.orchestrator.loop import OrchestratorLoop

app = FastAPI()

class ScanRequest(BaseModel):
    target: str

@app.post("/api/scan")
async def execute_network_scan(payload: ScanRequest):
    # Clean the input target domain string
    target_domain = payload.target.replace("https://", "").replace("http://", "").split("/")[0]
    
    try:
        # Initialize your suite's native orchestrator loop instance
        # (Pass 'default' or your preferred configuration profile)
        orchestrator = OrchestratorLoop(profile="default")
        
        # Run the internal execution engine loops asynchronously
        report = await orchestrator.run(target=target_domain)
        
        # Convert your native suite objects (LoopReport) directly to a readable dictionary map
        return JSONResponse(content={
            "status": "Completed",
            "target": target_domain,
            "summary": report.to_dict().get("summary", "Analysis finalized successfully."),
            "findings": report.to_dict().get("findings", [])  # Holds the real findings array
        })
        
    except Exception as e:
        return JSONResponse(status_code=500, content={"detail": f"Suite execution fault: {str(e)}"})