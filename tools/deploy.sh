#!/usr/bin/env bash
# 一鍵部署 practicepointer.org 到 Cloudflare Pages，並當場驗收。
#
# 用法：
#   tools/deploy.sh            # 同步 repo → site，部署 production，跑部署方自檢
#   tools/deploy.sh --no-sync  # 不同步（site/ 已是你要的內容）
#   tools/deploy.sh --force    # 明知 site/ 有手改痕跡也要覆蓋
#
# 分工（2026-10-19 定案）：
#   repo/     唯一編輯源，內容方只改這裡
#   site/     生成物，由 sync-to-publish.sh 從 repo/ 覆蓋產生，任何人不得手改
#   本腳本    只做部署 + 部署方自檢；線上獨立複驗由內容方做（只讀，不算部署）
#
# 憑證：用 wrangler 的 OAuth token（pages:write 就夠）。
#   過期時會提示重跑 `npx wrangler login`，你在瀏覽器按一次 Allow 即可。
#   也可以先 export CLOUDFLARE_API_TOKEN=... 用一支 scoped token 覆蓋。
#
# 為什麼要有這支腳本：部署有三個容易漏的步驟 ——
#   1) repo/ → site/ 同步（漏了等於部署舊內容；且不能直接丟 repo，會把 .git 帶上去）
#   2) 非互動 shell 必須把 token 傳成 CLOUDFLARE_API_TOKEN，否則 wrangler 直接拒絕
#   3) 部署後要驗證 www 301 與 404 行為，不能只看「Deployment complete」
#
# 若之後在 Cloudflare 加了 zone 層 Redirect Rule（www → apex），
# 可刪掉 site/_worker.js，本腳本不用改。

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
PUB="$ROOT/../site"
PROJECT="practicepointer"
ACCOUNT="c2088e34e4974c8a4cdd2d6655e2530a"
SITE="https://practicepointer.org"

say() { printf '%s\n' "$*"; }
die() { printf '✗ %s\n' "$*" >&2; exit 1; }

# --- 0. 參數 ---
SYNC=1; FORCE=0; PUSH=1
for a in "$@"; do
  case "$a" in
    --no-sync) SYNC=0 ;;
    --no-push) PUSH=0 ;;
    --force)   FORCE=1 ;;
    *) echo "未知參數：$a" >&2; exit 1 ;;
  esac
done

FILES=(index.html llms.txt robots.txt sitemap.xml 404.html _worker.js _headers CNAME .nojekyll)

# --- 0b. 發佈目錄守衛（註釋不能當守衛用，這裡要真的擋）---
[ -d "$PUB" ] || die "找不到 $PUB"
[ -d "$PUB/.git" ] && die "site/ 裡有 .git，會把提交者姓名與電郵一起公開上傳"
stray=$(find "$PUB" -maxdepth 2 \( -name '.git*' -o -name '*.md' -o -name 'tools' -o -name '.workbuddy*' \) 2>/dev/null)
[ -n "$stray" ] && die "site/ 裡有非部署檔案：
$stray"
[ -f "$PUB/index.html" ] || die "找不到 $PUB/index.html"

# --- 1. 同步（先偵測 site/ 手改，避免靜默覆蓋內容方的活）---
if [ "$SYNC" -eq 1 ]; then
  drift=""
  for f in "${FILES[@]}"; do
    [ -f "$PUB/$f" ] || continue
    cmp -s "$ROOT/$f" "$PUB/$f" && continue
    [ "$PUB/$f" -nt "$ROOT/$f" ] && drift="$drift $f"
  done
  if [ -n "$drift" ] && [ "$FORCE" -eq 0 ]; then
    die "site/ 有比 repo/ 新的內容，疑似手改：$drift
   唯一編輯源是 repo/。若確認要覆蓋，用 --force。"
  fi
  [ -n "$drift" ] && say "⚠ 覆蓋 site/ 的手改內容：${drift}（--force）"

  say "→ 同步 repo → site"
  "$ROOT/sync-to-publish.sh" >/dev/null || die "sync-to-publish.sh 失敗"
  say "  ok"
fi

# --- 1b. 提交快照（部署前落地，推送留到驗收全綠之後）---
GITN="${GIT_AUTHOR_NAME:-Leon Liang}"
GITE="${GIT_AUTHOR_EMAIL:-leonl.inhk@gmail.com}"
if [ -n "$(git -C "$ROOT" status --porcelain 2>/dev/null)" ]; then
  files=$(git -C "$ROOT" status --porcelain | awk '{print $NF}' | tr '\n' ' ')
  git -C "$ROOT" add -A >/dev/null 2>&1
  git -C "$ROOT" -c user.name="$GITN" -c user.email="$GITE" \
    commit -q -m "deploy: $(date '+%Y-%m-%d %H:%M') — ${files:0:120}" \
    && say "→ 已提交快照：${files:0:90}"
else
  say "→ 工作區乾淨，部署既有提交 $(git -C "$ROOT" rev-parse --short HEAD)"
fi

# --- 2. 憑證（每個候選都實測，不採信「存在即有效」）---
# 實測點用 pages/projects/<project>：這是部署真正要打的端點，能讀到就代表 token
# 對這個專案有效。只查 /zones 會放過「zone 可讀但 Pages 無權」的 token。
api_ok() {
  # 注意：Cloudflare 這個端點回的是「美化過的」JSON（`"success": true` 有空格），
  # 用 grep '"success":true' 會全部判成失敗 —— 老實解析 JSON。
  curl -s -m 20 "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT/pages/projects/$PROJECT" \
    -H "Authorization: Bearer $1" 2>/dev/null \
  | python3 -c 'import sys,json;sys.exit(0 if json.load(sys.stdin).get("success") else 1)' 2>/dev/null
}

TOK=""
# ① 專案 scoped token（首選：無到期，不受 OAuth 回調問題影響）
if [ -s "$HOME/.cf-token-pp" ]; then
  t=$(cat "$HOME/.cf-token-pp")
  if api_ok "$t"; then TOK="$t"; say "→ 憑證來源：~/.cf-token-pp"
  else say "⚠ ~/.cf-token-pp 的 token 碰不到 ${PROJECT}，跳過"; fi
fi

# ② 環境變數（可能被其它專案的 token 佔用，必須實測再採用）
if [ -z "$TOK" ] && [ -n "${CLOUDFLARE_API_TOKEN:-}" ]; then
  if api_ok "$CLOUDFLARE_API_TOKEN"; then TOK="$CLOUDFLARE_API_TOKEN"; say "→ 憑證來源：環境變數 CLOUDFLARE_API_TOKEN"
  else say "⚠ 環境變數 CLOUDFLARE_API_TOKEN 碰不到 ${PROJECT}，跳過"; fi
fi

# ③ wrangler OAuth
if [ -z "$TOK" ]; then
  for f in "$HOME/.wrangler/config/default.toml" \
           "$HOME/Library/Preferences/.wrangler/config/default.toml"; do
    [ -f "$f" ] || continue
    t=$(grep -m1 '^oauth_token' "$f" 2>/dev/null | sed 's/.*= "//; s/"$//')
    [ -n "${t:-}" ] || continue
    if api_ok "$t"; then TOK="$t"; say "→ 憑證來源：$f"; break
    else say "⚠ $f 的 token 已失效或無權，跳過"; fi
  done
fi

[ -n "$TOK" ] || die "沒有可用的 Cloudflare 憑證（三個來源都試過且都失敗）。
   · 首選：建一支 Account → Cloudflare Pages → Edit、TTL 留空的 token，存到 ~/.cf-token-pp
   · 或：cd $ROOT && unset CLOUDFLARE_API_TOKEN && npx --yes wrangler@4.151.1 login（本機 OAuth 不可靠）"

# --- 3. 部署 ---
say "→ 部署到 Pages（project: $PROJECT, branch: main）"
CLOUDFLARE_API_TOKEN="$TOK" CLOUDFLARE_ACCOUNT_ID="$ACCOUNT" \
  npx --yes wrangler@4.151.1 pages deploy "$PUB" \
    --project-name "$PROJECT" --branch main 2>&1 \
  | grep -vE 'WARNING|^\s*$' | tail -8
[ "${PIPESTATUS[0]}" -eq 0 ] || die "wrangler 部署失敗"

say "→ 等邊緣生效"
sleep 6

# --- 4. 部署方自檢（失敗重試；連線層錯誤記「未驗證」，不當站點故障）---
fail=0; envfail=0
ok()  { printf '  ✓ %s\n' "$1"; }
bad() { printf '  ✗ %s（期望 %s，得到 %s）\n' "$1" "$2" "$3"; fail=$((fail+1)); }
unk() { printf '  ⚠ %s —— 本機代理連不上，未驗證（非站點問題）\n' "$1"; envfail=$((envfail+1)); }

chk() { # chk <描述> <期望狀態> <curl 參數...>
  local desc="$1" want="$2"; shift 2
  local got="" i
  for i in 1 2 3; do
    got=$(curl -s -o /dev/null -w '%{http_code}' -m 20 "$@" 2>/dev/null); got=${got:-000}
    [ "$got" = "$want" ] && { ok "$desc → $got"; return; }
    case "$got" in 000|502|522|504) sleep 3 ;; *) break ;; esac
  done
  case "$got" in 000|502|522|504) unk "$desc" ;; *) bad "$desc" "$want" "$got" ;; esac
}

say "→ 自檢"
chk "根域 /" 200 "$SITE/"
chk "/llms.txt" 200 "$SITE/llms.txt"
chk "/sitemap.xml" 200 "$SITE/sitemap.xml"
chk "/robots.txt" 200 "$SITE/robots.txt"
chk "不存在路徑應 404（不是 soft 404）" 404 "$SITE/nope-deploy-check"
chk "www → apex 301" 301 "https://www.practicepointer.org/"
chk "www/llms.txt 301（保留路徑）" 301 "https://www.practicepointer.org/llms.txt"
chk "http → https 301" 301 "http://practicepointer.org/"

# 內容逐 byte 比對
if curl -s -m 25 "$SITE/" -o /tmp/_pp_deploy.html 2>/dev/null && [ -s /tmp/_pp_deploy.html ]; then
  if cmp -s /tmp/_pp_deploy.html "$PUB/index.html"; then ok "線上首頁與 site/index.html 逐 byte 相同"
  else bad "線上首頁與 site/index.html 不一致" "same" "diff"; fi
else
  unk "線上首頁內容比對"
fi

# _headers
if h=$(curl -sI -m 20 "$SITE/" 2>/dev/null) && [ -n "$h" ]; then
  if printf '%s' "$h" | grep -qi '^x-frame-options: DENY'; then ok "_headers 生效（x-frame-options: DENY）"
  else bad "_headers 未生效" "x-frame-options: DENY" "缺失"; fi
else
  unk "_headers 檢查"
fi

# 追蹤碼聲明
if body=$(curl -s -m 25 "$SITE/" 2>/dev/null) && [ -n "$body" ]; then
  if printf '%s' "$body" | grep -qE 'cloudflareinsights|googletagmanager|gtag\(|plausible|beacon'; then
    bad "頁面出現追蹤碼，與頁尾聲明矛盾" "0 命中" "有命中"
  else ok "無追蹤碼（頁尾聲明成立）"; fi
else
  unk "追蹤碼掃描"
fi

echo
if [ "$fail" -eq 0 ] && [ "$envfail" -eq 0 ]; then
  say "✅ 部署方自檢全綠：$SITE"
  say "   （線上獨立複驗由內容方做：只讀，不算部署）"

  # 推送：唯一值得推的時刻就是「程式碼 = 線上 = 已驗證」這三者重合的現在
  if [ "$PUSH" -eq 1 ]; then
    if GIT_TERMINAL_PROMPT=0 git -C "$ROOT" push origin HEAD:main >/tmp/_pp_push.log 2>&1; then
      say "→ 已推送 origin/main：$(git -C "$ROOT" rev-parse --short HEAD)"
    else
      say "⚠ 推送失敗（部署已成功，不影響線上）："
      sed 's/^/   /' /tmp/_pp_push.log | tail -4
      say "   處理：cd $ROOT && git push origin HEAD:main"
    fi
  else
    say "→ 略過推送（--no-push）"
  fi
elif [ "$fail" -eq 0 ]; then
  say "⚠️ 部署完成，但有 $envfail 項因本機代理無法驗證 —— 不宣告成功，也不宣告失敗。"
  say "   換通道或請內容方複驗這幾項。"
  exit 2
else
  say "❌ 部署完成但有 $fail 項真失敗（另有 $envfail 項無法驗證），先別宣告成功"
  exit 1
fi
