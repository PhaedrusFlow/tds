<!DOCTYPE html>
<html lang="en">

	<head>
		<meta charset="utf-8">
		<meta name="viewport" content="width=device-width, initial-scale=1">
		<title>TDS Tech Training Tips Portal</title>
		<style>
			:root {
				--bg: #020817;
				--bg-2: #061126;
				--surface: rgba(7, 20, 42, 0.88);
				--surface-2: rgba(10, 29, 61, 0.82);
				--line: rgba(74, 194, 255, 0.22);
				--text: #dff8ff;
				--muted: #8eb8d4;
				--cyan: #2fe8ff;
				--blue: #218bff;
				--blue-2: #5cc8ff;
				--glow: 0 0 24px rgba(47, 232, 255, 0.25), 0 0 80px rgba(33, 139, 255, 0.14);
				--radius: 20px;
			}
			
			* {
				box-sizing: border-box;
			}
			
			body {
				margin: 0;
				font-family: Inter, Segoe UI, Roboto, Arial, sans-serif;
				color: var(--text);
				background:
				radial-gradient(circle at top left, rgba(47, 232, 255, 0.13), transparent 24%),
				radial-gradient(circle at 80% 20%, rgba(33, 139, 255, 0.18), transparent 22%),
				linear-gradient(180deg, #01040d 0%, #020817 45%, #041126 100%);
				min-height: 100vh;
			}
			
			body::before {
				content: "";
				position: fixed;
				inset: 0;
				pointer-events: none;
				background:
				linear-gradient(rgba(255, 255, 255, 0.02), rgba(255, 255, 255, 0.01)),
				repeating-linear-gradient(90deg, rgba(47, 232, 255, 0.03) 0 1px, transparent 1px 120px),
				repeating-linear-gradient(0deg, rgba(33, 139, 255, 0.025) 0 1px, transparent 1px 120px);
				mix-blend-mode: screen;
			}
			
			.wrap {
				max-width: 1380px;
				margin: 0 auto;
				padding: 28px;
			}
			
			.topbar {
				display: flex;
				justify-content: space-between;
				align-items: center;
				gap: 16px;
				margin-bottom: 24px;
				padding: 16px 20px;
				border: 1px solid var(--line);
				border-radius: 18px;
				background: linear-gradient(180deg, rgba(5, 15, 32, 0.94), rgba(5, 17, 38, 0.78));
				box-shadow: var(--glow);
				backdrop-filter: blur(14px);
			}
			
			.brand {
				display: flex;
				align-items: center;
				gap: 14px;
			}
			
			.logo {
				width: 46px;
				height: 46px;
				border-radius: 14px;
				display: grid;
				place-items: center;
				background: radial-gradient(circle at 25% 20%, var(--cyan), transparent 35%), linear-gradient(135deg, rgba(47, 232, 255, 0.16), rgba(33, 139, 255, 0.18));
				border: 1px solid rgba(47, 232, 255, 0.26);
				box-shadow: var(--glow);
				font-weight: 800;
				color: white;
			}
			
			.title {
				font-size: 1.2rem;
				font-weight: 700;
				letter-spacing: 0.02em;
			}
			
			.subtitle {
				color: var(--muted);
				font-size: 0.92rem;
				margin-top: 2px;
			}
			
			.pillbar {
				display: flex;
				flex-wrap: wrap;
				gap: 10px;
			}
			
			.pill {
				padding: 10px 14px;
				border-radius: 999px;
				border: 1px solid var(--line);
				color: var(--text);
				text-decoration: none;
				background: rgba(8, 22, 48, 0.78);
				font-size: 0.92rem;
			}
			
			.hero {
				display: grid;
				grid-template-columns: 1.6fr 1fr;
				gap: 24px;
				margin-bottom: 24px;
			}
			
			.panel {
				position: relative;
				overflow: hidden;
				border-radius: var(--radius);
				border: 1px solid var(--line);
				background: linear-gradient(180deg, var(--surface), var(--surface-2));
				backdrop-filter: blur(12px);
				box-shadow: var(--glow);
			}
			
			.panel::after {
				content: "";
				position: absolute;
				inset: 0;
				background: linear-gradient(135deg, rgba(47, 232, 255, 0.06), transparent 30%, transparent 70%, rgba(33, 139, 255, 0.08));
				pointer-events: none;
			}
			
			.hero-main {
				padding: 32px;
				min-height: 320px;
				display: flex;
				flex-direction: column;
				justify-content: space-between;
			}
			
			h1 {
				margin: 0 0 14px;
				font-size: clamp(2rem, 4vw, 4rem);
				line-height: 1.02;
				letter-spacing: -0.03em;
			}
			
			p.lead {
				max-width: 62ch;
				margin: 0;
				color: var(--muted);
				font-size: 1rem;
				line-height: 1.7;
			}
			
			.cta-row {
				display: flex;
				flex-wrap: wrap;
				gap: 12px;
				margin-top: 22px;
			}
			
			.btn {
				display: inline-flex;
				align-items: center;
				gap: 10px;
				border-radius: 14px;
				padding: 12px 16px;
				text-decoration: none;
				font-weight: 600;
				border: 1px solid var(--line);
			}
			
			.btn-primary {
				color: #03111d;
				background: linear-gradient(135deg, var(--cyan), var(--blue-2));
				box-shadow: 0 10px 30px rgba(47, 232, 255, 0.2);
			}
			
			.btn-secondary {
				color: var(--text);
				background: rgba(7, 20, 42, 0.74);
			}
			
			.hero-side {
				padding: 24px;
				display: grid;
				gap: 14px;
				align-content: center;
			}
			
			.mini-stat {
				padding: 18px;
				border-radius: 18px;
				background: rgba(2, 10, 26, 0.55);
				border: 1px solid rgba(92, 200, 255, 0.18);
			}
			
			.mini-label {
				font-size: 0.82rem;
				color: var(--muted);
				text-transform: uppercase;
				letter-spacing: 0.12em;
				margin-bottom: 8px;
			}
			
			.mini-value {
				font-size: 1.9rem;
				font-weight: 700;
			}
			
			.grid {
				display: grid;
				grid-template-columns: repeat(12, 1fr);
				gap: 24px;
			}
			
			.span-8 {
				grid-column: span 8;
			}
			
			.span-4 {
				grid-column: span 4;
			}
			
			.span-6 {
				grid-column: span 6;
			}
			
			.span-12 {
				grid-column: span 12;
			}
			
			.section {
				padding: 24px;
			}
			
			.section h2 {
				margin: 0 0 16px;
				font-size: 1.15rem;
				letter-spacing: 0.01em;
			}
			
			.links {
				display: grid;
				gap: 12px;
			}
			
			.link-card {
				display: flex;
				align-items: center;
				justify-content: space-between;
				gap: 14px;
				padding: 16px 18px;
				border-radius: 16px;
				border: 1px solid rgba(92, 200, 255, 0.16);
				background: rgba(4, 14, 34, 0.58);
				color: var(--text);
				text-decoration: none;
			}
			
			.link-card small {
				display: block;
				color: var(--muted);
				margin-top: 4px;
			}
			
			.dot {
				width: 12px;
				height: 12px;
				border-radius: 999px;
				background: linear-gradient(135deg, var(--cyan), var(--blue));
				box-shadow: 0 0 18px rgba(47, 232, 255, 0.7);
				flex: none;
			}
			
			.apps {
				display: grid;
				grid-template-columns: repeat(2, minmax(0, 1fr));
				gap: 14px;
			}
			
			.app {
				padding: 18px;
				border-radius: 18px;
				border: 1px solid rgba(92, 200, 255, 0.16);
				background: rgba(4, 16, 39, 0.68);
			}
			
			.app strong {
				display: block;
				margin-bottom: 8px;
				font-size: 1rem;
			}
			
			.app span {
				color: var(--muted);
				font-size: 0.93rem;
				line-height: 1.6;
			}
			
			.excel-frame {
				min-height: 360px;
				padding: 0;
			}
			
			.excel-shell {
				height: 100%;
				min-height: 360px;
				display: grid;
				place-items: center;
				border-radius: var(--radius);
				background:
				linear-gradient(180deg, rgba(4, 15, 35, 0.5), rgba(3, 12, 26, 0.78)),
				repeating-linear-gradient(0deg, rgba(92, 200, 255, 0.06) 0 1px, transparent 1px 36px),
				repeating-linear-gradient(90deg, rgba(92, 200, 255, 0.06) 0 1px, transparent 1px 120px);
			}
			
			.excel-box {
				width: min(92%, 720px);
				border-radius: 18px;
				border: 1px solid rgba(92, 200, 255, 0.22);
				background: rgba(4, 14, 32, 0.9);
				box-shadow: var(--glow);
				overflow: hidden;
			}
			
			.excel-top {
				display: flex;
				align-items: center;
				justify-content: space-between;
				padding: 14px 16px;
				border-bottom: 1px solid rgba(92, 200, 255, 0.16);
				background: linear-gradient(90deg, rgba(47, 232, 255, 0.1), rgba(33, 139, 255, 0.08));
				font-size: 0.95rem;
			}
			
			.excel-table {
				width: 100%;
				border-collapse: collapse;
				font-size: 0.92rem;
			}
			
			.excel-table th,
			.excel-table td {
				padding: 12px 14px;
				border-bottom: 1px solid rgba(92, 200, 255, 0.09);
				text-align: left;
			}
			
			.excel-table th {
				color: var(--blue-2);
				font-weight: 600;
				background: rgba(7, 24, 52, 0.76);
			}
			
			.status {
				display: inline-flex;
				align-items: center;
				gap: 8px;
				padding: 7px 10px;
				border-radius: 999px;
				background: rgba(47, 232, 255, 0.08);
				color: #b9f8ff;
				border: 1px solid rgba(47, 232, 255, 0.18);
				font-size: 0.84rem;
			}
			
			.footer-note {
				margin-top: 24px;
				color: var(--muted);
				text-align: center;
				font-size: 0.9rem;
			}
			
			@media (max-width: 1100px) {
				
				.hero,
				.grid {
					grid-template-columns: 1fr;
				}
				
				.span-8,
				.span-6,
				.span-4,
				.span-12 {
					grid-column: auto;
				}
			}
			
			@media (max-width: 700px) {
				.wrap {
					padding: 16px;
				}
				
				.topbar {
					flex-direction: column;
					align-items: flex-start;
				}
				
				.apps {
					grid-template-columns: 1fr;
				}
				
				.hero-main,
				.hero-side,
				.section {
					padding: 20px;
				}
				
				.cta-row {
					flex-direction: column;
				}
				
				.btn {
					width: 100%;
					justify-content: center;
				}
			}
		</style>
	</head>

	<body>
		<div class="wrap">
			<header class="topbar">
				<div class="brand">
					<div class="logo">T</div>
					<div>
						<div class="title">TDS Tech Training Portal</div>
						<div class="subtitle">SharePoint-ready static dashboard</div>
					</div>
				</div>
				<nav class="pillbar" aria-label="Primary navigation">
					<a class="pill" href="#tools">Tools</a>
					<a class="pill" href="#apps">Apps</a>
					<a class="pill" href="#reports">Reports</a>
					<a class="pill" href="#excel">Excel</a>
				</nav>
			</header>

			<section class="hero">
				<article class="panel hero-main">
					<div>
						<div class="status"><span class="dot"></span>
						Field ops dashboard ready for SharePoint embedding</div>
						<h1>Training, tools, docs, and operational views in one lightning-blue portal.</h1>
						<p class="lead">This static dashboard is designed as a fallback path when native SPFx deployment is
							blocked. It can be uploaded as a static HTML page, copied to ASPX if your SharePoint environment
							supports it, or hosted elsewhere and embedded into a modern SharePoint page.</p>
						<div class="cta-row">
							<a class="btn btn-primary" href="#excel">Open Excel preview</a>
							<a class="btn btn-secondary" href="#tools">Browse field resources</a>
						</div>
					</div>
				</article>

				<aside class="panel hero-side">
					<div class="mini-stat">
						<div class="mini-label">Primary palette</div>
						<div class="mini-value">Dark Navy + Electric Cyan</div>
					</div>
					<div class="mini-stat">
						<div class="mini-label">Layout mode</div>
						<div class="mini-value">Static SharePoint Fallback</div>
					</div>
					<div class="mini-stat">
						<div class="mini-label">Target use</div>
						<div class="mini-value">Training, links, app launch, Excel surface</div>
					</div>
				</aside>
			</section>

			<section class="grid">
				<article id="tools" class="panel span-8 section">
					<h2>Field resources</h2>
					<div class="links">
						<a class="link-card" href="#">
							<div>
								<strong>Fiber install playbooks</strong>
								<small>ONT, DPU, validation flows, and standard work notes.</small>
							</div>
							<span class="dot" aria-hidden="true"></span>
						</a>
						<a class="link-card" href="#">
							<div>
								<strong>Salesforce ticket views</strong>
								<small>Queue links, dispatch workflows, and follow-up actions.</small>
							</div>
							<span class="dot" aria-hidden="true"></span>
						</a>
						<a class="link-card" href="#">
							<div>
								<strong>VoIP and Polycom references</strong>
								<small>Provisioning notes, templates, and troubleshooting docs.</small>
							</div>
							<span class="dot" aria-hidden="true"></span>
						</a>
						<a class="link-card" href="#">
							<div>
								<strong>Safety and NEC quick lookup</strong>
								<small>Field-ready access to code references and checklists.</small>
							</div>
							<span class="dot" aria-hidden="true"></span>
						</a>
					</div>
				</article>

				<article id="apps" class="panel span-4 section">
					<h2>App launcher</h2>
					<div class="apps">
						<div class="app">
							<strong>Excel</strong>
							<span>Embed workbooks, KPI sheets, dispatch trackers, and training matrices.</span>
						</div>
						<div class="app">
							<strong>Lists</strong>
							<span>Surface field inventory, task queues, and process checklists.</span>
						</div>
						<div class="app">
							<strong>Docs</strong>
							<span>Link SOPs, engineering PDFs, troubleshooting guides, and forms.</span>
						</div>
						<div class="app">
							<strong>Teams</strong>
							<span>Pin collaboration channels, escalation spaces, and announcements.</span>
						</div>
					</div>
				</article>

				<article id="excel" class="panel span-12 excel-frame">
					<div class="excel-shell">
						<div class="excel-box">
							<div class="excel-top">
								<strong>Excel embed preview</strong>
								<span>Replace this sample table with an Excel iframe or workbook link</span>
							</div>
							<table class="excel-table">
								<thead>
									<tr>
										<th>Team</th>
										<th>Open Jobs</th>
										<th>Validation Rate</th>
										<th>Status</th>
									</tr>
								</thead>
								<tbody>
									<tr>
										<td>Fiber Install</td>
										<td>18</td>
										<td>97.4%</td>
										<td>Healthy</td>
									</tr>
									<tr>
										<td>Repair</td>
										<td>9</td>
										<td>95.1%</td>
										<td>Watching</td>
									</tr>
									<tr>
										<td>Voice</td>
										<td>6</td>
										<td>98.8%</td>
										<td>Healthy</td>
									</tr>
									<tr>
										<td>Training</td>
										<td>4</td>
										<td>100%</td>
										<td>Ready</td>
									</tr>
								</tbody>
							</table>
						</div>
					</div>
				</article>

				<article id="reports" class="panel span-6 section">
					<h2>Operational signals</h2>
					<div class="links">
						<div class="link-card">
							<div>
								<strong>Morning readiness review</strong>
								<small>Jobs, blockers, materials, and route readiness snapshots.</small>
							</div>
							<span class="dot" aria-hidden="true"></span>
						</div>
						<div class="link-card">
							<div>
								<strong>Training completion heatmap</strong>
								<small>Track module completion by team, role, and territory.</small>
							</div>
							<span class="dot" aria-hidden="true"></span>
						</div>
					</div>
				</article>

				<article class="panel span-6 section">
					<h2>Embed guidance</h2>
					<div class="links">
						<div class="link-card">
							<div>
								<strong>Option 1: Upload as static page</strong>
								<small>Use this file as `index.html`, then copy it to `index.aspx` if your site supports
									rendering uploaded ASPX content.</small>
							</div>
							<span class="dot" aria-hidden="true"></span>
						</div>
						<div class="link-card">
							<div>
								<strong>Option 2: Host externally and embed</strong>
								<small>Publish to a static host, then use the SharePoint Embed web part with the hosted
									URL.</small>
							</div>
							<span class="dot" aria-hidden="true"></span>
						</div>
					</div>
				</article>
			</section>

			<div class="footer-note">Built as a static fallback for SharePoint environments where direct SPFx deployment is
				blocked.</div>
		</div>
	</body>
</html>
