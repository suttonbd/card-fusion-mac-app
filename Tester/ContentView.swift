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
            if captureService.detectedQRCodes.isEmpty {
                Text("No QR codes detected")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 36))
            } else {
                GeometryReader { geometry in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 20) {
                            Spacer(minLength: 0)
                            ForEach(captureService.detectedQRCodes, id: \.self) { code in
                                Text(code)
                                    .font(.system(size: 36, weight: .medium))
                                    .textSelection(.enabled)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 16)
                                    .background(Color.secondary.opacity(0.1))
                                    .cornerRadius(12)
                            }
                            Spacer(minLength: 0)
                        }
                        .frame(minWidth: geometry.size.width)
                        .padding()
                    }
                }
                .frame(height: 100)
            }
        }
        .frame(minWidth: 400, minHeight: 150)
        .task {
            await captureService.startCapture()
        }
    }
}

#Preview {
    ContentView()
}
