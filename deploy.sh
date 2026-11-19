#!/usr/bin/env bash
# EPL LAB 랜딩페이지 → GitHub Pages 배포/검증 (저장소가 이미 존재할 때 실행)
set -u
OWNER=ahyoungkim0802-web
REPO=epl-lab
URL="https://$OWNER.github.io/$REPO/"
cd "$(dirname "$0")" || exit 1

echo "== 1. 저장소 확인"
gh repo view "$OWNER/$REPO" --json name,visibility,isEmpty,defaultBranchRef \
  --jq '.name+" "+.visibility+" empty="+(.isEmpty|tostring)+" default="+(.defaultBranchRef.name // "none")' 2>&1 || { echo "NO_REPO"; exit 10; }

echo "== 2. 푸시"
if ! git remote get-url origin >/dev/null 2>&1; then
  git remote add origin "https://github.com/$OWNER/$REPO.git"
fi
if ! git push -u origin main 2>&1; then
  echo "-- 원격에 다른 커밋이 있음: 합친 뒤 다시 푸시"
  git fetch origin 2>&1
  BR=$(gh repo view "$OWNER/$REPO" --json defaultBranchRef --jq '.defaultBranchRef.name // "main"')
  git -c pull.rebase=false pull --no-rebase --allow-unrelated-histories origin "$BR" --no-edit 2>&1
  git push -u origin HEAD:"$BR" 2>&1 || { echo "PUSH_FAILED"; exit 11; }
fi

echo "== 3. Pages 활성화"
if gh api "repos/$OWNER/$REPO/pages" >/dev/null 2>&1; then
  echo "Pages 이미 활성화됨"
else
  gh api -X POST "repos/$OWNER/$REPO/pages" \
    -f 'source[branch]=main' -f 'source[path]=/' 2>&1 || { echo "PAGES_ENABLE_FAILED"; exit 12; }
fi

echo "== 4. 빌드 대기"
for i in $(seq 1 30); do
  ST=$(gh api "repos/$OWNER/$REPO/pages" --jq '.status' 2>/dev/null)
  echo "  pages status: ${ST:-?} ($(date +%H:%M:%S))"
  [ "$ST" = "built" ] && break
  sleep 10
done

echo "== 5. 라이브 확인"
for u in "$URL" "${URL}assets/monster-home.webp" "${URL}assets/fonts/PretendardVariable.woff2" "${URL}assets/report-sample.webp"; do
  code=$(curl -s -o /dev/null -w '%{http_code} %{size_download}' -L "$u")
  echo "  $code  $u"
done
echo "== 6. 본문 확인"
curl -sL "$URL" | grep -o '<title>[^<]*</title>' | head -1
