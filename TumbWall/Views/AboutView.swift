import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                .resizable()
                .frame(width: 128, height: 128)
            
            VStack(spacing: 8) {
                Text("TumbWall")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Version 1.1")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 8) {
                Text("Created by")
                    .font(.body)
                
                Link("Jorge Sánchez", destination: URL(string: "https://jsanchez.me")!)
                    .font(.headline)
                    .foregroundColor(.blue)
            }
            .padding(.top, 10)
            
            Spacer()
            
            Text("© 2026 Jorge Sánchez. All rights reserved.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(40)
        .frame(width: 400, height: 350)
    }
}

#Preview {
    AboutView()
}
