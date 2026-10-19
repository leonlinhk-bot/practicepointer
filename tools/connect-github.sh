#!/bin/zsh
# 把本機 repo/ 推上 GitHub
#
# 前提：GitHub 上已建立「空」倉庫（不要勾 README / .gitignore / LICENSE，
#       否則會因為歷史不相關而被拒絕推送）。
#
# 用法：./tools/connect-github.sh <倉庫網址>
#   例：./tools/connect-github.sh https://github.com/<owner>/practicepointer.git
#   例：./tools/connect-github.sh git@github.com:<owner>/practicepointer.git
# 憑證：走 git credential helper（本機 ~/.git-credentials），本腳本不接觸 token 本身。
#
# ⚠️ 為什麼掃描要排除自己：前一版把偵測用的字面量寫在腳本裡，
#   掃描時掃到自己 → 假紅，把合法的 push 擋掉了。
#   現在模式獨立放在 tools/pii-patterns.txt，只排除那一個檔與本檔。

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE/.."

ARG="${1:-}"
if [ -z "$ARG" ]; then
  echo "用法：./tools/connect-github.sh <倉庫網址>" >&2
  exit 2
fi
echo "遠端：$ARG"

echo ""
echo "=== 1/3 個人資訊檢查（掃已追蹤檔案）==="
# ⚠️ 模式檔裡不能留空行：grep -f 會把「空正則」當成匹配所有行，
#    結果每個檔案的每一行都算命中 —— 假紅。所以先清掉空行與 # 註解再餵給 grep。
PAT_CLEAN="$(mktemp)"
{
  grep -vE '^[[:space:]]*(#|$)' "$HERE/pii-patterns.txt"
  # 專案專屬的具體字串放在本地檔（.gitignore 已排除）。
  # 理由：公開的偵測清單如果把姓名郵箱寫進去，等於用偵測器把要保護的東西公開。
  if [ -f "$HERE/pii-patterns.local.txt" ]; then
    grep -vE '^[[:space:]]*(#|$)' "$HERE/pii-patterns.local.txt"
  fi
} > "$PAT_CLEAN"
trap 'rm -f "$PAT_CLEAN"' EXIT
echo "  使用模式：$(tr '\n' ' ' < "$PAT_CLEAN")"
hits=$(git ls-files \
       | grep -vE '^tools/(connect-github\.sh|pii-patterns\.txt)$' \
       | tr '\n' '\0' \
       | xargs -0 grep -niI -f "$PAT_CLEAN" 2>/dev/null || true)
if [ -n "$hits" ]; then
  echo "❌ 發現個人資訊，已中止（本倉庫會公開）："
  echo "$hits" | head -5
  exit 1
fi
echo "  零命中 ✅"

echo ""
echo "=== 2/3 提交者身分檢查 ==="
authors=$(git log --format="%ae" | sort -u)
echo "$authors" | sed 's/^/  /'
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
  git remote set-url origin "$ARG"
else
  git remote add origin "$ARG"
fi

# ⚠️ 必須檢查 push 的退出碼：前一版沒檢查，push 失敗（代理 502）時
#    仍印出「✅ 推送完成」—— 假綠，比不印更危險。
if git push -u origin main; then
  echo ""
  echo "✅ 推送完成。"
else
  echo ""
  echo "❌ 推送失敗（見上方 git 輸出）。常見原因：網路代理擋住 git 的 HTTPS 通道。"
  exit 1
fi
