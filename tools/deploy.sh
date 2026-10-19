#!/usr/bin/env bash
# 一鍵部署 practicepointer.org 到 Cloudflare Pages，並當場驗收。
#
# 用法：
#   tools/deploy.sh            # 同步 repo → site，部署到 production，跑驗收
#   tools/deploy.sh --no-sync  # 不同步（site/ 已是你要的內容）
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

# --- 1. 同步 ---
if [ "${1:-}" != "--no-sync" ]; then
  say "→ 同步 repo → site"
  "$ROOT/sync-to-publish.sh" >/dev/null || die "sync-to-publish.sh 失敗"
  say "  ok"
fi

[ -f "$PUB/index.html" ] || die "找不到 $PUB/index.html"

# --- 2. 憑證 ---
TOK="${CLOUDFLARE_API_TOKEN:-}"
if [ -z "$TOK" ]; then
  for f in "$HOME/.wrangler/config/default.toml" \
           "$HOME/Library/Preferences/.wrangler/config/default.toml"; do
    [ -f "$f" ] || continue
    t=$(grep -m1 '^oauth_token' "$f" 2>/dev/null | sed 's/.*= "//; s/"$//')
    [ -n "${t:-}" ] || continue
    if curl -s -m 15 "https://api.cloudflare.com/client/v4/zones?name=practicepointer.org" \
         -H "Authorization: Bearer $t" | grep -q '"success":true'; then
      TOK="$t"; say "→ 憑證來源：$f"; break
    fi
  done
fi

[ -n "$TOK" ] || die "沒有可用的 Cloudflare 憑證。先跑：
    cd $ROOT && unset CLOUDFLARE_API_TOKEN && npx --yes wrangler@4.151.1 login
  在瀏覽器按一次 Allow 後再執行本腳本。"

# --- 3. 部署 ---
say "→ 部署到 Pages（project: $PROJECT, branch: main）"
CLOUDFLARE_API_TOKEN="$TOK" CLOUDFLARE_ACCOUNT_ID="$ACCOUNT" \
  npx --yes wrangler@4.151.1 pages deploy "$PUB" \
    --project-name "$PROJECT" --branch main 2>&1 \
  | grep -vE 'WARNING|^\s*$' | tail -8
[ "${PIPESTATUS[0]}" -eq 0 ] || die "wrangler 部署失敗"

say "→ 等邊緣生效"
sleep 6

# --- 4. 驗收 ---
fail=0
chk() { # chk <描述> <期望> <curl 參數...>
  local desc="$1" want="$2"; shift 2
  local got
  got=$(curl -s -o /dev/null -w '%{http_code}' -m 25 "$@" 2>/dev/null)
  if [ "$got" = "$want" ]; then
    printf '  ✓ %-52s %s\n' "$desc" "$got"
  else
    printf '  ✗ %-52s %s（期望 %s）\n' "$desc" "${got:-ERR}" "$want"
    fail=$((fail+1))
  fi
}

say "→ 驗收"
chk "根域 /" 200 "$SITE/"
chk "/llms.txt" 200 "$SITE/llms.txt"
chk "/sitemap.xml" 200 "$SITE/sitemap.xml"
chk "/robots.txt" 200 "$SITE/robots.txt"
chk "不存在路徑應 404（不是 soft 404）" 404 "$SITE/nope-deploy-check"
chk "www → apex 301" 301 "https://www.practicepointer.org/"
chk "www/llms.txt 301（保留路徑）" 301 "https://www.practicepointer.org/llms.txt"
chk "http → https 301" 301 "http://practicepointer.org/"

# 內容與本地一致性（byte 比對）
if curl -s -m 25 "$SITE/" -o /tmp/_pp_deploy.html && cmp -s /tmp/_pp_deploy.html "$PUB/index.html"; then
  printf '  ✓ %-52s %s\n' "線上首頁與 site/index.html 逐 byte 相同" "same"
else
  printf '  ✗ %-52s\n' "線上首頁與 site/index.html 不一致"
  fail=$((fail+1))
fi

# _headers 是否生效
if curl -sI -m 20 "$SITE/" | grep -qi '^x-frame-options: DENY'; then
  printf '  ✓ %-52s\n' "_headers 生效（x-frame-options: DENY）"
else
  printf '  ✗ %-52s\n' "_headers 未生效"
  fail=$((fail+1))
fi

# 追蹤碼聲明
if curl -s -m 25 "$SITE/" | grep -qE 'cloudflareinsights|googletagmanager|gtag\(|plausible|beacon'; then
  printf '  ✗ %-52s\n' "頁面出現追蹤碼，與頁尾聲明矛盾"
  fail=$((fail+1))
else
  printf '  ✓ %-52s\n' "無追蹤碼（頁尾聲明成立）"
fi

echo
if [ "$fail" -eq 0 ]; then
  say "✅ 部署完成，全部驗收通過：$SITE"
else
  say "⚠️ 部署完成但有 $fail 項驗收未過，先別宣告成功"
  exit 1
fi
