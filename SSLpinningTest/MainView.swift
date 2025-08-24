//
//  MainView.swift
//  SSLpinningTest
//
//  Created by 褚宣德 on 2025/8/24.
//

import SwiftUI

struct MainView: View {
    var body: some View {
        TabView {


            ContentView()
                .tabItem {
                    Label("Pinning Test", systemImage: "pin.circle.fill")
                }
            
            GetSHAView()
                .tabItem {
                    Label("Get SHA", systemImage: "text.cursor.zh")
                }
            
        }
        
        
    }
}

#Preview {
    MainView()
}
