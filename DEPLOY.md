# 部署記錄 — practicepointer.org

> 上線時間：2026-10-19 02:07 HKT（2026-10-18 18:07 UTC）
> 狀態：**已上線，HTTPS 正常**

## 識別碼（下次不必再查）

| 項目 | 值 |
| --- | --- |
| Cloudflare 帳號 | `c2088e34e4974c8a4cdd2d6655e2530a`（帳號郵箱**不記錄於本檔案**——本倉庫會公開） |
| Zone ID | `c2e3f454843e341fe2b6940c7009dd5f` |
| Pages 專案 | `practicepointer`（production branch `main`） |
| 生產網址 | <https://practicepointer.org> |
| Pages 備用網址 | <https://practicepointer.pages.dev> |
| 本次部署 hash | `fc4d74b2.practicepointer.pages.dev` |
| DNS 記錄 | CNAME `practicepointer.org` → `practicepointer.pages.dev`，Proxied，id `de28f722a46deb5ecf3198a3e35928cc` |
| 憑證 | Google Trust Services WE1，CN=`practicepointer.org`，到期 2027-01-16（自動續） |

## 實際做了什麼

1. `wrangler login`（OAuth）→ 帳號郵箱**不記錄於本檔案**（本倉庫會公開）
2. `wrangler pages project create practicepointer --production-branch main`
3. `wrangler pages deploy site --project-name practicepointer --branch main`
   - 非互動 shell 必須把 OAuth token 當 `CLOUDFLARE_API_TOKEN` 傳入，否則 deploy 拒絕
4. Pages custom domain 綁 `practicepointer.org`（API）
5. 頂域 CNAME（apex flattening，Proxied）— 用一次性 scoped token（Zone.DNS:Edit）建立，用完即刪
6. 等 Pages 簽發憑證（約 3 分鐘）→ `status: active`

## 驗證結果（curl 實測，非 dashboard）

| 檢查 | 結果 |
| --- | --- |
| 解析（DoH） | `172.67.134.225` / `104.21.25.233` ✅ |
| `https://practicepointer.org/` | HTTP/2 200，60,521 bytes，與本地 `site/index.html` 逐 byte 相同 ✅ |
| `_headers` 是否生效 | `x-frame-options: DENY`、`x-content-type-options: nosniff`、`permissions-policy`、`referrer-policy` 全在 ✅ |
| HTTP → HTTPS | 301 ✅（Pages 自帶） |
| 憑證 | Google Trust Services，網域匹配 ✅ |
| `/sitemap.xml` `/robots.txt` `/llms.txt` | 200 且與本地一致 ✅ |
| 追蹤碼 | 線上 HTML 0 命中（`cloudflareinsights`／`gtag`／`beacon` 全無），頁尾聲明成立 ✅ |
| canonical | `https://practicepointer.org/` ✅ |

## GitHub 倉庫（2026-10-19 已建）

| 項目 | 值 |
| --- | --- |
| 網址 | <https://github.com/leonlinhk-bot/practicepointer> |
| 可見性 | Public |
| Issues | 開（糾錯入口靠它）；wiki / projects 關（公開倉庫的灌水面） |
| topics | hong-kong, insurance, compliance, insurance-agents, open-source, cantonese, financial-literacy |

> ⚠️ **GitHub 建組織的 API 已廢除**（`POST /organizations` 回 404），只能到網頁建。
> 所以倉庫落在帳號下而非 `practicepointer` 組織；站上連結已用 `tools/set-repo.sh` 全部改掉。

> ⚠️ **這台機器上 `github.com` 走 git 協定不通**：代理只放行 `api.github.com`，
> 直連 github.com:443 逾時。`git push` 一律失敗（502 / 連線逾時）。
> 因此改用 **GitHub Git Data API** 推送（`tools/` 之外的 `/tmp/push_via_api.py` 思路）：
> 逐 commit 建 blob → tree → commit，再用 PATCH 更新 ref。
> 好處是作者、時間、message 全部保留，連 commit sha 都與本地一致。

---

## 尚未處理 / 待決

- **`www.practicepointer.org` 做了一半**：
  - ✅ Pages 已把 `www.practicepointer.org` 設為自訂網域（狀態 `initializing`）
  - ✅ `_redirects`（www → apex 301）已隨部署上傳，線上 `/_redirects` 200
  - ❌ **DNS 那筆 CNAME 加不上去** —— OAuth token 打 `POST /zones/{id}/dns_records` 回 **403 Authentication error**
    （這支 token 有 Pages 寫入權，沒有 DNS 寫入權）
  - 待辦：開一支含 `Zone → DNS:Edit` 的 scoped token，加 `CNAME www → practicepointer.pages.dev`（開 Proxy），
    Pages 那筆自訂網域才會從 `initializing` 轉 `active`
- **ICANN 電郵驗證**：RDAP 無 `clientHold`，NS 仍是 `jose/rihana.ns.cloudflare.com` 且正常解析，
  未見 suspension。但驗證信是否已點，API 查不到（OAuth 無 registrar 權限），需本人到信箱確認。
- **GitHub 自動部署**：遠端 repo 已建，但本機 `git push` 走不通（見上）。
  要接自動部署，需在**能連 github.com 的環境**推送一次，或到 Pages 專案用 **Connect to Git**
  直接授權 GitHub（不用經過本機網路）。
- **`practicepointer.hk`**：仍延後未註冊（HKIRC 無 RDAP）。

## 日後部署命令

```bash
cd ~/WorkBuddy/2026-10-15-11-31-42
TOK=$(grep -m1 '^oauth_token' ~/Library/Preferences/.wrangler/config/default.toml | sed 's/.*= "//; s/"$//')
CLOUDFLARE_API_TOKEN="$TOK" CLOUDFLARE_ACCOUNT_ID=c2088e34e4974c8a4cdd2d6655e2530a \
  npx --yes wrangler@4.151.1 pages deploy site --project-name practicepointer --branch main
```

OAuth token 會過期（約 30 天）。過期時重跑 `npx wrangler login`，用戶在瀏覽器按一次 Allow 即可。
憑證檔位置會隨 wrangler 版本變：舊版在 `~/Library/Preferences/.wrangler/config/default.toml`，
4.151 實測寫在 `~/.wrangler/config/default.toml` —— 讀之前兩個都看一眼，讀錯會拿到已輪替的舊 token（表現為 `Invalid API Token`）。

---

## 誰負責什麼（2026-10-19 定案）

| 事項 | 負責 |
| --- | --- |
| 內容（文案、條文、頁面結構） | WorkBuddy |
| 部署、域名、DNS、憑證、驗收 | Hermes（本機 agent） |

**部署一律走 `tools/deploy.sh`**，不要手敲 wrangler 命令：

```bash
cd ~/WorkBuddy/2026-10-15-11-31-42/repo
./tools/deploy.sh              # 同步 repo → site + 部署 production + 當場驗收
./tools/deploy.sh --no-sync    # site/ 已是你要的內容時
```

腳本會做四件事，缺一件都會讓線上出問題：

1. **同步 `repo/` → `site/`**（`sync-to-publish.sh`）。不能直接丟 `repo/`，會把 `.git`（含提交者姓名電郵）一起上傳。
2. **解析憑證**：依序找 `CLOUDFLARE_API_TOKEN`、`~/.wrangler/config/default.toml`、`~/Library/Preferences/.wrangler/config/default.toml`，並實測能不能碰到 `practicepointer.org` 這個 zone；讀到輪替的舊 token 會自動跳過。
3. **部署**：非互動 shell 必須把 token 傳成 `CLOUDFLARE_API_TOKEN`，否則 wrangler 直接拒絕（`pages project create` 成功不代表 `pages deploy` 能跑）。
4. **驗收 9 項**：`/`、`/llms.txt`、`/sitemap.xml`、`/robots.txt` 皆 200；不存在路徑必須 **404**（不是 200 首頁）；`www` 301 且保留路徑；`http` 301；線上首頁與 `site/index.html` **逐 byte 相同**；`_headers` 生效；頁面無追蹤碼。任一項不過就 exit 1，不許宣告成功。

憑證過期時腳本會直接告訴你重跑 `npx --yes wrangler@4.151.1 login`，在瀏覽器按一次 Allow 即可。

### 交接給內容方（WorkBuddy）

- 改內容：只改 `repo/` 裡的 `index.html` / `llms.txt` / `robots.txt` / `sitemap.xml`，然後通知 Hermes 部署；或自己跑上面那條命令。
- **不要**動 `_worker.js`（www→apex 301）、`_headers`（安全標頭）、`404.html`（沒有它 Pages 會退回 SPA，全站變 soft 404）、`CNAME`。
- 不要新增 `_redirects` 做跨主機轉址 —— Pages 只匹配路徑，寫主機名不生效。
- 域名側（Registrar、DNS、憑證、ICANN 驗證）由 Hermes 管，WorkBuddy 不需要碰。

---

## 2026-10-19 12:20 修復：www 301 與全站 soft 404

### 問題一：`www` 沒有 301，與根域內容完全重複

`_redirects` 裡那條 `https://www.practicepointer.org/*  https://practicepointer.org/:splat  301`
**在 Pages 不會生效**：Pages 的 `_redirects` 只匹配**路徑**，來源寫主機名等於註解。
`www` 早在 02:49 就被加進 Pages 自訂域，所以 522 是暫時狀態，真正問題是它直接回 200 首頁。

修法：`_worker.js`（Pages Functions 進階模式）在主機層做 301。選它而非 zone 層 Redirect Rule，
是因為手上只有 Pages 權限（OAuth 無 zone 寫入）。日後若加了 Redirect Rule，這支 worker 可直接刪。

```js
if (url.hostname === "www.practicepointer.org") { url.hostname = "practicepointer.org"; return Response.redirect(url.toString(), 301); }
return env.ASSETS.fetch(request);
```

### 問題二：全站 soft 404（任何路徑都回 200 首頁）

**根因在 Cloudflare 的預設行為，不是設定被改壞**：官方文件明寫「若專案沒有頂層 `404.html`，
Pages 就當你是 SPA，任何對不到靜態資產的路徑都回根目錄」。所以 `/nope`、`/a/b/c.css`、`/favicon.ico`
全部 200 + 首頁 —— 對搜尋引擎是壞信號。

修法：加一個頂層 `404.html`（本站自製版，無外部資源、`noindex`），立刻恢復真 404。

### 本次驗證（curl + 第三方 vantage 雙通道）

| 檢查 | 結果 |
| --- | --- |
| `www.practicepointer.org/` | 301 → `https://practicepointer.org/` |
| `www/llms.txt` | 301 → `https://practicepointer.org/llms.txt`（路徑保留） |
| `www/a/b?x=1&y=2` | 301 → 保留路徑與 query |
| `practicepointer.org/` `/llms.txt` `/sitemap.xml` `/robots.txt` | 200，大小正確 |
| `/nope-xyz-123`、`/favicon.ico` | **404** + 自製 404 頁（3,557 bytes） |
| `_headers` | 200 與 404 回應都套用（DENY / nosniff / permissions-policy / referrer-policy） |
| `www` 憑證 | Google Trust Services WE1，CN=www.practicepointer.org，到期 2027-01-17 |
| 追蹤碼 | 首頁與 404 頁均無 script／外部資源 |

> 本機代理會干擾驗證：`dig` 直接超時、`openssl s_client` 拉不到 PEM。判斷「是否真的 200/404」
> 要用 curl 看狀態碼，必要時用第三方 vantage（`api.hackertarget.com/httpheaders/?q=<url>`）交叉確認；
> 但先確認代理不是在騙你 —— 拿 `https://example.com/nope` 應得 404 當對照組。

### 部署目錄的最終形態

`site/`（＝部署來源，`repo/` 同名檔案保持同步）：

```
404.html  _headers  _worker.js  index.html
llms.txt  robots.txt  sitemap.xml  CNAME  .nojekyll
```

已刪 `_redirects`（主機名規則無效，留著只會誤導下一個人）。
