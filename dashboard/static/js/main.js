document.addEventListener("DOMContentLoaded", () => {
    const actionButton = document.getElementById("test-btn");
    const targetInput = document.getElementById("target-url");
    const statusIndicator = document.getElementById("status-indicator");
    const resultsWorkspace = document.getElementById("results-workspace");
    const tableBody = document.getElementById("findings-table-body");
    
    if (actionButton && targetInput) {
        actionButton.addEventListener("click", async () => {
            const target = targetInput.value.trim();
            if (!target) return alert("Please input a target domain.");

            // Set loading display states
            actionButton.disabled = true;
            statusIndicator.innerText = "[+] SecSuite Orchestrator initializing scan channels...";
            resultsWorkspace.style.display = "none";
            tableBody.innerHTML = "";

            try {
                const response = await fetch("/api/scan", {
                    method: "POST",
                    headers: { "Content-Type": "application/json" },
                    body: JSON.stringify({ target: target })
                });

                const data = await response.json();
                statusIndicator.innerText = `[✓] ${data.summary}`;

                if (data.findings && data.findings.length > 0) {
                    // Loop over each finding object inside the report array maps
                    data.findings.forEach(finding => {
                        const row = `
                            <tr style="border-bottom: 1px solid #33354a; color: #cbd5e1;">
                                <td style="padding: 10px; font-weight: bold;">${finding.id || 'N/A'}</td>
                                <td style="padding: 10px;">${finding.title || 'Component Flaw Detected'}</td>
                                <td style="padding: 10px; color: #a7f3d0;">${finding.remediation || 'No immediate configuration patch defined.'}</td>
                            </tr>
                        `;
                        tableBody.innerHTML += row;
                    });
                } else {
                    tableBody.innerHTML = `<tr><td colspan="3" style="padding: 15px; text-align: center; color: #94a3b8;">No structural risk points flagged by the scanning engine profiles.</td></tr>`;
                }
                
                resultsWorkspace.style.display = "block";

            } catch (err) {
                statusIndicator.innerText = `[!] System Execution Fault: ${err.message}`;
            } finally {
                actionButton.disabled = false;
            }
        });
    }
});