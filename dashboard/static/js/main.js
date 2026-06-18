async function startScan() {
    const target = document.getElementById('target').value;
    const statusMsg = document.getElementById('status-message');
    const container = document.getElementById('results');
    
    // Clear previous results
    container.innerHTML = '';
    statusMsg.innerText = 'Status: Sending task to Worker...';
    
    // Send to FastAPI -> Celery
    const res = await fetch('/api/v1/scans', {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({target: target, modules: ['osint']})
    });
    const data = await res.json();
    
    statusMsg.innerText = 'Status: Worker is scanning (Pending)...';
    
    // Poll FastAPI -> Celery Backend
    const interval = setInterval(async () => {
        const poll = await fetch(`/api/v1/scans/${data.id}`);
        const statusData = await poll.json();
        
        if (statusData.status === 'completed') {
            clearInterval(interval);
            statusMsg.innerText = 'Status: Scan Complete!';
            renderResults(statusData.results);
        } else if (statusData.status === 'failed') {
            clearInterval(interval);
            statusMsg.innerText = 'Status: Scan Failed!';
        }
    }, 2000);
}

function renderResults(results) {
    const container = document.getElementById('results');
    const colors = { 
        'red': 'border-red-500 text-red-700 bg-red-50', 
        'yellow': 'border-yellow-500 text-yellow-700 bg-yellow-50', 
        'green': 'border-green-500 text-green-700 bg-green-50' 
    };
    
    container.innerHTML = results.map(r => `
        <div class="p-4 mb-3 border-l-4 ${colors[r.severity] || 'border-gray-500'} shadow-sm rounded">
            <strong class="block text-lg">${r.title}</strong> 
            <span class="text-sm">${r.details}</span>
        </div>
    `).join('');
}