//
//  NetworkManager.swift
//  SSLpinningTest
//
//  Created by 褚宣德 on 2025/8/23.
//

import Foundation
import CommonCrypto
import Security

class NetworkManager: NSObject {
    static let shared = NetworkManager()
    
    // 移除原本硬編碼 pinnedKeyHash
    private var pinnedKeyHash: String? {
        return UserDefaults.standard.string(forKey: "serverHash")
    }
//    let pinnedKeyHash = "0Zq6CDwp4AsvEFmsBa16VnG47HllRmzjK1nB4C+tSys="
    
    private var user_url: String? {
        return UserDefaults.standard.string(forKey: "serverURL")
    }
    
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()
    
    // 無 Pinning
    func testRequestNoPinning(completion: @escaping (Result<String, Error>) -> Void) {
        
        guard let url = URL(string: user_url!) else {
            completion(.failure(NSError(domain: "Invalid URL", code: 0)))
            return
        }
        let task = URLSession(configuration: .ephemeral).dataTask(with: url) { data, _, error in
            if let error = error { completion(.failure(error)); return }
            if let data = data, let text = String(data: data, encoding: .utf8) {
                completion(.success(text))
            } else {
                completion(.failure(NSError(domain: "No data", code: 0)))
            }
        }
        task.resume()
    }
    
    // 有 Pinning
    func testRequestWithPinning(completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: user_url!) else {
            completion(.failure(NSError(domain: "Invalid URL", code: 0)))
            return
        }
        let task = session.dataTask(with: url) { data, _, error in
            if let error = error { completion(.failure(error)); return }
            if let data = data, let text = String(data: data, encoding: .utf8) {
                completion(.success(text))
            } else {
                completion(.failure(NSError(domain: "No data", code: 0)))
            }
        }
        task.resume()
    }
}

// MARK: - URLSessionDelegate
extension NetworkManager: URLSessionDelegate {
    
    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {

        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust
        else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        var certificateChain: [SecCertificate] = []

        if #available(iOS 15.0, *) {
            certificateChain = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate] ?? []
        } else {
            let count = SecTrustGetCertificateCount(serverTrust)
            certificateChain = (0..<count).compactMap { SecTrustGetCertificateAtIndex(serverTrust, $0) }
        }

        guard let serverCertificate = certificateChain.first,
              let serverPublicKey = SecCertificateCopyKey(serverCertificate),
              let serverPublicKeyData = SecKeyCopyExternalRepresentation(serverPublicKey, nil) as Data?
        else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        let keyHash = sha256Base64(data: serverPublicKeyData)

        if keyHash == pinnedKeyHash {
            print("✅ 公鑰 Pinning 驗證成功")
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            print("❌ 公鑰 Pinning 驗證失敗")
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }

    // Helper function
    func sha256Base64(data: Data) -> String {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash) }
        return Data(hash).base64EncodedString()
    }



}

extension SecTrust {
    @available(iOS 13.0, *)
    func evaluateWithError() -> Bool {
        return SecTrustEvaluateWithError(self, nil)
    }
}

