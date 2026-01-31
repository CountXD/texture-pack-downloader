// Texture Pack Downloader - Frontend Logic

const API_BASE = '';

// DOM Elements
const loadingEl = document.getElementById('loading');
const reposEl = document.getElementById('repos');
const errorEl = document.getElementById('error');

// State
let repos = [];

// Initialize
async function init() {
    try {
        await loadRepos();
    } catch (error) {
        showError('Failed to load repositories. Please check your connection.');
        console.error(error);
    }
}

// Load repositories
async function loadRepos() {
    showLoading(true);

    const response = await fetch(`${API_BASE}/api/repos`);
    if (!response.ok) throw new Error('Failed to fetch repos');

    repos = await response.json();

    showLoading(false);
    renderRepos();
}

// Render repository cards
function renderRepos() {
    if (repos.length === 0) {
        reposEl.innerHTML = `
      <div class="empty-state">
        <p>No repositories found</p>
      </div>
    `;
        return;
    }

    reposEl.innerHTML = repos.map(repo => `
    <div class="repo-card" data-repo="${repo.name}">
      <div class="repo-header">
        <a href="${repo.html_url}" target="_blank" class="repo-name">${repo.name}</a>
      </div>
      <p class="repo-description">${repo.description || 'No description'}</p>
      <div class="repo-actions">
        <select class="branch-select" data-repo="${repo.name}">
          <option value="${repo.default_branch}">${repo.default_branch}</option>
        </select>
        <button class="download-btn" onclick="downloadRepo('${repo.name}')">
          📥 Download ZIP
        </button>
      </div>
      <div class="repo-meta">
        Updated: ${formatDate(repo.updated_at)}
      </div>
    </div>
  `).join('');

    // Load branches for each repo
    repos.forEach(repo => loadBranches(repo.name));
}

// Load branches for a repo
async function loadBranches(repoName) {
    try {
        const response = await fetch(`${API_BASE}/api/repos/CountXD/${repoName}/branches`);
        if (!response.ok) return;

        const branches = await response.json();
        const select = document.querySelector(`.branch-select[data-repo="${repoName}"]`);

        if (select && branches.length > 0) {
            select.innerHTML = branches.map(branch =>
                `<option value="${branch}">${branch}</option>`
            ).join('');
        }
    } catch (error) {
        console.error(`Failed to load branches for ${repoName}:`, error);
    }
}

// Download repository as ZIP
async function downloadRepo(repoName) {
    const select = document.querySelector(`.branch-select[data-repo="${repoName}"]`);
    const branch = select ? select.value : 'main';
    const btn = document.querySelector(`.repo-card[data-repo="${repoName}"] .download-btn`);

    // Update button state
    const originalText = btn.innerHTML;
    btn.innerHTML = '⏳ Downloading...';
    btn.disabled = true;
    btn.classList.add('loading');

    try {
        const url = `${API_BASE}/api/repos/CountXD/${repoName}/download?branch=${encodeURIComponent(branch)}`;

        // Trigger download
        const link = document.createElement('a');
        link.href = url;
        link.download = `${repoName}-${branch}.zip`;
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);

        // Restore button after a delay
        setTimeout(() => {
            btn.innerHTML = '✅ Downloaded!';
            setTimeout(() => {
                btn.innerHTML = originalText;
                btn.disabled = false;
                btn.classList.remove('loading');
            }, 2000);
        }, 1000);
    } catch (error) {
        console.error('Download failed:', error);
        btn.innerHTML = '❌ Failed';
        setTimeout(() => {
            btn.innerHTML = originalText;
            btn.disabled = false;
            btn.classList.remove('loading');
        }, 2000);
    }
}

// Helper: Format date
function formatDate(dateStr) {
    const date = new Date(dateStr);
    return date.toLocaleDateString('en-US', {
        year: 'numeric',
        month: 'short',
        day: 'numeric'
    });
}

// Helper: Show/hide loading
function showLoading(show) {
    loadingEl.style.display = show ? 'flex' : 'none';
}

// Helper: Show error
function showError(message) {
    showLoading(false);
    errorEl.textContent = message;
    errorEl.style.display = 'block';
}

// Start app
init();
