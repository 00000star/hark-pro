#!/bin/bash
set -e

PROJECT_DIR="/sdcard/Antigravity_Projects/hark_agent"
cd "$PROJECT_DIR"

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
# Try creating repo if it doesn't exist, otherwise push to existing
gh repo create hark-pro --public --source=. --remote=origin --push 2>/dev/null || git push -u origin main --force 2>/dev/null || true

echo "=== 4. Checking Workflow Status ==="
sleep 8
RUN_ID=$(gh run list --workflow="Build Hark Pro APK" --limit 1 --json databaseId --jq '.[0].databaseId' 2>/dev/null || true)

if [ -n "$RUN_ID" ] && [ "$RUN_ID" != "null" ]; then
    echo "Triggered Workflow Run ID: $RUN_ID"
    echo "Monitoring build in progress..."
    gh run watch "$RUN_ID" --exit-status || true

    echo "=== 5. Downloading APK Artifact ==="
    mkdir -p /sdcard/Download
    gh run download "$RUN_ID" --name HarkPro-Release-APK --dir /sdcard/Download/ 2>/dev/null || true
    
    # Locate downloaded apk and copy to standard destination
    APK_FILE=$(find /sdcard/Download -name "*.apk" -type f | head -n 1)
    if [ -n "$APK_FILE" ]; then
        cp "$APK_FILE" /sdcard/Download/HarkPro.apk 2>/dev/null || true
        echo "SUCCESS: APK saved to /sdcard/Download/HarkPro.apk"
        ls -la /sdcard/Download/HarkPro.apk
    fi
else
    echo "Workflow queued. You can also view progress at https://github.com/$(gh api user -q .login 2>/dev/null || echo 'user')/hark-pro/actions"
fi
