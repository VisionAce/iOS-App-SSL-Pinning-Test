//
//  SSLPinning.swift
//  SSLpinningTest
//
//  Created by 褚宣德 on 2025/8/23.
//

import Foundation
import CommonCrypto
import Security

// MARK: - 公鑰 Pinning Delegate
class PublicKeyPinningDelegate: NSObject, URLSessionDelegate {
    // 公鑰 SHA256 Base64（需確認與實際抓取的一致）
//    let pinnedPublicKeyHash = "0Zq6CDwp4AsvEFmsBa16VnG47HllRmzjK1nB4C+tSys="
    
    private var pinnedPublicKeyHash: String? {
        return UserDefaults.standard.string(forKey: "serverHash")
    }

    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {

        guard let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // iOS 15+ 使用新 API 取得憑證鏈
        let certChain = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate] ?? []
        guard let leafCert = certChain.first,
              let serverPublicKey = SecCertificateCopyKey(leafCert),
              let serverPublicKeyData = SecKeyCopyExternalRepresentation(serverPublicKey, nil) as Data? else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // 計算 SHA256 hash
        let hashBase64 = sha256(data: serverPublicKeyData).base64EncodedString()

        if hashBase64 == pinnedPublicKeyHash {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
        
        print("Server Public Key Hash:", hashBase64)
    }

    private func sha256(data: Data) -> Data {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash) }
        return Data(hash)
    }
}
