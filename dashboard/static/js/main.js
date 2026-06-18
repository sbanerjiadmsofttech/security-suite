document.addEventListener('DOMContentLoaded', () => {
    const scanBtn = document.getElementById('scan-btn');
    const workspace = document.getElementById('results-workspace');

    if (scanBtn) {
        scanBtn.addEventListener('click', async () => {
            // 1. Lock the button and update UI
            scanBtn.disabled = true;
            scanBtn.innerText = "Executing Scan Loop...";
            workspace.innerHTML = "<span style='color: #ff9800;'>[SYSTEM] Booting AI Engine and scanning targets...</span>";

            try {
                // 2. Call the FastAPI endpoint
                const response = await fetch('/api/scan', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' }
                });

                const data = await response.json();

                // 3. Render the result
                if (response.ok) {
                    workspace.innerHTML = `<span style='color: #4caf50;'>[SUCCESS]</span> ${data.message}`;
                } else {
                    workspace.innerHTML = `<span style='color: #f44336;'>[ERROR]</span> Server returned status ${response.status}`;
                }
            } catch (error) {
                console.error("Fetch error:", error);
                workspace.innerHTML = `<span style='color: #f44336;'>[NETWORK ERROR]</span> Could not connect to backend engine.`;
            } finally {
                // 4. Unlock the button
                scanBtn.disabled = false;
                scanBtn.innerText = "Initialize Security Scan";
            }
        });
    } else {
        console.error("Critical Error: scan-btn not found in the DOM.");
    }
});