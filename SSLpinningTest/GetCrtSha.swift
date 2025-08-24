//
//  Test4.swift
//  SSLpinningTest
//
//  Created by 褚宣德 on 2025/8/24.
//

import SwiftUI
import Foundation
import CommonCrypto
import Security
import CryptoKit

// MARK: - ViewModel
class PinningViewModel3: ObservableObject {
    @Published var inputHash: String = ""
    @Published var inputURL: String = ""
    @Published var result: String = "等待測試..."
    @Published var serverHash: String {
        didSet {
            UserDefaults.standard.set(serverHash, forKey: "serverHash")
        }
    }
    @Published var savedURL: String {
        didSet {
            UserDefaults.standard.set(savedURL, forKey: "serverURL")
        }
    }
    @Published var pinningSuccess: Bool = false
    
    init() {
        self.serverHash = UserDefaults.standard.string(forKey: "serverHash") ?? ""
        self.savedURL = UserDefaults.standard.string(forKey: "serverURL") ?? ""
        self.inputURL = self.savedURL
        self.inputHash = self.serverHash
    }
    
    func reset() {
        UserDefaults.standard.removeObject(forKey: "serverHash")
        UserDefaults.standard.removeObject(forKey: "serverURL")
        
        serverHash = ""
        savedURL = ""
        inputHash = ""
        inputURL = ""
        result = "已重置 UserDefaults"

    }
}

// MARK: - NetworkManager
class NetworkManager3: NSObject, URLSessionDelegate {
    static let shared = NetworkManager3()
    
    private var session: URLSession = createSession()
    
    private static func createSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        return URLSession(configuration: config, delegate: shared, delegateQueue: nil)
    }
    

    
    func testRequestWithPinning(completion: @escaping (Result<String, Error>) -> Void) {
        guard let savedURL = UserDefaults.standard.string(forKey: "serverURL"),
              let url = URL(string: savedURL) else {
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
    
    // MARK: - URLSessionDelegate
    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {

        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust,
              let pinnedKeyHash = UserDefaults.standard.string(forKey: "serverHash")
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

    private func sha256Base64(data: Data) -> String {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash) }
        return Data(hash).base64EncodedString()
    }
}

// MARK: - Pinning Delegate for Session
class PinningDelegate3: NSObject, URLSessionDelegate {
    let expectedHash: String
    let completion: (Bool, String) -> Void
    
    init(expectedHash: String, completion: @escaping (Bool, String) -> Void) {
        self.expectedHash = expectedHash
        self.completion = completion
    }
    
    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
        guard let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            completion(false, "無法取得 serverTrust")
            return
        }
        
        let serverCert: SecCertificate?
        if #available(iOS 15.0, *) {
            serverCert = (SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate])?.first
        } else {
            serverCert = SecTrustGetCertificateAtIndex(serverTrust, 0)
        }
        
        guard let cert = serverCert,
              let publicKey = SecCertificateCopyKey(cert),
              let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, nil) as Data? else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            completion(false, "無法取得公鑰")
            return
        }
        
        let hash = SHA256.hash(data: publicKeyData)
        let hashBase64 = Data(hash).base64EncodedString()
        
        if hashBase64 == expectedHash {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
            completion(true, hashBase64)
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            completion(false, hashBase64)
        }
    }
}

// MARK: - Detail View
struct DetailView2: View {
    let serverHash: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("伺服器公鑰 Hash:")
                .font(.headline)
            
            Text(serverHash)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .textSelection(.enabled)
                .padding()
        }
        .padding()
        .navigationTitle("Detail")
    }
}

// MARK: - Main SwiftUI View
struct GetSHAView: View {
    @StateObject private var vm = PinningViewModel3()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 15) {
                
                // URL 輸入
                TextField("輸入 API URL", text: $vm.inputURL)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                
                Button("儲存 URL") {
                    vm.savedURL = vm.inputURL
                }
                
                // 公鑰 hash 輸入
                TextField("輸入公鑰 SHA256 Base64", text: $vm.inputHash)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                
                Button("儲存 Hash") {
                    vm.serverHash = vm.inputHash
                }
                
                // 測試 Pinning
                Button("測試 Pinning") {
                    testPinning(expectedHash: vm.inputHash)
                }
                .padding(.vertical)
                
                // 顯示結果
                TextEditor(text: $vm.result)
                    .foregroundColor(vm.pinningSuccess ? .green : .red)
                    .frame(height: 120)
                    .textSelection(.enabled)
                    .border(Color.gray.opacity(0.5))
                
                HStack {
                    Spacer()
                    Button(action: {
                        UIPasteboard.general.string = vm.serverHash
                    }) {
                        Image(systemName: "doc.on.doc")
                        Text("複製 Hash")
                    }
                    .disabled(vm.serverHash.isEmpty)
                }
                .padding(.horizontal)
                
                // 🔴 重置
                Button(action: {
                    vm.reset()
                }) {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text("重置")
                    }
                }
                .foregroundColor(.red)
                
            }
            .padding()

        }
    }
    
    func testPinning(expectedHash: String) {
        guard let urlString = UserDefaults.standard.string(forKey: "serverURL"),
              let url = URL(string: urlString) else { return }
        
        let session = URLSession(configuration: .default,
                                 delegate: PinningDelegate3(expectedHash: expectedHash) { success, serverHash in
            DispatchQueue.main.async {
                vm.serverHash = serverHash
                vm.pinningSuccess = success
                vm.result = success ? "✅ Pinning 成功！伺服器公鑰 hash = \(serverHash)"
                                    : "❌ Pinning 失敗！伺服器回傳的 hash = \(serverHash)"
            }
        }, delegateQueue: nil)
        
        session.dataTask(with: url).resume()
    }
}



#Preview {
    GetSHAView()
}
