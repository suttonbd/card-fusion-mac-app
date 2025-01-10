//
//  ContentView.swift
//  Tester
//
//  Created by Brian Sutton on 1/9/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var captureService = ScreenCaptureService()
    
    var body: some View {
        VStack {
            Spacer()
            
            if captureService.detectedQRCodes.isEmpty {
                Text("No QR codes detected")
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(captureService.detectedQRCodes, id: \.self) { code in
                            Text(code)
                                .textSelection(.enabled)
                                .padding()
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                    .padding()
                }
                .frame(maxHeight: 200)
            }
        }
        .frame(minWidth: 400, minHeight: 300)
        .task {
            await captureService.startCapture()
        }
    }
}

#Preview {
    ContentView()
}
