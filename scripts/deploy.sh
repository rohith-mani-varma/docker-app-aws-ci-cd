#!/usr/bin/env bash
# Deploy app container to EC2 via SSH.
# Expects: EC2_HOST, EC2_SSH_KEY, IMAGE (env vars)

set -e

: "${EC2_HOST:?EC2_HOST not set}"
: "${EC2_SSH_KEY:?EC2_SSH_KEY not set}"
: "${IMAGE:?IMAGE not set}"

mkdir -p ~/.ssh
printf '%s' "$EC2_SSH_KEY" > ~/.ssh/deploy_key
chmod 600 ~/.ssh/deploy_key

ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  -i ~/.ssh/deploy_key ubuntu@$EC2_HOST "
  set -e
  docker pull $IMAGE
  docker stop -t 5 app-container 2>/dev/null || true
  docker rm -f app-container 2>/dev/null || true
  docker run -d -p 3000:3000 --name app-container --restart unless-stopped $IMAGE
  docker image prune -f
  echo Deployment complete.
"
