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

## 尚未處理 / 待決

- **`www.practicepointer.org` 目前 NXDOMAIN**（未設記錄）。若要支援，需在 Dashboard 加 CNAME；
  **但正確做法是 301 到 apex**，而 Redirect Rules 需要 zone 寫入權限，本次的 scoped token 沒有。
  現階段刻意不加，避免出現兩個內容完全相同的站。
- **ICANN 電郵驗證**：RDAP 無 `clientHold`，NS 仍是 `jose/rihana.ns.cloudflare.com` 且正常解析，
  未見 suspension。但驗證信是否已點，API 查不到（OAuth 無 registrar 權限），需本人到信箱確認。
- **GitHub 自動部署**：repo 目前**沒有 remote**（只有本地兩次提交）。要接 GitHub 需先建遠端 repo，
  再到 Pages 專案 Connect to Git。
- **`practicepointer.hk`**：仍延後未註冊（HKIRC 無 RDAP）。

## 日後部署命令

```bash
cd ~/WorkBuddy/2026-10-15-11-31-42
TOK=$(grep -m1 '^oauth_token' ~/Library/Preferences/.wrangler/config/default.toml | sed 's/.*= "//; s/"$//')
CLOUDFLARE_API_TOKEN="$TOK" CLOUDFLARE_ACCOUNT_ID=c2088e34e4974c8a4cdd2d6655e2530a \
  npx --yes wrangler@4.151.1 pages deploy site --project-name practicepointer --branch main
```

OAuth token 會過期（約 30 天）。過期時重跑 `npx wrangler login`，用戶在瀏覽器按一次 Allow 即可。
