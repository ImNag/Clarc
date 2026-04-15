#!/bin/bash
set -e

# ─────────────────────────────────────────────
# Clarc 릴리즈 스크립트
#
# 사용법: ./scripts/release.sh <버전>
# 예시:   ./scripts/release.sh 1.0.1
#
# 사전 조건:
#   - scripts/.env 파일 설정 (build_zip.sh 참고)
#   - Developer ID Application 인증서 설치 (scripts/setup_cert.sh 참고)
#   - gh CLI 인증 완료 (gh auth login)
#   - qa 브랜치에서 실행
# ─────────────────────────────────────────────

VERSION=${1:-""}
if [ -z "$VERSION" ]; then
    echo "❌ 버전을 입력해주세요."
    echo "   사용법: ./scripts/release.sh 1.0.1"
    exit 1
fi

TAG="v${VERSION}"
ZIP="build/Clarc-${VERSION}.zip"
META_FILE="build/.sparkle_meta"

echo "▶ Clarc ${TAG} 릴리즈 시작"
echo ""

# ── 1. 브랜치 확인 ──────────────────────────
BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ "$BRANCH" != "qa" ]; then
    echo "❌ qa 브랜치에서 실행해야 합니다. (현재: $BRANCH)"
    exit 1
fi

# ── 2. 빌드 + 노터라이제이션 ─────────────────
echo "📦 빌드 및 노터라이제이션..."
./scripts/build_zip.sh "$VERSION"
echo ""

# ── 3. appcast.xml 업데이트 ──────────────────
if [ -f "$META_FILE" ]; then
    echo "📡 appcast.xml 업데이트 중..."
    source "$META_FILE"

    REPO_URL="https://github.com/$(gh repo view --json nameWithOwner -q .nameWithOwner)"
    DOWNLOAD_URL="${REPO_URL}/releases/download/${TAG}/${SPARKLE_ZIP}"
    PUB_DATE=$(date -u "+%a, %d %b %Y %H:%M:%S +0000")
    BUILD_NUMBER=$(xcodebuild -project Clarc.xcodeproj -showBuildSettings 2>/dev/null \
        | grep CURRENT_PROJECT_VERSION | awk '{print $3}')

    NEW_ITEM="    <item>
      <title>Clarc ${TAG}</title>
      <sparkle:version>${BUILD_NUMBER}</sparkle:version>
      <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>15.0</sparkle:minimumSystemVersion>
      <pubDate>${PUB_DATE}</pubDate>
      <enclosure
        url=\"${DOWNLOAD_URL}\"
        length=\"${SPARKLE_SIZE}\"
        type=\"application/octet-stream\"
        sparkle:edSignature=\"${SPARKLE_SIGNATURE}\" />
    </item>"

    # </channel> 바로 앞에 새 항목 삽입
    python3 -c "
import sys
content = open('appcast.xml').read()
item = '''${NEW_ITEM}'''
content = content.replace('    <!-- 릴리즈 항목은 /release 명령어 실행 시 scripts/release.sh 에 의해 자동 추가됩니다-->', '')
content = content.replace('  </channel>', item + '\n  </channel>')
open('appcast.xml', 'w').write(content)
"
    echo "✓ appcast.xml 업데이트 완료"
else
    echo "⚠️  Sparkle 메타데이터 없음 — appcast.xml이 업데이트되지 않습니다."
    echo "   최초 설정: ./scripts/setup_sparkle.sh"
fi
echo ""

# ── 4. qa 푸시 + PR 생성 ─────────────────────
echo "🔀 qa 브랜치 푸시 및 PR 생성..."
git push origin qa

gh pr create \
    --title "release: Clarc ${TAG}" \
    --body "## Release ${TAG}

- \`qa\` → \`main\` 병합
- 배포 파일: \`Clarc-${VERSION}.zip\` (노터라이제이션 완료)

🤖 Generated with [Claude Code](https://claude.com/claude-code)" \
    --base main \
    --head qa
echo ""

# ── 5. 태그 생성 ─────────────────────────────
echo "🏷  태그 ${TAG} 생성..."
git tag "$TAG"
git push origin "$TAG"
echo ""

# ── 6. GitHub Release + ZIP 업로드 ───────────
echo "🚀 GitHub Release 생성..."
gh release create "$TAG" "$ZIP" \
    --title "Clarc ${TAG}" \
    --notes "## Clarc ${TAG}

### 설치 방법
1. \`Clarc-${VERSION}.zip\` 다운로드
2. 압축 해제 후 \`Clarc.app\`을 \`/Applications\`로 이동
3. 처음 실행 시 우클릭 → 열기

> 기존 사용자는 앱 내 자동 업데이트로 설치됩니다."
echo ""

# ── 7. appcast.xml을 main에 커밋 + 푸시 ──────
if [ -f "$META_FILE" ]; then
    echo "📤 appcast.xml main 브랜치에 반영 중..."
    git stash push -m "release: appcast.xml ${TAG}" -- appcast.xml
    git checkout main
    git pull origin main
    git stash pop
    git add appcast.xml
    git commit -m "chore(release): appcast.xml ${TAG} 업데이트"
    git push origin main
    git checkout qa
    echo "✓ appcast.xml 배포 완료"
fi

echo ""
echo "─────────────────────────────────────────"
echo "✅ 릴리즈 완료: ${TAG}"
echo "   PR:      $(gh pr list --head qa --json url -q '.[0].url')"
echo "   Release: https://github.com/$(gh repo view --json nameWithOwner -q .nameWithOwner)/releases/tag/${TAG}"
echo "   Appcast: https://raw.githubusercontent.com/$(gh repo view --json nameWithOwner -q .nameWithOwner)/main/appcast.xml"
echo "─────────────────────────────────────────"
