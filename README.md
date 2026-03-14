# Automated Docker Deployment Pipeline on AWS

A production-style **CI/CD pipeline** that builds a Node.js API as a Docker image, pushes it to GitHub Container Registry (GHCR), and deploys to an Ubuntu EC2 instance on every push to `main`.

---

## Architecture (Option B — Registry-based)

```
Developer pushes to main
        │
        ▼
GitHub Actions
        │
        ├── Build Docker image (multi-stage, version-tagged)
        ├── Push to GitHub Container Registry (ghcr.io)
        │
        ▼
SSH to EC2
        │
        ├── Pull latest image
        ├── Stop & remove old container
        └── Run new container (port 80 → 3000, restart policy)
```

---

## Repository structure

```
docker-app-aws-ci-cd/
├── app/
│   ├── server.js              # Express API (GET /, GET /health)
│   ├── package.json
│   └── package-lock.json
├── .github/
│   └── workflows/
│       └── deploy.yml         # Build → Push → Deploy
├── Dockerfile                 # Multi-stage, health check
├── .dockerignore
├── .gitignore
└── README.md
```

---

## Local run (Docker)

```bash
# Build
docker build -t devops-portfolio-api:local .

# Run (app on port 3000)
docker run -d -p 3000:3000 --name app-container devops-portfolio-api:local

# Test
curl http://localhost:3000/
# Hello from DevOps Portfolio 🚀

curl http://localhost:3000/health
# {"status":"ok","timestamp":"..."}

# Stop and remove
docker stop app-container && docker rm app-container
```

---

## API

| Endpoint   | Response |
|-----------|----------|
| `GET /`   | `Hello from DevOps Portfolio 🚀` |
| `GET /health` | `{"status":"ok","timestamp":"..."}` |

Port: **3000** (inside container). Pipeline maps **host 80 → container 3000** on EC2.

---

## EC2 server setup (Ubuntu)

Use an **Ubuntu** EC2 instance (e.g. **t3.micro**). Configure the following.

### 1. Security group

| Type | Port | Source |
|------|------|--------|
| SSH | 22 | Your IP |
| HTTP | 80 | 0.0.0.0/0 |

(Application port 3000 is only used inside the host; external traffic uses 80.)

### 2. Install Docker on EC2

SSH into the instance, then:

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin
sudo usermod -aG docker ubuntu
```

Log out and back in (or new SSH session) so `docker` works without `sudo`.

### 3. (Optional) Pull from private GHCR

If the GHCR package is **private**, on the EC2 instance run once (replace `USER` and `PAT`):

```bash
echo "YOUR_GITHUB_PAT" | docker login ghcr.io -u USER --password-stdin
```

For **public** packages, no login is needed.

---

## GitHub Actions setup

### 1. Repository settings

- Code is in a **GitHub** repo; pipeline runs on **push to `main`**.

### 2. Package visibility (GHCR)

- First pipeline run will create the package under the repo owner (e.g. `ghcr.io/<owner>/devops-portfolio-api`).
- In **GitHub → Your profile → Packages**, open the package → **Package settings** → set **Visibility** to **Public** if you want EC2 to pull without login.

### 3. Secrets

In **Settings → Secrets and variables → Actions**, add:

| Secret       | Description |
|-------------|-------------|
| `EC2_HOST`  | EC2 public IP or DNS (e.g. `3.12.34.56` or `ec2-3-12-34-56.compute-1.amazonaws.com`) |
| `EC2_SSH_KEY` | Full contents of the **private** key file (e.g. `id_rsa` or `.pem`) used to SSH as `ubuntu` |

No other secrets are required for the pipeline. For private GHCR, configure `docker login` on EC2 as above; do **not** put the PAT in GitHub Actions for this design.

### 4. Deploy behavior

- **Push to `main`** → workflow runs.
- **Build job**: checkout → build image → push to GHCR with tag `latest` and `sha-<short-sha>`.
- **Deploy job**: SSH to EC2 → `docker pull` → `docker stop` / `docker rm` old `app-container` → `docker run` with `-p 80:3000`, `--name app-container`, `--restart unless-stopped`.

If `EC2_HOST` or `EC2_SSH_KEY` is missing, the deploy job is skipped (build and push still run).

---

## Deliverables checklist

- [x] Node.js Express API in `app/`
- [x] Dockerfile (multi-stage, non-root, health check)
- [x] GitHub Actions workflow: build → push to GHCR → deploy via SSH
- [x] Deployment and EC2 setup instructions (this README)
- [ ] Screenshots (you add): running GitHub Actions pipeline, app in browser on EC2

---

## Optional extras included

- **Docker**: multi-stage build, `.dockerignore`, non-root user, `HEALTHCHECK`, `--restart unless-stopped`.
- **Pipeline**: image tagged as `latest` and `sha-<short-sha>`, GHCR cache, OCI labels.
- **API**: `/health` for health checks.

---

## Cost (approximate)

- **EC2 t3.micro** (always on): about **$7–10/month**.
- **GitHub Actions**: free for public repos; private repos have a free tier.
- **GHCR**: free for public and moderate private usage.

---

## Tech stack

| Component        | Technology           |
|-----------------|----------------------|
| Application     | Node.js + Express    |
| Container       | Docker (Alpine), `--restart unless-stopped` (restarts container on crash) |
| CI/CD           | GitHub Actions       |
| Registry        | GitHub Container Registry |
| Server          | AWS EC2 (Ubuntu)     |

---

## Required environment variables

| Where        | Variable     | Required | Description |
|-------------|--------------|----------|-------------|
| **GitHub Actions** | `EC2_HOST`   | Yes (for deploy) | EC2 public IP or hostname |
| **GitHub Actions** | `EC2_SSH_KEY` | Yes (for deploy) | Private key contents for SSH as `ubuntu` |
| **App (optional)** | `PORT`       | No  | Server port (default `3000`) |
| **App (optional)** | `NODE_ENV`   | No  | e.g. `production` |
