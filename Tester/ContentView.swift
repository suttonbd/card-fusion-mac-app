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
                            ForEach(captureService.userOrderedCodes, id: \.self) { code in
                                ZStack(alignment: .topTrailing) {
                                    Text(code)
                                        .font(.system(size: 36, weight: .medium))
                                        .padding(.horizontal, 24)
                                        .padding(.vertical, 16)
                                        .background(Color.secondary.opacity(0.1))
                                        .cornerRadius(12)
                                    
                                    // Badge - use position from original detected order
                                    Text("\(captureService.detectedQRCodes.firstIndex(of: code)! + 1)")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(8)
                                        .background(Circle().fill(Color.blue))
                                        .offset(x: -10, y: -10)
                                }
                                .contentShape(Rectangle())
                                .onDrag {
                                    NSItemProvider(object: code as NSString)
                                }
                                .onDrop(of: [.text], delegate: DropViewDelegate(
                                    items: captureService.userOrderedCodes,
                                    currentIndex: captureService.userOrderedCodes.firstIndex(of: code)!,
                                    reorderHandler: captureService.reorderCodes
                                ))
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

struct DropViewDelegate: DropDelegate {
    let items: [String]
    let currentIndex: Int
    let reorderHandler: (Int, Int) -> Void
    
    func performDrop(info: DropInfo) -> Bool {
        return true
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
    
    func dropEntered(info: DropInfo) {
        guard let draggedItem = info.itemProviders(for: [.text]).first else { return }
        
        draggedItem.loadObject(ofClass: NSString.self) { (string, _) in
            guard let draggedText = string as? String,
                  let fromIndex = items.firstIndex(of: draggedText) else { return }
            
            if fromIndex != currentIndex {
                DispatchQueue.main.async {
                    let toIndex = currentIndex > fromIndex ? currentIndex + 1 : currentIndex
                    reorderHandler(fromIndex, toIndex)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
