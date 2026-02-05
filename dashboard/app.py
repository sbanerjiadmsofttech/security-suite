"""FastAPI Web Dashboard application."""

import asyncio
from datetime import datetime
from pathlib import Path
from typing import Optional
import json

from core.models import Target, ScanResult
from core.logger import get_logger
from core.config import get_settings


class DashboardApp:
    """Web Dashboard application."""

    def __init__(self, host: str = "0.0.0.0", port: int = 8080):
        self.host = host
        self.port = port
        self.logger = get_logger("dashboard")
        self._app = None
        self._scan_results: list[ScanResult] = []
        self._scheduler = None

    def _create_app(self):
        """Create FastAPI application."""
        try:
            from fastapi import FastAPI, HTTPException, Request
            from fastapi.responses import HTMLResponse, JSONResponse
            from fastapi.staticfiles import StaticFiles
        except ImportError:
            raise ImportError("FastAPI not installed. Run: pip install fastapi uvicorn")

        app = FastAPI(
            title="Security Suite Dashboard",
            description="Web interface for security scanning and monitoring",
            version="0.1.0",
        )

        # Store reference to dashboard instance
        app.state.dashboard = self

        # Routes
        @app.get("/", response_class=HTMLResponse)
        async def index():
            return self._render_dashboard()

        @app.get("/api/stats")
        async def get_stats():
            return self._get_stats()

        @app.get("/api/scans")
        async def list_scans():
            return [self._result_to_dict(r) for r in self._scan_results[-50:]]

        @app.get("/api/scans/{scan_id}")
        async def get_scan(scan_id: str):
            for result in self._scan_results:
                if result.module == scan_id:
                    return self._result_to_dict(result)
            raise HTTPException(status_code=404, detail="Scan not found")

        @app.post("/api/scan")
        async def start_scan(request: Request):
            data = await request.json()
            target = data.get("target")
            modules = data.get("modules", ["dns", "headers", "tech"])

            if not target:
                raise HTTPException(status_code=400, detail="Target required")

            # Run scan in background
            asyncio.create_task(self._run_scan(target, modules))

            return {"status": "started", "target": target, "modules": modules}

        @app.get("/api/schedules")
        async def list_schedules():
            if self._scheduler:
                return [s.to_dict() for s in self._scheduler.list_schedules()]
            return []

        @app.post("/api/schedules")
        async def create_schedule(request: Request):
            if not self._scheduler:
                raise HTTPException(status_code=503, detail="Scheduler not initialized")

            data = await request.json()
            from modules.scheduler import ScheduleFrequency

            schedule = self._scheduler.create_schedule(
                name=data.get("name", "New Schedule"),
                target=data["target"],
                modules=data.get("modules", ["dns", "headers"]),
                frequency=ScheduleFrequency(data.get("frequency", "daily")),
            )

            return schedule.to_dict()

        @app.delete("/api/schedules/{schedule_id}")
        async def delete_schedule(schedule_id: str):
            if not self._scheduler:
                raise HTTPException(status_code=503)
            if self._scheduler.delete_schedule(schedule_id):
                return {"status": "deleted"}
            raise HTTPException(status_code=404)

        @app.get("/api/findings")
        async def list_findings():
            findings = []
            for result in self._scan_results:
                for finding in result.findings:
                    findings.append({
                        "title": finding.title,
                        "description": finding.description,
                        "severity": finding.severity.value,
                        "source": finding.source,
                        "target": result.target.value,
                        "timestamp": result.started_at.isoformat() if result.started_at else None,
                    })
            return sorted(findings, key=lambda f: f.get("timestamp") or "", reverse=True)[:100]

        return app

    def _render_dashboard(self) -> str:
        """Render main dashboard HTML."""
        return """<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Security Suite Dashboard</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: #0f0f23;
            color: #cccccc;
            min-height: 100vh;
        }
        .navbar {
            background: #1a1a2e;
            padding: 1rem 2rem;
            display: flex;
            justify-content: space-between;
            align-items: center;
            border-bottom: 1px solid #333;
        }
        .navbar h1 {
            color: #00d4ff;
            font-size: 1.5rem;
        }
        .container {
            max-width: 1400px;
            margin: 0 auto;
            padding: 2rem;
        }
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 1.5rem;
            margin-bottom: 2rem;
        }
        .stat-card {
            background: #1a1a2e;
            border-radius: 10px;
            padding: 1.5rem;
            text-align: center;
            border: 1px solid #333;
        }
        .stat-card .number {
            font-size: 2.5rem;
            font-weight: bold;
            color: #00d4ff;
        }
        .stat-card .label {
            color: #888;
            margin-top: 0.5rem;
        }
        .stat-card.critical .number { color: #ff4444; }
        .stat-card.high .number { color: #ff8844; }
        .stat-card.medium .number { color: #ffcc00; }
        .section {
            background: #1a1a2e;
            border-radius: 10px;
            padding: 1.5rem;
            margin-bottom: 2rem;
            border: 1px solid #333;
        }
        .section h2 {
            color: #00d4ff;
            margin-bottom: 1rem;
            font-size: 1.2rem;
        }
        .scan-form {
            display: flex;
            gap: 1rem;
            margin-bottom: 1rem;
        }
        .scan-form input {
            flex: 1;
            padding: 0.75rem;
            background: #0f0f23;
            border: 1px solid #333;
            border-radius: 5px;
            color: #fff;
            font-size: 1rem;
        }
        .scan-form button {
            padding: 0.75rem 1.5rem;
            background: #00d4ff;
            color: #000;
            border: none;
            border-radius: 5px;
            cursor: pointer;
            font-weight: bold;
        }
        .scan-form button:hover {
            background: #00b8e6;
        }
        table {
            width: 100%;
            border-collapse: collapse;
        }
        th, td {
            padding: 0.75rem;
            text-align: left;
            border-bottom: 1px solid #333;
        }
        th {
            color: #888;
            font-weight: normal;
            text-transform: uppercase;
            font-size: 0.8rem;
        }
        .severity {
            padding: 0.25rem 0.5rem;
            border-radius: 3px;
            font-size: 0.75rem;
            text-transform: uppercase;
        }
        .severity.critical { background: #ff4444; color: #fff; }
        .severity.high { background: #ff8844; color: #fff; }
        .severity.medium { background: #ffcc00; color: #000; }
        .severity.low { background: #00ccff; color: #000; }
        .severity.info { background: #666; color: #fff; }
        .tabs {
            display: flex;
            gap: 1rem;
            margin-bottom: 1rem;
            border-bottom: 1px solid #333;
            padding-bottom: 1rem;
        }
        .tab {
            padding: 0.5rem 1rem;
            background: transparent;
            border: 1px solid #333;
            color: #888;
            cursor: pointer;
            border-radius: 5px;
        }
        .tab.active {
            background: #00d4ff;
            color: #000;
            border-color: #00d4ff;
        }
        .hidden { display: none; }
        #loading {
            position: fixed;
            top: 50%;
            left: 50%;
            transform: translate(-50%, -50%);
            color: #00d4ff;
            font-size: 1.5rem;
        }
        .refresh-btn {
            background: transparent;
            border: 1px solid #00d4ff;
            color: #00d4ff;
            padding: 0.5rem 1rem;
            border-radius: 5px;
            cursor: pointer;
        }
    </style>
</head>
<body>
    <nav class="navbar">
        <h1>🔒 Security Suite Dashboard</h1>
        <button class="refresh-btn" onclick="loadData()">↻ Refresh</button>
    </nav>

    <div class="container">
        <div class="stats-grid" id="stats">
            <div class="stat-card"><div class="number">-</div><div class="label">Total Scans</div></div>
            <div class="stat-card critical"><div class="number">-</div><div class="label">Critical</div></div>
            <div class="stat-card high"><div class="number">-</div><div class="label">High</div></div>
            <div class="stat-card medium"><div class="number">-</div><div class="label">Medium</div></div>
        </div>

        <div class="section">
            <h2>New Scan</h2>
            <form class="scan-form" onsubmit="startScan(event)">
                <input type="text" id="target" placeholder="Enter target (domain, IP, or URL)" required>
                <button type="submit">Start Scan</button>
            </form>
        </div>

        <div class="section">
            <div class="tabs">
                <button class="tab active" onclick="showTab('findings')">Findings</button>
                <button class="tab" onclick="showTab('scans')">Scan History</button>
                <button class="tab" onclick="showTab('schedules')">Schedules</button>
            </div>

            <div id="findings-tab">
                <table>
                    <thead>
                        <tr>
                            <th>Severity</th>
                            <th>Finding</th>
                            <th>Target</th>
                            <th>Source</th>
                        </tr>
                    </thead>
                    <tbody id="findings-table"></tbody>
                </table>
            </div>

            <div id="scans-tab" class="hidden">
                <table>
                    <thead>
                        <tr>
                            <th>Target</th>
                            <th>Module</th>
                            <th>Findings</th>
                            <th>Status</th>
                        </tr>
                    </thead>
                    <tbody id="scans-table"></tbody>
                </table>
            </div>

            <div id="schedules-tab" class="hidden">
                <table>
                    <thead>
                        <tr>
                            <th>Name</th>
                            <th>Target</th>
                            <th>Frequency</th>
                            <th>Next Run</th>
                            <th>Status</th>
                        </tr>
                    </thead>
                    <tbody id="schedules-table"></tbody>
                </table>
            </div>
        </div>
    </div>

    <script>
        async function loadData() {
            try {
                // Load stats
                const statsResp = await fetch('/api/stats');
                const stats = await statsResp.json();
                updateStats(stats);

                // Load findings
                const findingsResp = await fetch('/api/findings');
                const findings = await findingsResp.json();
                updateFindings(findings);

                // Load scans
                const scansResp = await fetch('/api/scans');
                const scans = await scansResp.json();
                updateScans(scans);

                // Load schedules
                const schedulesResp = await fetch('/api/schedules');
                const schedules = await schedulesResp.json();
                updateSchedules(schedules);
            } catch (e) {
                console.error('Failed to load data:', e);
            }
        }

        function updateStats(stats) {
            const grid = document.getElementById('stats');
            grid.innerHTML = `
                <div class="stat-card"><div class="number">${stats.total_scans || 0}</div><div class="label">Total Scans</div></div>
                <div class="stat-card critical"><div class="number">${stats.critical || 0}</div><div class="label">Critical</div></div>
                <div class="stat-card high"><div class="number">${stats.high || 0}</div><div class="label">High</div></div>
                <div class="stat-card medium"><div class="number">${stats.medium || 0}</div><div class="label">Medium</div></div>
            `;
        }

        function updateFindings(findings) {
            const tbody = document.getElementById('findings-table');
            tbody.innerHTML = findings.map(f => `
                <tr>
                    <td><span class="severity ${f.severity}">${f.severity}</span></td>
                    <td>${f.title}</td>
                    <td>${f.target}</td>
                    <td>${f.source}</td>
                </tr>
            `).join('');
        }

        function updateScans(scans) {
            const tbody = document.getElementById('scans-table');
            tbody.innerHTML = scans.map(s => `
                <tr>
                    <td>${s.target}</td>
                    <td>${s.module}</td>
                    <td>${s.findings_count}</td>
                    <td>${s.success ? '✓ Success' : '✗ Failed'}</td>
                </tr>
            `).join('');
        }

        function updateSchedules(schedules) {
            const tbody = document.getElementById('schedules-table');
            tbody.innerHTML = schedules.map(s => `
                <tr>
                    <td>${s.name}</td>
                    <td>${s.target}</td>
                    <td>${s.frequency}</td>
                    <td>${s.next_run || 'N/A'}</td>
                    <td>${s.enabled ? '✓ Enabled' : '✗ Disabled'}</td>
                </tr>
            `).join('');
        }

        function showTab(tab) {
            document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
            document.querySelectorAll('[id$="-tab"]').forEach(t => t.classList.add('hidden'));
            event.target.classList.add('active');
            document.getElementById(tab + '-tab').classList.remove('hidden');
        }

        async function startScan(e) {
            e.preventDefault();
            const target = document.getElementById('target').value;
            try {
                const resp = await fetch('/api/scan', {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json'},
                    body: JSON.stringify({target, modules: ['dns', 'headers', 'tech', 'ssl']})
                });
                if (resp.ok) {
                    alert('Scan started for ' + target);
                    document.getElementById('target').value = '';
                    setTimeout(loadData, 5000);
                }
            } catch (e) {
                alert('Failed to start scan');
            }
        }

        // Load data on page load
        loadData();
        // Auto-refresh every 30 seconds
        setInterval(loadData, 30000);
    </script>
</body>
</html>"""

    def _get_stats(self) -> dict:
        """Get dashboard statistics."""
        severity_counts = {"critical": 0, "high": 0, "medium": 0, "low": 0, "info": 0}

        for result in self._scan_results:
            for finding in result.findings:
                severity = finding.severity.value.lower()
                if severity in severity_counts:
                    severity_counts[severity] += 1

        return {
            "total_scans": len(self._scan_results),
            "total_findings": sum(len(r.findings) for r in self._scan_results),
            **severity_counts,
        }

    def _result_to_dict(self, result: ScanResult) -> dict:
        """Convert scan result to dict."""
        return {
            "target": result.target.value,
            "module": result.module,
            "success": result.success,
            "findings_count": len(result.findings),
            "duration": result.duration_seconds,
            "timestamp": result.started_at.isoformat() if result.started_at else None,
        }

    async def _run_scan(self, target: str, modules: list[str]) -> None:
        """Run a scan (placeholder - integrate with actual scanners)."""
        self.logger.info(f"Starting scan: {target} with {modules}")

        try:
            from modules.osint import (
                DNSEnumerator, HeaderAnalyzer, TechDetector
            )
            from modules.webscanner import SSLAnalyzer

            t = Target.from_string(target)
            scanners = {
                "dns": DNSEnumerator(),
                "headers": HeaderAnalyzer(),
                "tech": TechDetector(),
                "ssl": SSLAnalyzer(),
            }

            for mod in modules:
                if mod in scanners:
                    try:
                        result = await scanners[mod].run(t)
                        self._scan_results.append(result)
                    except Exception as e:
                        self.logger.error(f"Scan error {mod}: {e}")

        except Exception as e:
            self.logger.error(f"Scan failed: {e}")

    def add_scan_result(self, result: ScanResult) -> None:
        """Add a scan result to the dashboard."""
        self._scan_results.append(result)
        # Keep only last 1000 results
        if len(self._scan_results) > 1000:
            self._scan_results = self._scan_results[-1000:]

    def set_scheduler(self, scheduler) -> None:
        """Set the scheduler instance."""
        self._scheduler = scheduler

    async def run(self) -> None:
        """Run the dashboard server."""
        try:
            import uvicorn
        except ImportError:
            raise ImportError("uvicorn not installed. Run: pip install uvicorn")

        self._app = self._create_app()
        self.logger.info(f"Starting dashboard on http://{self.host}:{self.port}")

        config = uvicorn.Config(
            self._app,
            host=self.host,
            port=self.port,
            log_level="info",
        )
        server = uvicorn.Server(config)
        await server.serve()


def create_app(host: str = "0.0.0.0", port: int = 8080) -> DashboardApp:
    """Create dashboard application instance."""
    return DashboardApp(host=host, port=port)
