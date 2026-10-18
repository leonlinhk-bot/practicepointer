#!/bin/zsh
# 把本機 repo/ 推上 GitHub
#
# 前提：GitHub 上已建立「空」倉庫（不要勾 README / .gitignore / LICENSE，
#       否則會因為歷史不相關而被拒絕推送）。
#
# 用法：./tools/connect-github.sh <倉庫網址或 owner/repo>
#   例：./tools/connect-github.sh git@github.com:practicepointer/practicepointer.git
#   例：./tools/connect-github.sh practicepointer/practicepointer   （自動補成 SSH 網址）

set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE/.."

ARG="${1:-}"
if [ -z "$ARG" ]; then
  echo "用法：./tools/connect-github.sh <owner/repo 或 倉庫網址>" >&2
  exit 2
fi

case "$ARG" in
  *:*) URL="$ARG" ;;
  http*) URL="$ARG" ;;
  *) URL="git@github.com:${ARG}.git" ;;
esac
echo "遠端：$URL"

# 推送前的三道關卡，任何一道不過就停
echo ""
echo "=== 1/3 敏感資訊檢查 ==="
hits=$(grep -rniI "leonl\.inhk\|@gmail\|Leon Liang" . 2>/dev/null | grep -v "^./.git/" || true)
if [ -n "$hits" ]; then
  echo "❌ 發現個人資訊，已中止（本倉庫會公開）："
  echo "$hits" | head -5
  exit 1
fi
echo "  零命中 ✅"

echo ""
echo "=== 2/3 提交者身分檢查 ==="
authors=$(git log --format="%ae" | sort -u)
echo "  $authors" | sed 's/^/  /'
if echo "$authors" | grep -qiE "@gmail|leonl|leonliang"; then
  echo "  ❌ 歷史裡有個人郵箱，push 後會永久公開，已中止"
  exit 1
fi
echo "  全為中性身分 ✅"

echo ""
echo "=== 3/3 分支 ==="
git branch -M main 2>/dev/null || true
echo "  當前分支：$(git rev-parse --abbrev-ref HEAD)"

echo ""
if git remote get-url origin >/dev/null 2>&1; then
  echo "origin 已存在，改指向新網址"
  git remote set-url origin "$URL"
else
  git remote add origin "$URL"
fi

git push -u origin main
echo ""
echo "✅ 推送完成。下一步：跑 ./tools/set-repo.sh <owner>/<repo> 換掉站上的糾錯連結。"
