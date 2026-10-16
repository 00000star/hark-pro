#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR"

if [ -d "/sdcard/Download" ] && [ -w "/sdcard/Download" ]; then
    OUT_DIR="/sdcard/Download"
elif [ -d "$HOME/Downloads" ]; then
    OUT_DIR="$HOME/Downloads"
else
    OUT_DIR="$PROJECT_DIR/dist"
    mkdir -p "$OUT_DIR"
fi

echo "=== 1. Authenticating GitHub CLI ==="
if ! gh auth status &>/dev/null; then
    echo "$GITHUB_TOKEN" | gh auth login --with-token 2>/dev/null || true
fi

echo "=== 2. Configuring Git ==="
git config user.name "Starboy" || true
git config user.email "starboy@antigravity.ai" || true
git config init.defaultBranch main || true

if [ ! -d ".git" ]; then
    git init
    git branch -M main
fi

git add .
git commit -m "feat: complete Hark Pro stack with CI/CD" 2>/dev/null || true

echo "=== 3. Pushing to GitHub ==="
gh repo create hark-pro --public --source=. --remote=origin --push 2>/dev/null || git push -u origin main --force 2>/dev/null || true

echo "=== 4. Checking Workflow Status ==="
sleep 8
RUN_ID=$(gh run list --workflow="Build Hark Pro APK" --limit 1 --json databaseId --jq '.[0].databaseId' 2>/dev/null || true)

if [ -n "$RUN_ID" ] && [ "$RUN_ID" != "null" ]; then
    echo "Triggered Workflow Run ID: $RUN_ID"
    echo "Monitoring build in progress..."
    gh run watch "$RUN_ID" --exit-status || true

    echo "=== 5. Downloading APK Artifact ==="
    TMP_DIR="$OUT_DIR/hark_apk_tmp"
    mkdir -p "$TMP_DIR"
    rm -rf "$TMP_DIR"/*
    gh run download "$RUN_ID" --name HarkPro-Release-APK --dir "$TMP_DIR" 2>/dev/null || true

    APK_FILE=$(find "$TMP_DIR" -name "*.apk" -type f | head -n 1)
    if [ -n "$APK_FILE" ]; then
        cp "$APK_FILE" "$OUT_DIR/HarkPro.apk" 2>/dev/null || true
        echo "SUCCESS: APK saved to $OUT_DIR/HarkPro.apk"
        ls -la "$OUT_DIR/HarkPro.apk"
    fi
else
    echo "Workflow queued. You can also view progress at https://github.com/$(gh api user -q .login 2>/dev/null || echo 'user')/hark-pro/actions"
fi
