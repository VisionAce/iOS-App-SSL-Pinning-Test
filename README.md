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


## 📸 YouTube iOSS Demo

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
