# App Certificate Pinning 實作指南

## 📌 什麼是 Certificate Pinning?
Certificate Pinning（憑證釘選）是一種防止中間人攻擊 (MITM) 的安全技術。  
App 在連線伺服器時，不僅會驗證伺服器是否使用可信憑證，還會檢查憑證是否與 App 內部綁定的憑證或公鑰相符。  
若不相符，即使攻擊者安裝了惡意的 CA 憑證，也無法成功攔截通訊。

---

## ⚙️ Pinning 實作方式
常見的 Pinning 方式：
1. **憑證 Pinning (Certificate Pinning)**  
   App 內部存放伺服器憑證 (`server.crt`)，驗證伺服器憑證是否完全一致。
2. **公鑰 Pinning (Public Key Pinning)**  
   App 內部存放伺服器憑證的公鑰 (例如 `SHA256` 雜湊)，只要伺服器憑證對應的公鑰一致即可。


| 方案                | 說明                                                                 | 優點                                                                 | 缺點                                                                 |
|---------------------|----------------------------------------------------------------------|----------------------------------------------------------------------|----------------------------------------------------------------------|
| **綁整張憑證**       | 在 App 內預先儲存伺服器憑證，連線時比對完整憑證內容（Subject、序號、效期…）。 | 實作簡單，安全性高（僅允許完全相同的憑證）。                         | 伺服器憑證一更新（即使同一公鑰重新簽發），App 也必須更新並重新發布。 |
| **綁公鑰（Public Key Pinning）** | 在 App 內預先儲存伺服器的公鑰（或雜湊值），只要伺服器憑證對應的公鑰相同即可通過驗證。 | 較有彈性，憑證到期更換時，只要公鑰不變，App 無需更新。               | 若伺服器公鑰變更，App 必須更新；比對邏輯較綁憑證複雜。               |
| **綁 CA 憑證**       | 在 App 內儲存 Root CA 或中繼 CA 憑證，只允許該 CA 發出的憑證被接受。          | 可隨憑證週期自動更新，只要同一 CA 發行即可通過。                     | 安全性較低（CA 領域太大，CA 發給其他網域的憑證也會被信任，增加攻擊面）。 |

---


## 🔑 iOS (Swift) 實作範例
[採用公鑰Pinning][6]

---

# iOS 與 Android 憑證綁定 (Certificate Pinning) 公鑰 SHA-256

在 iOS 和 Android 上做憑證綁定（Certificate Pinning）時，通常會使用 **公鑰的 SHA-256 值**（即 SPKI 雜湊）來驗證伺服器憑證。

---

## iOS (App Transport Security / Trust Evaluation)
- **推薦雜湊方式**：SHA-256
- **操作流程**：
  1. 從伺服器憑證擷取 **公鑰 (SPKI)**。
  2. 將公鑰轉換成 **DER 編碼格式**。
  3. 計算 **SHA-256 雜湊值**。
  4. 將結果與 App 中硬編碼或下載的公鑰 hash 比對。
- **官方文件**：
  - [Apple Security - Certificate, Key, and Trust Services][3]

---

## Android (Network Security Config / Certificate Pinning)
- **推薦雜湊方式**：SHA-256
- **操作流程**：
  1. 從伺服器憑證擷取 **Subject Public Key Info (SPKI)**。
  2. 計算 **SHA-256 雜湊值**。
  3. 將結果與 `network_security_config.xml` 中 `<pin digest="SHA-256">` 設定的值比對。
- **官方文件**：
  - [Android Developers - Network security configuration][5] 

---

## 官方統一建議
兩平台都建議使用 **SHA-256 的 SPKI 雜湊**，而非 SHA-1 或 MD5。

**算法流程**：
SPKI → DER Encode → SHA-256 → Base64



---

# CSR、CA、CRT 差異與重點

- **CSR (Certificate Signing Request，憑證簽署請求)**
  - 由伺服器端產生，內含公開金鑰與申請者資訊  
  - 用來向 CA 申請憑證，**不含私鑰**

- **CA (Certificate Authority，憑證頒發單位)**
  - 負責驗證申請者身份並簽發憑證  
  - 可以是公開 CA（如 DigiCert、Let’s Encrypt）或自建 CA  

- **CRT (Certificate，憑證檔案)**
  - CA 根據 CSR 簽發的憑證檔案  
  - 內含公開金鑰、簽章與有效期限，用於伺服器或用戶端驗證  
  - 格式常見為 `.crt` 或 `.cer`

## 重點
1. CSR 是「申請檔」，CRT 是「核發結果」  
2. CA 是「見證人」，確保憑證可信  
3. 私鑰永不出現在 CSR、CRT，需妥善保管在伺服器  

---

# 備用金鑰來源概念

備用金鑰不是隨便生成的，它通常是提前生成、未來要部署到伺服器的新公私鑰對。  
它的作用是讓 App 在伺服器憑證更新或金鑰輪替時，仍能順利驗證連線。

💡備用金鑰是「未來會用的金鑰」，事先放入 App 的 pin 列表，確保伺服器憑證換掉也能連線。  
**主金鑰 + 備用金鑰 = 平滑輪替 + 高安全性**

## (A) 預生成伺服器新金鑰（推薦方式）

- 企業 / 伺服器管理員提前生成一組未來要用的 TLS 金鑰對
- 現在伺服器使用「主金鑰」對外提供服務
- 將備用公鑰 hash 事先放入 App 的 pin 列表
- 當主金鑰到期或需要換憑證時：
  - 新憑證用備用金鑰簽署
  - App 已經有備用金鑰，所以驗證仍然成功
  - 過渡期間主金鑰與備用金鑰都可用
  - 完成輪替後，舊金鑰可從 App 移除
- **優點**：安全、可控、無需動態更新 App

## (B) 由中繼憑證 / CA 金鑰衍生（次佳方式）

- 部分企業會 pin Intermediate CA 公鑰
- 中繼 CA 可簽署多個伺服器憑證
- 如果伺服器更新憑證但仍使用同一中繼 CA，App 驗證仍通過
- 可視為「備用金鑰」的一種來源
- **優點**：不需要每次換伺服器憑證都更新 App  
- **缺點**：安全性略低，若中繼 CA 被盜或更換，pin 驗證會失敗或降低安全

## (C) 動態更新（非推薦，但可做補充）

- App 啟動時從可信服務端 API 下載備用金鑰 hash
- 適合極長生命周期 App 或憑證更新頻繁的場景
- **風險**：API 本身需要保護，如果被攻擊者控制，就可能導致 MITM

---

## 備用金鑰實務建議

1. **主要來源**：預生成未來伺服器金鑰，部署到 App pin 列表  
2. **次要來源**：中繼憑證公鑰，作為兼顧維護性的備援  
3. **盡量避免**：動態下載備用金鑰（增加攻擊面）  
4. **備用金鑰數量**：一般 1~2 個，太多會增加管理負擔  

---

# 萬用憑證（Wildcard Certificate）

## 萬用憑證之特性
- **通配符覆蓋**：可用 `*.example.com` 的形式，保護主網域下所有子網域（如 `api.example.com`、`mail.example.com`）。  
- **便利性高**：只需管理一張憑證即可，減少多子域環境中憑證安裝與維護的複雜度。  
- **成本效益**：相較為每個子網域購買獨立憑證，萬用憑證更具成本效益。  
- **安全風險**：一旦萬用憑證私鑰外洩，將導致所有子網域受影響，風險面擴大。  

---

## 萬用憑證之較佳實務
- **限制使用範圍**：僅用於必要的子網域，不要在內部/低敏感環境與高敏感系統混用。
  
- **憑證釘選（Pinning）注意事項**：  
  - 不建議對萬用憑證直接做憑證釘選，因為子網域服務可能更換或新增，導致應用程式失效。  
  - 若需要 Pinning，建議改用 **公鑰釘選（Public Key Pinning / SPKI Pinning）**，確保未來憑證更新仍能正常使用。  

- **考慮替代方案**：  
  - 對於高安全需求環境，優先使用 **單一網域憑證** 或 **SAN 憑證**，避免萬用憑證單點失效風險。  

---

## 📸 YouTube iOS Demo

[![IMAGE ALT TEXT HERE](https://img.youtube.com/vi/mB-pgi_MyRM/0.jpg)](https://www.youtube.com/watch?v=mB-pgi_MyRM)





## 參考連結
- [Android][1]
- [iOS][2]
- [Flutter][4]

[1]: https://developer.android.com/privacy-and-security/security-ssl?hl=zh-tw
[2]: https://developer.apple.com/news/?id=g9ejcf8y
[3]: https://developer.apple.com/documentation/security/certificate-key-and-trust-services
[4]: https://dwirandyh.medium.com/securing-your-flutter-app-by-adding-ssl-pinning-474722e38518
[5]: https://developer.android.com/training/articles/security-config#CertificatePinning
[6]: https://github.com/VisionAce/iOS-App-SSL-Pinning-Test/blob/01fb16203a0f96e2f6d298d2535c3b86cdb27850/SSLpinningTest/NetworkManager.swift#L48-L124
