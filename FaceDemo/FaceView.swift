import UIKit

class FaceView: UIView {

    var faceBoxes: NSMutableArray? = nil
    var frameSize: CGSize?
    
    public func setFaceBoxes(faceBoxes: NSMutableArray) {
        self.faceBoxes = faceBoxes
        setNeedsDisplay()
    }

    public func setFrameSize(frameSize: CGSize) {
        self.frameSize = frameSize
    }

    private func drawBBox(context: CGContext, rect: CGRect) {
        let lineLength: CGFloat = 60 // specify your line length
        let radius: CGFloat = 30// specify your radius

        // Draw left top corner
        context.move(to: CGPoint(x: rect.minX, y: rect.minY + lineLength))
        context.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        context.addArc(center: CGPoint(x: rect.minX + radius, y: rect.minY + radius), radius: radius, startAngle: .pi, endAngle: -.pi / 2, clockwise: false)
        context.addLine(to: CGPoint(x: rect.minX + lineLength, y: rect.minY))

        // Draw right top corner
        context.move(to: CGPoint(x: rect.maxX - lineLength, y: rect.minY))
        context.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        context.addArc(center: CGPoint(x: rect.maxX - radius, y: rect.minY + radius), radius: radius, startAngle: -.pi / 2, endAngle: 0, clockwise: false)
        context.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + lineLength))

        // Draw right bottom corner
        context.move(to: CGPoint(x: rect.maxX, y: rect.maxY - lineLength))
        context.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        context.addArc(center: CGPoint(x: rect.maxX - radius, y: rect.maxY - radius), radius: radius, startAngle: 0, endAngle: .pi / 2, clockwise: false)
        context.addLine(to: CGPoint(x: rect.maxX - lineLength, y: rect.maxY))
        
        // Draw left bottom corner
        context.move(to: CGPoint(x: rect.minX + lineLength, y: rect.maxY))
        context.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        context.addArc(center: CGPoint(x: rect.minX + radius, y: rect.maxY - radius), radius: radius, startAngle: .pi / 2, endAngle: .pi, clockwise: false)
        context.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - lineLength))
    }

    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        
        guard let context = UIGraphicsGetCurrentContext() else {
            return
        }

        let defaults = UserDefaults.standard
        let livenessThreshold = defaults.float(forKey: "liveness_threshold")

        if(self.frameSize != nil) {
            context.beginPath()

            let x_scale = self.frameSize!.width / self.bounds.width
            let y_scale = self.frameSize!.height / self.bounds.height

            for faceBox in (faceBoxes! as NSArray as! [FaceBox]) {
                var color = UIColor(named: "clr_main_button_bg1")
                var string = "REAL " + String(format: "%.3f", faceBox.liveness)
                if(faceBox.liveness < livenessThreshold) {
                    color = UIColor.red
                    string = "SPOOF " + String(format: "%.3f", faceBox.liveness)
                }
                
                context.setStrokeColor(color!.cgColor)
                context.setLineWidth(2.0)
                
                let scaledRect = CGRect(x: Int(CGFloat(faceBox.x1) / x_scale), y: Int(CGFloat(faceBox.y1) / y_scale), width: Int(CGFloat(faceBox.x2 - faceBox.x1 + 1) / x_scale), height: Int(CGFloat(faceBox.y2 - faceBox.y1 + 1) / y_scale))
                

                let attributes = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 20),
                                  NSAttributedString.Key.foregroundColor: color]
                string.draw(at: CGPoint(x: CGFloat(scaledRect.minX + 5), y: CGFloat(scaledRect.minY - 25)), withAttributes: attributes)
                drawBBox(context: context, rect: scaledRect) // Call drawBBox method
                context.strokePath()
            }
        }
    }
}
