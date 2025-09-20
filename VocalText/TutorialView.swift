//
//  TutorialView.swift
//  VocalText
//
//  Created by LEEJAYMC on 16/9/2025.
//

import SwiftUI

struct TutorialStep {
    let title: String
    let description: String
    let imageName: String?
    let contentImageName: String?
}

struct TutorialView: View {
    @Binding var isPresented: Bool
    @State private var currentStep = 0
    @State private var isAnimating = false
    var onTutorialCompleted: (() -> Void)? = nil
    
    let steps = [
        TutorialStep(
            title: "歡迎使用 VocalText",
            description: "VocalText 是一款語音轉文字工具，可以將您的語音即時轉換為文字。",
            imageName: nil,
            contentImageName: "waveform"
        ),
        TutorialStep(
            title: "開始錄音",
            description: "點擊咪高峰按鈕開始錄音。錄音時，您會看到即時的音頻波形顯示。",
            imageName: nil,
            contentImageName: "mic.circle.fill"
        ),
        TutorialStep(
            title: "查看轉錄結果",
            description: "錄音結束後，VocalText 會自動將語音轉換為文字並顯示在螢幕上。您可以點擊文字複製到剪貼簿。",
            imageName: nil,
            contentImageName: "text.alignleft"
        ),
        TutorialStep(
            title: "設定和自訂",
            description: "點擊設定按鈕可以更改識別模型、選擇音頻輸入裝置和設定識別語言。",
            imageName: nil,
            contentImageName: "gear"
        ),
        TutorialStep(
            title: "準備開始使用",
            description: "現在您已經了解了基本功能，可以開始使用 VocalText 了。祝您使用愉快！",
            imageName: nil,
            contentImageName: "checkmark.circle.fill"
        )
    ]
    
    var body: some View {
        VStack(spacing: 20) {
            // 标题
            Text(steps[currentStep].title)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .padding(.top, 30)
                .padding(.horizontal, 20)
            
            // 描述
            Text(steps[currentStep].description)
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .frame(maxWidth: 300)
            
            // 图标或图像
            if let imageName = steps[currentStep].imageName {
                Image(imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 200, height: 150)
                    .padding()
            } else if let contentImageName = steps[currentStep].contentImageName {
                Image(systemName: contentImageName)
                    .font(.system(size: 50))
                    .foregroundColor(.blue)
                    .padding()
            }
            
            Spacer()
            
            // 步骤指示器
            HStack {
                ForEach(0..<steps.count, id: \.self) { index in
                    Circle()
                        .fill(currentStep == index ? Color.blue : Color.gray)
                        .frame(width: 10, height: 10)
                }
            }
            
            // 按钮
            HStack {
                if currentStep == 0 {
                    Spacer()
                } else {
                    Button("上一步") {
                        withAnimation {
                            currentStep -= 1
                        }
                    }
                    .padding(8)
                    .foregroundColor(.gray)
                    .cornerRadius(6)
                }
                
                Spacer()
                
                if currentStep == steps.count - 1 {
                    Button("開始使用") {
                        // 保存教程已完成的状态
                        UserDefaults.standard.set(true, forKey: "HasCompletedTutorial")
                        // 调用完成回调（请求麦克风权限）
                        onTutorialCompleted?()
                        isPresented = false
                    }
                    .padding(8)
                    .foregroundColor(.blue)
                    .cornerRadius(6)
                } else {
                    Button("下一步") {
                        withAnimation {
                            currentStep += 1
                        }
                    }
                    .padding(8)
                    .foregroundColor(.blue)
                    .cornerRadius(6)
                }
            }
            .padding(.bottom, 20)
        }
        .frame(width: 400, height: 300)
    }
}

#Preview {
    TutorialView(isPresented: .constant(true))
}

#Preview {
  TutorialView(isPresented: .constant(true))
 }
