import SwiftUI
import AVFoundation
import CoreImage

// MARK: - PIECE COLOR DEFINITIONS
struct PieceColorRange {
    let name: String
    let uiColor: Color
    let hueMin: CGFloat
    let hueMax: CGFloat
    let satMin: CGFloat
    let briMin: CGFloat
}

let pieceColors: [PieceColorRange] = [
    PieceColorRange(name: "T", uiColor: Color(red: 0.6, green: 0.2, blue: 0.8), hueMin: 270, hueMax: 310, satMin: 0.4, briMin: 0.3),
    PieceColorRange(name: "V", uiColor: .red, hueMin: 0, hueMax: 15, satMin: 0.5, briMin: 0.3),
    PieceColorRange(name: "V_wrap", uiColor: .red, hueMin: 345, hueMax: 360, satMin: 0.5, briMin: 0.3),
    PieceColorRange(name: "U", uiColor: .pink, hueMin: 310, hueMax: 345, satMin: 0.25, briMin: 0.5),
    PieceColorRange(name: "F", uiColor: .blue, hueMin: 200, hueMax: 250, satMin: 0.4, briMin: 0.2),
    PieceColorRange(name: "X", uiColor: .teal, hueMin: 165, hueMax: 200, satMin: 0.4, briMin: 0.2),
    PieceColorRange(name: "W", uiColor: .orange, hueMin: 20, hueMax: 45, satMin: 0.5, briMin: 0.3),
    PieceColorRange(name: "L", uiColor: .yellow, hueMin: 45, hueMax: 75, satMin: 0.4, briMin: 0.4),
    PieceColorRange(name: "Z", uiColor: .green, hueMin: 90, hueMax: 165, satMin: 0.3, briMin: 0.2),
]

func matchPieceColor(hue: CGFloat, sat: CGFloat, bri: CGFloat) -> (name: String, color: Color)? {
    for range in pieceColors {
        if hue >= range.hueMin && hue <= range.hueMax && sat >= range.satMin && bri >= range.briMin {
            let name = range.name == "V_wrap" ? "V" : range.name
            return (name, range.uiColor)
        }
    }
    return nil
}

// MARK: - MAIN VIEW
struct CameraView: View {
    @State private var detectedPiece: String = "Scanning..."
    @State private var detectedColor: Color = .white
    @State private var isLocked = false
    @State private var stableFrames = 0
    @State private var lastPiece = ""

    var body: some View {
        ZStack {
            CameraPreview(onColor: { hue, sat, bri in
                handleColor(hue: hue, sat: sat, bri: bri)
            })
            .ignoresSafeArea()

            GeometryReader { geo in
                let size = min(geo.size.width, geo.size.height) * 0.65
                let cx = geo.size.width / 2
                let cy = geo.size.height / 2
                let half = size / 2
                let cLen: CGFloat = 36
                let lw: CGFloat = 4

                ZStack {
                    Rectangle()
                        .fill(Color.black.opacity(0.45))
                        .mask(
                            ZStack {
                                Rectangle()
                                Rectangle()
                                    .frame(width: size, height: size)
                                    .position(x: cx, y: cy)
                                    .blendMode(.destinationOut)
                            }
                            .compositingGroup()
                        )

                    // Corner Brackets
                    Group {
                        Path { p in
                            p.move(to: CGPoint(x: cx - half, y: cy - half + cLen))
                            p.addLine(to: CGPoint(x: cx - half, y: cy - half))
                            p.addLine(to: CGPoint(x: cx - half + cLen, y: cy - half))
                        }.stroke(isLocked ? detectedColor : Color.white, lineWidth: lw)

                        Path { p in
                            p.move(to: CGPoint(x: cx + half - cLen, y: cy - half))
                            p.addLine(to: CGPoint(x: cx + half, y: cy - half))
                            p.addLine(to: CGPoint(x: cx + half, y: cy - half + cLen))
                        }.stroke(isLocked ? detectedColor : Color.white, lineWidth: lw)

                        Path { p in
                            p.move(to: CGPoint(x: cx - half, y: cy + half - cLen))
                            p.addLine(to: CGPoint(x: cx - half, y: cy + half))
                            p.addLine(to: CGPoint(x: cx - half + cLen, y: cy + half))
                        }.stroke(isLocked ? detectedColor : Color.white, lineWidth: lw)

                        Path { p in
                            p.move(to: CGPoint(x: cx + half - cLen, y: cy + half))
                            p.addLine(to: CGPoint(x: cx + half, y: cy + half))
                            p.addLine(to: CGPoint(x: cx + half, y: cy + half - cLen))
                        }.stroke(isLocked ? detectedColor : Color.white, lineWidth: lw)
                    }

                    Path { p in
                        p.move(to: CGPoint(x: cx - 12, y: cy))
                        p.addLine(to: CGPoint(x: cx + 12, y: cy))
                        p.move(to: CGPoint(x: cx, y: cy - 12))
                        p.addLine(to: CGPoint(x: cx, y: cy + 12))
                    }.stroke(Color.white.opacity(0.5), lineWidth: 1.5)

                    Text("POINT AT PIECE")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.75))
                        .position(x: cx, y: cy - half - 14)
                }
            }

            if detectedPiece != "Scanning..." {
                VStack {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(detectedColor)
                            .frame(width: 16, height: 16)
                            .shadow(color: detectedColor.opacity(0.8), radius: 6)

                        Text("PIECE  \(detectedPiece)")
                            .font(.system(size: 28, weight: .black, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.black.opacity(0.75))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(isLocked ? detectedColor : Color.white.opacity(0.2), lineWidth: 2)
                            )
                    )

                    if isLocked {
                        Text("✓ LOCKED")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(detectedColor)
                            .padding(.top, 4)
                    }
                }
                .padding(.top, 60)
                .frame(maxHeight: .infinity, alignment: .top)
            }
        }
    }

    private func handleColor(hue: CGFloat, sat: CGFloat, bri: CGFloat) {
        let result = matchPieceColor(hue: hue, sat: sat, bri: bri)
        let newPiece = result?.name ?? "Unknown"

        DispatchQueue.main.async {
            if newPiece == self.lastPiece && newPiece != "Unknown" {
                self.stableFrames += 1
            } else {
                self.stableFrames = 0
            }
            self.lastPiece = newPiece

            if newPiece == "Unknown" {
                self.detectedPiece = "Scanning..."
                self.detectedColor = .white
                self.isLocked = false
            } else {
                self.detectedPiece = newPiece
                self.detectedColor = result?.color ?? .white
                self.isLocked = self.stableFrames > 12
            }
        }
    }
}

// MARK: - CAMERA PREVIEW
struct CameraPreview: UIViewRepresentable {
    var onColor: (CGFloat, CGFloat, CGFloat) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onColor: onColor)
    }

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.coordinator = context.coordinator
        context.coordinator.setupCamera(in: view)
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) { }

    final class Coordinator: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
        var onColor: (CGFloat, CGFloat, CGFloat) -> Void
        let session = AVCaptureSession()
        var previewLayer: AVCaptureVideoPreviewLayer?
        var videoOutput: AVCaptureVideoDataOutput?
        private var frameCount = 0

        init(onColor: @escaping (CGFloat, CGFloat, CGFloat) -> Void) {
            self.onColor = onColor
        }

        func setupCamera(in view: UIView) {
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
                  let input = try? AVCaptureDeviceInput(device: device) else { return }

            session.beginConfiguration()
            session.sessionPreset = .medium

            if session.canAddInput(input) { session.addInput(input) }

            let output = AVCaptureVideoDataOutput()
            output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "camera.queue", qos: .userInitiated))

            if session.canAddOutput(output) {
                session.addOutput(output)
                self.videoOutput = output
            }
            
            session.commitConfiguration()

            let preview = AVCaptureVideoPreviewLayer(session: session)
            preview.videoGravity = .resizeAspectFill
            view.layer.addSublayer(preview)
            self.previewLayer = preview

            DispatchQueue.global(qos: .userInitiated).async {
                self.session.startRunning()
            }
        }

        func updateOrientation() {
            guard let previewLayer = previewLayer else { return }
            
            let deviceOrientation = UIDevice.current.orientation
            let videoOrientation: AVCaptureVideoOrientation
            
            switch deviceOrientation {
            case .portrait: videoOrientation = .portrait
            case .landscapeLeft: videoOrientation = .landscapeRight
            case .landscapeRight: videoOrientation = .landscapeLeft
            case .portraitUpsideDown: videoOrientation = .portraitUpsideDown
            default: return
            }

            // 1. Update Preview visuals
            if previewLayer.connection?.isVideoOrientationSupported == true {
                previewLayer.connection?.videoOrientation = videoOrientation
            }

            // 2. Update Data output buffer orientation
            if let outputConnection = videoOutput?.connection(with: .video),
               outputConnection.isVideoOrientationSupported {
                outputConnection.videoOrientation = videoOrientation
            }
        }

        func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
            frameCount += 1
            guard frameCount % 3 == 0 else { return }
            guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

            CVPixelBufferLockBaseAddress(imageBuffer, .readOnly)
            defer { CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly) }

            let width = CVPixelBufferGetWidth(imageBuffer)
            let height = CVPixelBufferGetHeight(imageBuffer)
            let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer)
            guard let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer) else { return }
            
            let buffer = baseAddress.assumingMemoryBound(to: UInt8.self)

            let sampleSize = 20
            let startX = width / 2 - sampleSize / 2
            let startY = height / 2 - sampleSize / 2

            var totalR: CGFloat = 0, totalG: CGFloat = 0, totalB: CGFloat = 0
            var count: CGFloat = 0

            for y in startY..<(startY + sampleSize) {
                for x in startX..<(startX + sampleSize) {
                    let offset = y * bytesPerRow + x * 4
                    totalB += CGFloat(buffer[offset]) / 255.0
                    totalG += CGFloat(buffer[offset + 1]) / 255.0
                    totalR += CGFloat(buffer[offset + 2]) / 255.0
                    count += 1
                }
            }

            let avgR = totalR / count
            let avgG = totalG / count
            let avgB = totalB / count

            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
            UIColor(red: avgR, green: avgG, blue: avgB, alpha: 1.0).getHue(&h, saturation: &s, brightness: &b, alpha: nil)
            onColor(h * 360, s, b)
        }
    }
}

// MARK: - PREVIEW UIVIEW
class PreviewUIView: UIView {
    weak var coordinator: CameraPreview.Coordinator?

    override func layoutSubviews() {
        super.layoutSubviews()
        coordinator?.previewLayer?.frame = bounds
        coordinator?.updateOrientation()
    }
}

#Preview {
    CameraView()
}
