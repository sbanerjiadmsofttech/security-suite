document.addEventListener("DOMContentLoaded", () => {
    const actionButton = document.getElementById("test-btn");
    const targetInput = document.getElementById("target-url");
    const terminalLog = document.getElementById("terminal-log");
    
    if (actionButton && targetInput && terminalLog) {
        actionButton.addEventListener("click", async () => {
            const selectedTarget = targetInput.value.trim();
            if (!selectedTarget) return alert("Please specify a target domain!");

            // 1. Update terminal display frame state to loading
            actionButton.disabled = true;
            actionButton.innerText = "Scanning...";
            terminalLog.innerHTML = `<span style="color: #38bdf8;">[Pipeline Initiated] Contacting FastAPI scan orchestration pipeline for: ${selectedTarget}...</span>`;

            try {
                // 2. Dispatch real asynchronous background HTTP network request 
                const response = await fetch("/api/scan", {
                    method: "POST",
                    headers: { "Content-Type": "application/json" },
                    body: JSON.stringify({ target: selectedTarget })
                });

                if (!response.ok) throw new Error("Backend engine network pipeline connection drop error.");
                const data = await response.json();

                // 3. Render out the response data loops back onto the dashboard UI
                terminalLog.innerHTML = "";
                data.logs.forEach(logLine => {
                    terminalLog.innerHTML += `<div style="margin-bottom: 5px; color: #a7f3d0;">${logLine}</div>`;
                });
                terminalLog.innerHTML += `<hr style="border-color: #334155; margin: 10px 0;"><div style="color: #34d399; font-weight: bold;">${data.summary}</div>`;

            } catch (error) {
                terminalLog.innerHTML = `<span style="color: #f87171;">[Error] Command string sequence aborted: ${error.message}</span>`;
            } finally {
                actionButton.disabled = false;
                actionButton.innerText = "Execute Scan";
            }
        });
    }
});