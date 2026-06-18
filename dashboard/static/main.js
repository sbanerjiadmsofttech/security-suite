/**
 * Dispatch execution details to Security Suite API Core
 */
async function dispatchScan() {
    const targetValue = document.getElementById('targetInput').value.trim();
    if (!targetValue) {
        alert('Please specify a valid targets destination.');
        return;
    }

    // Collect checked tool modules
    const selectedModules = [];
    document.querySelectorAll('input[name="modules"]:checked').forEach((checkbox) => {
        selectedModules.push(checkbox.value);
    });

    const pipelineContainer = document.getElementById('scanPipeline');
    pipelineContainer.innerHTML = `
        <div class="bg-zinc-900 border border-zinc-800 p-4 rounded-xl flex items-center justify-between">
            <div class="flex items-center space-x-3">
                <i class="fa-solid fa-circle-notch fa-spin text-cyan-500"></i>
                <div>
                    <span class="block font-medium text-sm text-slate-200">${targetValue}</span>
                    <span class="block text-xs text-zinc-500">Processing ${selectedModules.join(', ')} payload matrices...</span>
                </div>
            </div>
            <span class="text-xs font-semibold px-2.5 py-1 rounded bg-cyan-950 text-cyan-400 animate-pulse">RUNNING</span>
        </div>
    `;

    try {
        // Dispatch directly to your scans API layer
        const response = await fetch('/api/v1/scans/', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                target: targetValue,
                modules: selectedModules,
                options: {}
            })
        });

        const data = await response.json();
        if (response.ok) {
            alert(`Scan pipeline registered successfully! ID: ${data.id}`);
            // Start monitoring findings loops here...
        } else {
            throw new Error(data.detail || 'Failed pipeline injection');
        }
    } catch (err) {
        pipelineContainer.innerHTML = `
            <div class="bg-red-950/30 border border-red-900/50 p-4 rounded-xl text-red-400 text-sm">
                <i class="fa-solid fa-triangle-exclamation mr-2"></i><strong>Engine Exception:</strong> ${err.message}
            </div>
        `;
    }
}