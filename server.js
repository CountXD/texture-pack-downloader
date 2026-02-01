const express = require('express');
const archiver = require('archiver');
const https = require('https');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;
const GITHUB_TOKEN = process.env.GITHUB_TOKEN || '';
const GITHUB_USERNAME = process.env.GITHUB_USERNAME || 'CountXD';

// Serve static files
app.use(express.static('public'));

// Helper to make GitHub API requests
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

        if (GITHUB_TOKEN) {
            options.headers['Authorization'] = `token ${GITHUB_TOKEN}`;
        }

        https.get(options, (res) => {
            let data = '';
            res.on('data', chunk => data += chunk);
            res.on('end', () => {
                try {
                    resolve(JSON.parse(data));
                } catch (e) {
                    reject(e);
                }
            });
        }).on('error', reject);
    });
}

// Helper to download file from URL
function downloadFile(url) {
    return new Promise((resolve, reject) => {
        const options = {
            headers: {
                'User-Agent': 'Texture-Pack-Downloader',
                'Accept': 'application/vnd.github.v3.raw'
            }
        };

        if (GITHUB_TOKEN) {
            options.headers['Authorization'] = `token ${GITHUB_TOKEN}`;
        }

        https.get(url, options, (res) => {
            if (res.statusCode === 302 || res.statusCode === 301) {
                // Follow redirect
                https.get(res.headers.location, (redirectRes) => {
                    const chunks = [];
                    redirectRes.on('data', chunk => chunks.push(chunk));
                    redirectRes.on('end', () => resolve(Buffer.concat(chunks)));
                }).on('error', reject);
            } else {
                const chunks = [];
                res.on('data', chunk => chunks.push(chunk));
                res.on('end', () => resolve(Buffer.concat(chunks)));
            }
        }).on('error', reject);
    });
}

// Get all repos for user
app.get('/api/repos', async (req, res) => {
    try {
        const repos = await githubRequest(`/users/${GITHUB_USERNAME}/repos?per_page=100&sort=updated`);

        // Filter to only repos that might be texture packs (have assets folder or pack.mcmeta)
        // Also exclude the downloader webapp itself
        const repoList = repos
            .filter(repo => repo.name !== 'texture-pack-downloader')
            .map(repo => ({
                name: repo.name,
                description: repo.description,
                default_branch: repo.default_branch,
                updated_at: repo.updated_at,
                html_url: repo.html_url
            }));

        res.json(repoList);
    } catch (error) {
        console.error('Error fetching repos:', error);
        res.status(500).json({ error: 'Failed to fetch repos' });
    }
});

// Get branches for a repo
app.get('/api/repos/:owner/:repo/branches', async (req, res) => {
    try {
        const { owner, repo } = req.params;
        const branches = await githubRequest(`/repos/${owner}/${repo}/branches`);
        res.json(branches.map(b => b.name));
    } catch (error) {
        console.error('Error fetching branches:', error);
        res.status(500).json({ error: 'Failed to fetch branches' });
    }
});

// Get repo tree (all files)
async function getRepoTree(owner, repo, branch) {
    const tree = await githubRequest(`/repos/${owner}/${repo}/git/trees/${branch}?recursive=1`);
    return tree.tree.filter(item => item.type === 'blob');
}

// Download repo as ZIP
app.get('/api/repos/:owner/:repo/download', async (req, res) => {
    try {
        const { owner, repo } = req.params;
        const branch = req.query.branch || 'main';
        const suffix = req.query.suffix || ''; // Optional suffix

        // Get all files in repo
        const files = await getRepoTree(owner, repo, branch);

        // Set up ZIP response
        res.setHeader('Content-Type', 'application/zip');
        // Clean suffix to avoid injection, though simple string concatenation is mostly safe for filenames
        const safeSuffix = suffix.replace(/[^a-zA-Z0-9._-]/g, '');
        res.setHeader('Content-Disposition', `attachment; filename="${repo}-${branch}${safeSuffix ? '-' + safeSuffix : ''}.zip"`);

        // Use standard compression (level 1) for speed instead of max (level 9)
        const archive = archiver('zip', { zlib: { level: 1 } });
        archive.pipe(res);

        // Download files in parallel batches to speed up performance
        const BATCH_SIZE = 10;

        // Files to exclude
        const EXCLUDED_FILES = ['README.md', '.gitattributes', '.gitignore'];

        for (let i = 0; i < files.length; i += BATCH_SIZE) {
            const batch = files.slice(i, i + BATCH_SIZE)
                .filter(file => !EXCLUDED_FILES.some(ex => file.path.toLowerCase().endsWith(ex.toLowerCase())));

            // Download batch in parallel
            await Promise.all(batch.map(async (file) => {
                try {
                    const url = `https://raw.githubusercontent.com/${owner}/${repo}/${branch}/${file.path}`;
                    const content = await downloadFile(url);
                    archive.append(content, { name: file.path });
                } catch (err) {
                    console.error(`Failed to download ${file.path}:`, err.message);
                }
            }));
        }

        await archive.finalize();
    } catch (error) {
        console.error('Error creating ZIP:', error);
        res.status(500).json({ error: 'Failed to create ZIP' });
    }
});

app.listen(PORT, () => {
    console.log(`Texture Pack Downloader running on http://localhost:${PORT}`);
});
