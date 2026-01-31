# Texture Pack Downloader

Download Minecraft texture packs from GitHub as ZIP files.

## Quick Start (Local)

```bash
npm install
npm start
```

Open http://localhost:3000

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `PORT` | Server port | 3000 |
| `GITHUB_USERNAME` | GitHub username to list repos from | CountXD |
| `GITHUB_TOKEN` | GitHub token (optional, for higher rate limits) | - |

## Docker

```bash
# Build
docker build -t texture-pack-downloader .

# Run
docker run -p 3000:3000 -e GITHUB_USERNAME=CountXD texture-pack-downloader
```

## Kubernetes

```bash
# Build and load image (for local k8s like minikube/k3s)
docker build -t texture-pack-downloader:latest .

# Deploy
kubectl apply -f k8s/

# Optional: Create secret for GitHub token
kubectl create secret generic github-token --from-literal=token=YOUR_TOKEN
```

Then uncomment the `GITHUB_TOKEN` env section in `k8s/deployment.yaml`.

## Features

- List all repos from your GitHub account
- Select branch/version to download
- Download as ZIP file
- Dark themed UI
