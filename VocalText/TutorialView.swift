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
            title: NSLocalizedString("tutorial.step1.title", comment: ""),
            description: NSLocalizedString("tutorial.step1.description", comment: ""),
            imageName: nil,
            contentImageName: "waveform"
        ),
        TutorialStep(
            title: NSLocalizedString("tutorial.step2.title", comment: ""),
            description: NSLocalizedString("tutorial.step2.description", comment: ""),
            imageName: nil,
            contentImageName: "mic.circle.fill"
        ),
        TutorialStep(
            title: NSLocalizedString("tutorial.step3.title", comment: ""),
            description: NSLocalizedString("tutorial.step3.description", comment: ""),
            imageName: nil,
            contentImageName: "text.alignleft"
        ),
        TutorialStep(
            title: NSLocalizedString("tutorial.step4.title", comment: ""),
            description: NSLocalizedString("tutorial.step4.description", comment: ""),
            imageName: nil,
            contentImageName: "gear"
        ),
        TutorialStep(
            title: NSLocalizedString("tutorial.step5.title", comment: ""),
            description: NSLocalizedString("tutorial.step5.description", comment: ""),
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
                    Button("tutorial.previous.button") {
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
                    Button("tutorial.start.using.button") {
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
                    Button("tutorial.next.button") {
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
