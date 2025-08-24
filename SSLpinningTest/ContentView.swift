//
//  ContentView.swift
//  SSLpinningTest
//
//  Created by 褚宣德 on 2025/8/23.
//

import SwiftUI



struct ContentView: View {
    @State private var statusNoPinning: String = "尚未連線"
    @State private var statusPinning: String = "尚未連線"

    var body: some View {
        VStack(spacing: 30) {
            Text("HTTPS 測試")
                .font(.title2)
                .bold()

            VStack(spacing: 10) {
                Text("✅ 無 Pinning")
                    .bold()
                ScrollView {
                    Text(statusNoPinning)
                        .foregroundColor(statusNoPinning.contains("成功") ? .green : .red)
                        .multilineTextAlignment(.center)
                }
                
                Button("發送請求 (無 Pinning)") {
                    NetworkManager.shared.testRequestNoPinning { result in
                        DispatchQueue.main.async {
                            switch result {
                            case .success(let text):
                                statusNoPinning = "✅ 成功：\(text)"
                            case .failure(let error):
                                statusNoPinning = "❌ 錯誤：\(error.localizedDescription)"
                            }
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
            }

            VStack(spacing: 10) {
                Text("🔒 有 Pinning")
                    .bold()
                ScrollView {
                    Text(statusPinning)
                        .foregroundColor(statusPinning.contains("成功") ? .green : .red)
                        .multilineTextAlignment(.center)
                }

                Button("發送請求 (有 Pinning)") {
                    NetworkManager.shared.testRequestWithPinning { result in
                        DispatchQueue.main.async {
                            switch result {
                            case .success(let text):
                                statusPinning = "✅ 成功：\(text)"
                            case .failure(let error):
                                statusPinning = "❌ 錯誤：\(error.localizedDescription)"
                            }
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
}


#Preview {
    ContentView()
}
