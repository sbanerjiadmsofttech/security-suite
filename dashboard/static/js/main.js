document.addEventListener('DOMContentLoaded', () => {
    const scanBtn = document.getElementById('scan-btn');
    const targetInput = document.getElementById('target-domain');
    const workspace = document.getElementById('results-workspace');

    if (scanBtn) {
        scanBtn.addEventListener('click', async () => {
            const target = targetInput.value.trim();
            
            // 1. Validation check
            if (!target) {
                workspace.innerHTML = `<span style='color: #f44336;'>[ERROR]</span> Please enter a valid domain or IP address.`;
                return;
            }

            // 2. Lock UI and show progress
            scanBtn.disabled = true;
            targetInput.disabled = true;
            scanBtn.innerText = "Scanning...";
            workspace.innerHTML = `<span style='color: #ff9800;'>[SYSTEM] Booting AI Engine...<br>[TARGET] Analyzing ${target}...</span>`;

            try {
                // 3. Send the target to the backend
                const response = await fetch('/api/scan', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ target: target }) // Sending the domain here!
                });

                const data = await response.json();

                // 4. Render the output
                if (response.ok) {
                    workspace.innerHTML = `<span style='color: #4caf50;'>[SUCCESS]</span> Scan completed for <strong>${data.target}</strong>.<br><br>[OUTPUT]<br>${data.message}`;
                } else {
                    // Handle validation errors from FastAPI (like missing fields)
                    workspace.innerHTML = `<span style='color: #f44336;'>[ERROR]</span> Server returned status ${response.status}: ${JSON.stringify(data.detail)}`;
                }
            } catch (error) {
                console.error("Fetch error:", error);
                workspace.innerHTML = `<span style='color: #f44336;'>[NETWORK ERROR]</span> Could not connect to backend engine.`;
            } finally {
                // 5. Unlock UI
                scanBtn.disabled = false;
                targetInput.disabled = false;
                scanBtn.innerText = "Initialize Scan";
            }
        });
    }
});