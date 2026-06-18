async function startScan() {
    const target = document.getElementById('target').value;
    const res = await fetch('/api/v1/scans', {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({target: target, modules: ['osint']})
    });
    const data = await res.json();
    
    // UI Feedback
    const container = document.getElementById('results');
    container.innerHTML = '<p class="text-blue-500">Scan in progress...</p>';
    
    const interval = setInterval(async () => {
        const poll = await fetch(`/api/v1/scans/${data.id}`);
        const status = await poll.json();
        if (status.status === 'completed') {
            clearInterval(interval);
            renderResults(status.results);
        }
    }, 2000);
}

function renderResults(results) {
    const container = document.getElementById('results');
    // Map severity to Tailwind border classes
    const colors = { 
        'red': 'border-red-500', 
        'yellow': 'border-yellow-500', 
        'green': 'border-green-500' 
    };
    
    container.innerHTML = results.map(r => `
        <div class="p-3 mb-2 border-l-4 ${colors[r.severity] || 'border-gray-500'} bg-white shadow-sm rounded">
            <span class="font-bold text-gray-800">${r.title}</span> 
            <p class="text-sm text-gray-600">${r.details}</p>
        </div>
    `).join('');
}