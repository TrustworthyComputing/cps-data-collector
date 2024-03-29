
import Foundation
import SwiftUI

struct WaveView: Shape {
    @Binding var phase: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let step = 10
        let frequency: CGFloat = 1 / 100
        let amplitude: CGFloat = 20
        
        path.move(to: CGPoint(x: 0, y: rect.height / 2))
        
        for x in stride(from: 0, to: Int(rect.width) + step, by: step) {
            let y = rect.height / 2 + amplitude * sin(frequency * CGFloat(x) + phase)
            path.addLine(to: CGPoint(x: CGFloat(x), y: y))
        }
        
        return path
    }
}
