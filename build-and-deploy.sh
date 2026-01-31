#!/bin/bash
# Texture Pack Downloader - One-Command Setup
# Run this on your Kubernetes server to create and build the app

set -e

echo "🎮 Creating Texture Pack Downloader..."

# Create directory
mkdir -p texture-pack-downloader/public texture-pack-downloader/k8s
cd texture-pack-downloader

# Create package.json
cat > package.json << 'EOF'
{
  "name": "texture-pack-downloader",
  "version": "1.0.0",
  "description": "Download Minecraft texture packs from GitHub as ZIP files",
  "main": "server.js",
  "scripts": {
    "start": "node server.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "archiver": "^6.0.1"
  }
}
EOF

# Create server.js
cat > server.js << 'EOF'
const express = require('express');
const archiver = require('archiver');
const https = require('https');

const app = express();
const PORT = process.env.PORT || 3000;
const GITHUB_TOKEN = process.env.GITHUB_TOKEN || '';
const GITHUB_USERNAME = process.env.GITHUB_USERNAME || 'CountXD';

app.use(express.static('public'));

function githubRequest(endpoint) {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: 'api.github.com',
      path: endpoint,
      headers: {
        'User-Agent': 'Texture-Pack-Downloader',
        'Accept': 'application/vnd.github.v3+json'
      }
    };
    if (GITHUB_TOKEN) options.headers['Authorization'] = `token ${GITHUB_TOKEN}`;
    https.get(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => { try { resolve(JSON.parse(data)); } catch (e) { reject(e); } });
    }).on('error', reject);
  });
}

function downloadFile(url) {
  return new Promise((resolve, reject) => {
    const options = { headers: { 'User-Agent': 'Texture-Pack-Downloader', 'Accept': 'application/vnd.github.v3.raw' } };
    if (GITHUB_TOKEN) options.headers['Authorization'] = `token ${GITHUB_TOKEN}`;
    https.get(url, options, (res) => {
      if (res.statusCode === 302 || res.statusCode === 301) {
        https.get(res.headers.location, (r) => { const c = []; r.on('data', d => c.push(d)); r.on('end', () => resolve(Buffer.concat(c))); }).on('error', reject);
      } else { const c = []; res.on('data', d => c.push(d)); res.on('end', () => resolve(Buffer.concat(c))); }
    }).on('error', reject);
  });
}

app.get('/api/repos', async (req, res) => {
  try {
    const repos = await githubRequest(`/users/${GITHUB_USERNAME}/repos?per_page=100&sort=updated`);
    res.json(repos.map(r => ({ name: r.name, description: r.description, default_branch: r.default_branch, updated_at: r.updated_at, html_url: r.html_url })));
  } catch (e) { res.status(500).json({ error: 'Failed to fetch repos' }); }
});

app.get('/api/repos/:owner/:repo/branches', async (req, res) => {
  try {
    const branches = await githubRequest(`/repos/${req.params.owner}/${req.params.repo}/branches`);
    res.json(branches.map(b => b.name));
  } catch (e) { res.status(500).json({ error: 'Failed to fetch branches' }); }
});

app.get('/api/repos/:owner/:repo/download', async (req, res) => {
  try {
    const { owner, repo } = req.params;
    const branch = req.query.branch || 'main';
    const tree = await githubRequest(`/repos/${owner}/${repo}/git/trees/${branch}?recursive=1`);
    const files = tree.tree.filter(i => i.type === 'blob');
    res.setHeader('Content-Type', 'application/zip');
    res.setHeader('Content-Disposition', `attachment; filename="${repo}-${branch}.zip"`);
    const archive = archiver('zip', { zlib: { level: 9 } });
    archive.pipe(res);
    for (const file of files) {
      try {
        const content = await downloadFile(`https://raw.githubusercontent.com/${owner}/${repo}/${branch}/${file.path}`);
        archive.append(content, { name: file.path });
      } catch (e) { console.error(`Skip ${file.path}`); }
    }
    await archive.finalize();
  } catch (e) { res.status(500).json({ error: 'Failed to create ZIP' }); }
});

app.listen(PORT, () => console.log(`Running on http://localhost:${PORT}`));
EOF

# Create public/index.html
cat > public/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Texture Pack Downloader</title>
  <link rel="stylesheet" href="style.css">
</head>
<body>
  <div class="container">
    <header><h1>🎮 Texture Pack Downloader</h1><p class="subtitle">Download your Minecraft texture packs from GitHub</p></header>
    <div id="loading" class="loading"><div class="spinner"></div><p>Loading...</p></div>
    <div id="repos" class="repos-grid"></div>
    <div id="error" class="error" style="display:none;"></div>
  </div>
  <script src="app.js"></script>
</body>
</html>
EOF

# Create public/style.css
cat > public/style.css << 'EOF'
*{margin:0;padding:0;box-sizing:border-box}:root{--bg:#0d1117;--bg2:#161b22;--border:#30363d;--text:#f0f6fc;--text2:#8b949e;--accent:#58a6ff;--success:#3fb950}body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Helvetica,Arial,sans-serif;background:var(--bg);color:var(--text);min-height:100vh}.container{max-width:900px;margin:0 auto;padding:2rem}header{text-align:center;margin-bottom:2.5rem}header h1{font-size:2.2rem;background:linear-gradient(135deg,var(--accent),#a371f7);-webkit-background-clip:text;-webkit-text-fill-color:transparent;background-clip:text}.subtitle{color:var(--text2)}.loading{display:flex;flex-direction:column;align-items:center;padding:4rem;color:var(--text2)}.spinner{width:40px;height:40px;border:3px solid var(--bg2);border-top:3px solid var(--accent);border-radius:50%;animation:spin 1s linear infinite;margin-bottom:1rem}@keyframes spin{0%{transform:rotate(0deg)}100%{transform:rotate(360deg)}}.repos-grid{display:flex;flex-direction:column;gap:1rem}.repo-card{background:var(--bg2);border:1px solid var(--border);border-radius:12px;padding:1.25rem;transition:border-color .2s,transform .2s}.repo-card:hover{border-color:var(--accent);transform:translateY(-2px)}.repo-header{display:flex;justify-content:space-between;align-items:flex-start;gap:1rem;margin-bottom:.75rem}.repo-name{font-size:1.2rem;font-weight:600;color:var(--accent);text-decoration:none}.repo-name:hover{text-decoration:underline}.repo-description{color:var(--text2);font-size:.9rem;margin-bottom:1rem}.repo-actions{display:flex;align-items:center;gap:1rem;flex-wrap:wrap}.branch-select{background:var(--bg);border:1px solid var(--border);border-radius:6px;color:var(--text);padding:.5rem .75rem;font-size:.9rem;min-width:120px}.download-btn{display:inline-flex;align-items:center;gap:.5rem;background:linear-gradient(135deg,var(--success),#238636);color:white;border:none;border-radius:6px;padding:.5rem 1rem;font-size:.9rem;font-weight:500;cursor:pointer;transition:transform .2s,box-shadow .2s}.download-btn:hover{transform:translateY(-1px);box-shadow:0 4px 12px rgba(63,185,80,.3)}.download-btn:disabled{opacity:.6;cursor:not-allowed}.repo-meta{font-size:.8rem;color:var(--text2);margin-top:.75rem}.error{background:rgba(248,81,73,.1);border:1px solid #f85149;border-radius:8px;padding:1rem;color:#f85149;text-align:center}
EOF

# Create public/app.js
cat > public/app.js << 'EOF'
const loadingEl=document.getElementById('loading'),reposEl=document.getElementById('repos'),errorEl=document.getElementById('error');let repos=[];async function init(){try{await loadRepos()}catch(e){showError('Failed to load repositories');console.error(e)}}async function loadRepos(){showLoading(!0);const r=await fetch('/api/repos');if(!r.ok)throw new Error('Failed');repos=await r.json();showLoading(!1);renderRepos()}function renderRepos(){if(!repos.length){reposEl.innerHTML='<div class="empty-state"><p>No repos found</p></div>';return}reposEl.innerHTML=repos.map(r=>`<div class="repo-card" data-repo="${r.name}"><div class="repo-header"><a href="${r.html_url}" target="_blank" class="repo-name">${r.name}</a></div><p class="repo-description">${r.description||'No description'}</p><div class="repo-actions"><select class="branch-select" data-repo="${r.name}"><option value="${r.default_branch}">${r.default_branch}</option></select><button class="download-btn" onclick="downloadRepo('${r.name}')">📥 Download ZIP</button></div><div class="repo-meta">Updated: ${formatDate(r.updated_at)}</div></div>`).join('');repos.forEach(r=>loadBranches(r.name))}async function loadBranches(n){try{const r=await fetch(`/api/repos/CountXD/${n}/branches`);if(!r.ok)return;const b=await r.json(),s=document.querySelector(`.branch-select[data-repo="${n}"]`);if(s&&b.length)s.innerHTML=b.map(x=>`<option value="${x}">${x}</option>`).join('')}catch(e){}}async function downloadRepo(n){const s=document.querySelector(`.branch-select[data-repo="${n}"]`),b=s?s.value:'main',btn=document.querySelector(`.repo-card[data-repo="${n}"] .download-btn`),orig=btn.innerHTML;btn.innerHTML='⏳ Downloading...';btn.disabled=!0;try{const a=document.createElement('a');a.href=`/api/repos/CountXD/${n}/download?branch=${encodeURIComponent(b)}`;a.download=`${n}-${b}.zip`;document.body.appendChild(a);a.click();document.body.removeChild(a);setTimeout(()=>{btn.innerHTML='✅ Done!';setTimeout(()=>{btn.innerHTML=orig;btn.disabled=!1},2e3)},1e3)}catch(e){btn.innerHTML='❌ Failed';setTimeout(()=>{btn.innerHTML=orig;btn.disabled=!1},2e3)}}function formatDate(d){return new Date(d).toLocaleDateString('en-US',{year:'numeric',month:'short',day:'numeric'})}function showLoading(s){loadingEl.style.display=s?'flex':'none'}function showError(m){showLoading(!1);errorEl.textContent=m;errorEl.style.display='block'}init();
EOF

# Create Dockerfile
cat > Dockerfile << 'EOF'
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install --production
COPY . .
EXPOSE 3000
CMD ["node", "server.js"]
EOF

# Create .dockerignore
cat > .dockerignore << 'EOF'
.git
node_modules
*.md
EOF

# Create k8s/deployment.yaml
cat > k8s/deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: texture-pack-downloader
spec:
  replicas: 1
  selector:
    matchLabels:
      app: texture-pack-downloader
  template:
    metadata:
      labels:
        app: texture-pack-downloader
    spec:
      containers:
      - name: app
        image: texture-pack-downloader:latest
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 3000
        env:
        - name: GITHUB_USERNAME
          value: "CountXD"
EOF

# Create k8s/service.yaml
cat > k8s/service.yaml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: texture-pack-downloader
spec:
  selector:
    app: texture-pack-downloader
  ports:
  - port: 80
    targetPort: 3000
  type: ClusterIP
EOF

echo "✅ Files created!"
echo ""
echo "🔨 Building Docker image..."
docker build -t texture-pack-downloader:latest .

echo ""
echo "🚀 Deploying to Kubernetes..."
kubectl apply -f k8s/

echo ""
echo "✅ Done! To access the app:"
echo "   kubectl port-forward svc/texture-pack-downloader 3000:80"
echo "   Then open http://localhost:3000"
