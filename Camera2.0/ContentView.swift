//
//import SwiftUI
//import AVFoundation
//
//// MARK: - COLOR DEFINITIONS
//
//struct PieceColorRange {
//    let name: String
//    let displayColor: Color
//    let hueMin: CGFloat
//    let hueMax: CGFloat
//    let satMin: CGFloat
//    let satMax: CGFloat
//    let briMin: CGFloat
//    let briMax: CGFloat
//}
//
//let pentominoColors: [PieceColorRange] = [
//    PieceColorRange(name:"F", displayColor:.blue, hueMin:190, hueMax:255, satMin:0.35, satMax:1.0, briMin:0.20, briMax:1.0),
//    PieceColorRange(name:"I", displayColor:Color(red:0.3, green:0.8, blue:1.0), hueMin:175, hueMax:190, satMin:0.20, satMax:1.0, briMin:0.50, briMax:1.0),
//    PieceColorRange(name:"L", displayColor:.yellow, hueMin:45, hueMax:75, satMin:0.40, satMax:1.0, briMin:0.40, briMax:1.0),
//    PieceColorRange(name:"P", displayColor:Color(red:0.5, green:0.9, blue:0.1), hueMin:75, hueMax:95, satMin:0.45, satMax:1.0, briMin:0.40, briMax:1.0),
//    PieceColorRange(name:"T", displayColor:Color(red:0.6, green:0.2, blue:0.8), hueMin:255, hueMax:310, satMin:0.30, satMax:1.0, briMin:0.25, briMax:1.0),
//    PieceColorRange(name:"U", displayColor:Color(red:1.0, green:0.4, blue:0.7), hueMin:310, hueMax:345, satMin:0.25, satMax:1.0, briMin:0.40, briMax:1.0),
////    PieceColorRange(name:"V", displayColor:.red, hueMin:0, hueMax:15, satMin:0.40, satMax:1.0, briMin:0.25, briMax:1.0),
//    PieceColorRange(name:"V", displayColor:.red, hueMin:345, hueMax:360, satMin:0.40, satMax:1.0, briMin:0.25, briMax:1.0),
//    PieceColorRange(name:"W", displayColor:.orange, hueMin:25, hueMax:45, satMin:0.45, satMax:1.0, briMin:0.30, briMax:1.0),
//    PieceColorRange(name:"X", displayColor:.teal, hueMin:155, hueMax:175, satMin:0.35, satMax:1.0, briMin:0.20, briMax:1.0),
//    PieceColorRange(name:"Z", displayColor:.green, hueMin:95, hueMax:155, satMin:0.30, satMax:1.0, briMin:0.20, briMax:1.0),
//]
//
//// MARK: - AUTO-SCAN ENGINE
//
//struct CameraView: View {
//    @State private var detectedPieces: [DetectedPiece] = []
//    @State private var isScanning = false // Visual feedback for auto-detection
//    
//    private let gridCols = 12
//    private let gridRows = 16
//
//    var body: some View {
//        ZStack {
//            MultiZoneCameraPreview(
//                gridCols: gridCols,
//                gridRows: gridRows,
//                onZoneColors: handleZoneColors
//            )
//            .ignoresSafeArea()
//
//            // Visual 'Scanning' Indicator
//            if isScanning {
//                VStack {
//                    HStack {
//                        Circle().fill(.green).frame(width: 8, height: 8)
//                        Text("AUTO-SCAN ACTIVE").font(.caption.monospaced()).foregroundColor(.green)
//                    }
//                    .padding(8).background(Capsule().fill(Color.black.opacity(0.6)))
//                    Spacer()
//                }.padding(.top, 50)
//            }
//
//            GeometryReader { geo in
//                ForEach(detectedPieces) { piece in
//                    PieceLabelView(piece: piece)
//                        .position(
//                            x: (1.0 - piece.normX) * geo.size.width,
//                            y: piece.normY * geo.size.height - 40
//                        )
//                }
//            }
//            .ignoresSafeArea()
//            .animation(.spring(), value: detectedPieces.count)
//        }
//    }
//
//    private func handleZoneColors(_ zones: [(col: Int, row: Int, normX: CGFloat, normY: CGFloat, hue: CGFloat, sat: CGFloat, bri: CGFloat)]) {
//        var matched: [String: (color: Color, normX: CGFloat, normY: CGFloat, count: Int)] = [:]
//        
//        for zone in zones {
//            // Only match if the area is colorful enough to be a piece (Sat > 0.2)
//            if zone.sat < 0.2 || zone.bri < 0.2 { continue }
//            
//            if let m = matchPentomino(hue: zone.hue, sat: zone.sat, bri: zone.bri) {
//                let existing = matched[m.name] ?? (color: m.color, normX: 0, normY: 0, count: 0)
//                matched[m.name] = (color: m.color, normX: existing.normX + zone.normX, normY: existing.normY + zone.normY, count: existing.count + 1)
//            }
//        }
//
//        // Logic: Only "Scan" if a piece occupies at least 3 grid zones (avoids noise)
//        let filteredMatches = matched.filter { $0.value.count >= 3 }
//        
//        let updated = filteredMatches.map { (name, val) -> DetectedPiece in
//            let prev = detectedPieces.first(where: { $0.name == name })
//            return DetectedPiece(id: name, name: name, color: val.color, normX: val.normX / CGFloat(val.count), normY: val.normY / CGFloat(val.count), stableFrames: (prev?.stableFrames ?? 0) + 1)
//        }
//
//        DispatchQueue.main.async {
//            self.isScanning = !updated.isEmpty
//            self.detectedPieces = updated
//        }
//    }
//
//    func matchPentomino(hue: CGFloat, sat: CGFloat, bri: CGFloat) -> (name: String, color: Color)? {
//        for r in pentominoColors {
//            if hue >= (r.hueMin - 4) && hue <= (r.hueMax + 4) && sat >= (r.satMin - 0.05) && bri >= (r.briMin - 0.05) {
//                return (r.name, r.displayColor)
//            }
//        }
//        return nil
//    }
//}
//
//// MARK: - HELPERS & MODELS
//
//struct DetectedPiece: Identifiable {
//    let id: String
//    let name: String
//    let color: Color
//    let normX: CGFloat
//    let normY: CGFloat
//    var stableFrames: Int
//}
//
//struct PieceLabelView: View {
//    let piece: DetectedPiece
//    var body: some View {
//        VStack(spacing: 4) {
//            Text(piece.name).font(.system(size: 24, weight: .black, design: .monospaced)).foregroundColor(.white)
//            Circle().fill(piece.color).frame(width: 12, height: 12)
//        }
//        .padding(12).background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.7)))
//    }
//}
//
//// MARK: - CAMERA PREVIEW (IPAD ORIENTATION FIXED)
//
//struct MultiZoneCameraPreview: UIViewRepresentable {
//    let gridCols: Int
//    let gridRows: Int
//    var onZoneColors: ([(col: Int, row: Int, normX: CGFloat, normY: CGFloat, hue: CGFloat, sat: CGFloat, bri: CGFloat)]) -> Void
//
//    func makeCoordinator() -> Coordinator { Coordinator(self) }
//    func makeUIView(context: Context) -> PreviewUIView {
//        let v = PreviewUIView()
//        context.coordinator.setup(in: v)
//        return v
//    }
//    func updateUIView(_ uiView: PreviewUIView, context: Context) {
//        context.coordinator.updateOrientation()
//    }
//
//    final class Coordinator: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
//        let parent: MultiZoneCameraPreview
//        let session = AVCaptureSession()
//        var previewLayer: AVCaptureVideoPreviewLayer?
//        var videoOutput: AVCaptureVideoDataOutput?
//
//        init(_ parent: MultiZoneCameraPreview) { self.parent = parent }
//
//        func setup(in view: UIView) {
//            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
//                  let input = try? AVCaptureDeviceInput(device: device) else { return }
//
//            session.beginConfiguration()
//            if session.canAddInput(input) { session.addInput(input) }
//            let out = AVCaptureVideoDataOutput()
//            out.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
//            out.setSampleBufferDelegate(self, queue: DispatchQueue(label: "camera.queue"))
//            if session.canAddOutput(out) { session.addOutput(out); videoOutput = out }
//            session.commitConfiguration()
//
//            let pl = AVCaptureVideoPreviewLayer(session: session)
//            pl.videoGravity = .resizeAspectFill
//            view.layer.addSublayer(pl)
//            previewLayer = pl
//            
//            updateOrientation()
//            DispatchQueue.global(qos: .userInitiated).async { self.session.startRunning() }
//        }
//
//        func updateOrientation() {
//            guard let connection = previewLayer?.connection else { return }
//            let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene
//            let orientation = scene?.interfaceOrientation ?? .portrait
//            let videoOrientation: AVCaptureVideoOrientation
//            switch orientation {
//            case .landscapeLeft: videoOrientation = .landscapeLeft
//            case .landscapeRight: videoOrientation = .landscapeRight
//            case .portraitUpsideDown: videoOrientation = .portraitUpsideDown
//            default: videoOrientation = .portrait
//            }
//            if connection.isVideoOrientationSupported { connection.videoOrientation = videoOrientation }
//            if let outputConnection = videoOutput?.connection(with: .video), outputConnection.isVideoOrientationSupported {
//                outputConnection.videoOrientation = videoOrientation
//            }
//        }
//
//        func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
//            guard let ib = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
//            CVPixelBufferLockBaseAddress(ib, .readOnly)
//            let W = CVPixelBufferGetWidth(ib), H = CVPixelBufferGetHeight(ib), bpr = CVPixelBufferGetBytesPerRow(ib)
//            guard let base = CVPixelBufferGetBaseAddress(ib) else { CVPixelBufferUnlockBaseAddress(ib, .readOnly); return }
//            let buf = base.assumingMemoryBound(to: UInt8.self)
//
//            let zoneW = W / parent.gridCols, zoneH = H / parent.gridRows
//            var results: [(col: Int, row: Int, normX: CGFloat, normY: CGFloat, hue: CGFloat, sat: CGFloat, bri: CGFloat)] = []
//
//            for row in 0..<parent.gridRows {
//                for col in 0..<parent.gridCols {
//                    let cx = zoneW * col + zoneW / 2
//                    let cy = zoneH * row + zoneH / 2
//                    let o = cy * bpr + cx * 4
//                    let b_val = CGFloat(buf[o]) / 255.0
//                    let g_val = CGFloat(buf[o+1]) / 255.0
//                    let r_val = CGFloat(buf[o+2]) / 255.0
//                    var h: CGFloat=0, s: CGFloat=0, b: CGFloat=0
//                    UIColor(red: r_val, green: g_val, blue: b_val, alpha: 1).getHue(&h, saturation: &s, brightness: &b, alpha: nil)
//                    results.append((col: col, row: row, normX: CGFloat(cx)/CGFloat(W), normY: CGFloat(cy)/CGFloat(H), hue: h*360, sat: s, bri: b))
//                }
//            }
//            CVPixelBufferUnlockBaseAddress(ib, .readOnly)
//            parent.onZoneColors(results)
//        }
//    }
//}
//
//class PreviewUIView: UIView {
//    override func layoutSubviews() {
//        super.layoutSubviews()
//        layer.sublayers?.forEach { $0.frame = bounds }
//    }
//}
