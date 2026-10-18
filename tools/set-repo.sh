#!/bin/zsh
# 更換全站 GitHub 倉庫路徑
#
# 為什麼要有這支腳本：站上有 3 處「提交糾錯」按鈕、README / CONTRIBUTING
# 也會引用倉庫網址。手改一定會漏，漏一處就是一個死鏈。
#
# 用法：./tools/set-repo.sh <owner>/<repo>
#   例：./tools/set-repo.sh leonlinhk-bot/practicepointer
# 不帶參數時只做校驗，不改動任何檔案。
#
# ⚠️ 為什麼要印「改前 / 改後」兩個數字並做斷言：
#   前一版只印改前的數字，曾出現「實際改了但報 0 處」的不一致。
#   一個會撒謊的計數器比沒有計數器更危險 —— 所以現在改成可驗證：
#   改後舊路徑必須為 0、新路徑數量必須等於改前數量，否則 exit 1。

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE/.."

OLD="practicepointer/practicepointer"
TARGET="${1:-}"
# ⚠️ 這裡必須列全。前一版漏了 .github/ISSUE_TEMPLATE/config.yml，
#    結果它裡面的舊路徑沒被換掉，而殘留檢查又只掃這五個檔案 ——
#    於是報「✅ 全部統一，無殘留」，實際上漏了一處。這是假綠。
FILES=(index.html README.md CONTRIBUTING.md llms.txt DEPLOY.md
       .github/ISSUE_TEMPLATE/config.yml)

# 固定字串計數（路徑裡有 . 和 /，用 -F 避免被當成正則）
cnt() {
  [ -f "$2" ] || { echo 0; return; }
  grep -oF -- "$1" "$2" 2>/dev/null | wc -l | tr -d ' '
}

echo "目前設定的舊路徑：$OLD"
if [ -z "$TARGET" ]; then
  echo "（未提供參數，僅校驗不改動）"
else
  echo "目標路徑：$TARGET"
fi
echo ""

fail=0
for f in "${FILES[@]}"; do
  [ -f "$f" ] || continue
  before=$(cnt "$OLD" "$f")
  if [ -n "$TARGET" ] && [ "$before" -gt 0 ]; then
    /usr/bin/sed -i '' "s|$OLD|$TARGET|g" "$f"
    after_old=$(cnt "$OLD" "$f")
    after_new=$(cnt "$TARGET" "$f")
    if [ "$after_old" -ne 0 ] || [ "$after_new" -ne "$before" ]; then
      printf "  ❌ %-16s 改前 %s → 改後(舊 %s / 新 %s) 不符，請人工檢查\n" \
             "$f" "$before" "$after_old" "$after_new"
      fail=1
    else
      printf "  ✅ %-16s %s 處 → 舊 %s / 新 %s\n" "$f" "$before" "$after_old" "$after_new"
    fi
  else
    printf "  —  %-16s 改前 %s 處（未改動）\n" "$f" "$before"
  fi
done

echo ""
# 反查：是否還有「其他」GitHub 倉庫路徑殘留
# ⚠️ 範圍是「所有已追蹤檔案」，不是上面那個 FILES 清單 ——
#    清單是人手維護的，一定會漏；掃全部才不會出現「報全綠但其實漏了」。
others=$(git ls-files | tr '\n' '\0' \
         | xargs -0 grep -rhoE 'github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+' 2>/dev/null \
         | sort -u || true)
if [ -n "$TARGET" ] && [ -n "$others" ]; then
  leftover=$(echo "$others" | grep -vF "github.com/$TARGET" || true)
  if [ -n "$leftover" ]; then
    echo "⚠️  殘留其他倉庫路徑："
    echo "$leftover" | sed 's/^/     /'
    fail=1
  else
    echo "✅ 全部統一為 github.com/$TARGET，無殘留"
  fi
else
  echo "檔案中出現的 GitHub 路徑："
  echo "${others:-（無）}" | sed 's/^/     /'
fi

exit $fail
