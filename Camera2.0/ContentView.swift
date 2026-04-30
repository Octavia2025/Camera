//
//  ContentView.swift
//  Camera2.0
//
//  Created by octavia on 29/4/2026.
//

//  CameraView.swift
//  Pentomino Block Detector — Color-Based Detection
//  Point camera at piece on table — detects by color

import SwiftUI
import AVFoundation
import CoreImage

// MARK: - PIECE COLOR DEFINITIONS
// HSB ranges for each physical piece color
struct PieceColorRange {
    let name: String
    let uiColor: Color
    // Hue range 0–360, Saturation & Brightness 0–1
    let hueMin: CGFloat
    let hueMax: CGFloat
    let satMin: CGFloat
    let briMin: CGFloat
}

let pieceColors: [PieceColorRange] = [
    PieceColorRange(name: "T", uiColor: Color(red: 0.6, green: 0.2, blue: 0.8),
                    hueMin: 270, hueMax: 310, satMin: 0.4, briMin: 0.3),  // Purple

    PieceColorRange(name: "V", uiColor: .red,
                    hueMin: 0,   hueMax: 15,  satMin: 0.5, briMin: 0.3),  // Red (also wraps)

    PieceColorRange(name: "V_wrap", uiColor: .red,
                    hueMin: 345, hueMax: 360, satMin: 0.5, briMin: 0.3),  // Red wrap-around

    PieceColorRange(name: "U", uiColor: .pink,
                    hueMin: 310, hueMax: 345, satMin: 0.25, briMin: 0.5), // Pink

    PieceColorRange(name: "F", uiColor: .blue,
                    hueMin: 200, hueMax: 250, satMin: 0.4, briMin: 0.2),  // Blue

    PieceColorRange(name: "X", uiColor: .teal,
                    hueMin: 165, hueMax: 200, satMin: 0.4, briMin: 0.2),  // Teal

    PieceColorRange(name: "W", uiColor: .orange,
                    hueMin: 20,  hueMax: 45,  satMin: 0.5, briMin: 0.3),  // Orange

    PieceColorRange(name: "L", uiColor: .yellow,
                    hueMin: 45,  hueMax: 75,  satMin: 0.4, briMin: 0.4),  // Yellow

    PieceColorRange(name: "Z", uiColor: .green,
                    hueMin: 90,  hueMax: 165, satMin: 0.3, briMin: 0.2),  // Green
]

// Match a hue/sat/bri to a piece name
func matchPieceColor(hue: CGFloat, sat: CGFloat, bri: CGFloat) -> (name: String, color: Color)? {
    for range in pieceColors {
        if hue >= range.hueMin && hue <= range.hueMax &&
           sat >= range.satMin && bri >= range.briMin {
            // Map "V_wrap" back to V
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
            // Camera feed
            CameraPreview(onColor: { hue, sat, bri in
                handleColor(hue: hue, sat: sat, bri: bri)
            })
            .ignoresSafeArea()

            // Aiming box
            GeometryReader { geo in
                let size = min(geo.size.width, geo.size.height) * 0.65
                let cx = geo.size.width / 2
                let cy = geo.size.height / 2
                let half = size / 2
                let cLen: CGFloat = 36
                let lw: CGFloat = 4

                ZStack {
                    // Dim outside
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

                    // Corner TL
                    Path { p in
                        p.move(to: CGPoint(x: cx - half, y: cy - half + cLen))
                        p.addLine(to: CGPoint(x: cx - half, y: cy - half))
                        p.addLine(to: CGPoint(x: cx - half + cLen, y: cy - half))
                    }.stroke(isLocked ? detectedColor : Color.white, lineWidth: lw)

                    // Corner TR
                    Path { p in
                        p.move(to: CGPoint(x: cx + half - cLen, y: cy - half))
                        p.addLine(to: CGPoint(x: cx + half, y: cy - half))
                        p.addLine(to: CGPoint(x: cx + half, y: cy - half + cLen))
                    }.stroke(isLocked ? detectedColor : Color.white, lineWidth: lw)

                    // Corner BL
                    Path { p in
                        p.move(to: CGPoint(x: cx - half, y: cy + half - cLen))
                        p.addLine(to: CGPoint(x: cx - half, y: cy + half))
                        p.addLine(to: CGPoint(x: cx - half + cLen, y: cy + half))
                    }.stroke(isLocked ? detectedColor : Color.white, lineWidth: lw)

                    // Corner BR
                    Path { p in
                        p.move(to: CGPoint(x: cx + half - cLen, y: cy + half))
                        p.addLine(to: CGPoint(x: cx + half, y: cy + half))
                        p.addLine(to: CGPoint(x: cx + half, y: cy + half - cLen))
                    }.stroke(isLocked ? detectedColor : Color.white, lineWidth: lw)

                    // Centre crosshair
                    Path { p in
                        p.move(to: CGPoint(x: cx - 12, y: cy))
                        p.addLine(to: CGPoint(x: cx + 12, y: cy))
                        p.move(to: CGPoint(x: cx, y: cy - 12))
                        p.addLine(to: CGPoint(x: cx, y: cy + 12))
                    }.stroke(Color.white.opacity(0.5), lineWidth: 1.5)

                    // Instruction label
                    Text("POINT AT PIECE")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.75))
                        .position(x: cx, y: cy - half - 14)
                }
            }

            // Piece name badge — shown when detected
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
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: detectedPiece)
            }

            // Bottom status
            VStack {
                Spacer()
                HStack(spacing: 8) {
                    Circle()
                        .fill(isLocked ? detectedColor : Color.white.opacity(0.35))
                        .frame(width: 8, height: 8)
                    Text(isLocked ? "LOCKED — \(detectedPiece)" : detectedPiece)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(isLocked ? detectedColor : .white)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.black.opacity(0.7))
                .cornerRadius(12)
                .padding(.bottom, 48)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isLocked)
    }

    // MARK: - COLOR HANDLER
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
    typealias UIViewType = PreviewUIView

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

    // MARK: - COORDINATOR
    final class Coordinator: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
        var onColor: (CGFloat, CGFloat, CGFloat) -> Void
        let session = AVCaptureSession()
        var previewLayer: AVCaptureVideoPreviewLayer?
        private var frameCount = 0

        init(onColor: @escaping (CGFloat, CGFloat, CGFloat) -> Void) {
            self.onColor = onColor
        }

        func setupCamera(in view: UIView) {
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: device) else { return }

            session.beginConfiguration()
            session.sessionPreset = .medium  // Lower res is fine for color sampling

            if session.canAddInput(input) { session.addInput(input) }

            let output = AVCaptureVideoDataOutput()
            output.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            output.setSampleBufferDelegate(self,
                queue: DispatchQueue(label: "camera.queue", qos: .userInitiated))

            if session.canAddOutput(output) { session.addOutput(output) }
            session.commitConfiguration()

            let preview = AVCaptureVideoPreviewLayer(session: session)
            preview.videoGravity = .resizeAspectFill
            view.layer.addSublayer(preview)
            self.previewLayer = preview

            DispatchQueue.global(qos: .userInitiated).async {
                self.session.startRunning()
            }
        }

        func captureOutput(_ output: AVCaptureOutput,
                           didOutput sampleBuffer: CMSampleBuffer,
                           from connection: AVCaptureConnection) {

            // Sample every 3rd frame for performance
            frameCount += 1
            guard frameCount % 3 == 0 else { return }

            guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

            CVPixelBufferLockBaseAddress(imageBuffer, .readOnly)
            defer { CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly) }

            let width = CVPixelBufferGetWidth(imageBuffer)
            let height = CVPixelBufferGetHeight(imageBuffer)

            guard let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer) else { return }
            let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer)
            let buffer = baseAddress.assumingMemoryBound(to: UInt8.self)

            // Sample a 20x20 patch from the centre of the frame
            // This matches where the aiming box crosshair is
            let sampleSize = 20
            let startX = width / 2 - sampleSize / 2
            let startY = height / 2 - sampleSize / 2

            var totalR: CGFloat = 0
            var totalG: CGFloat = 0
            var totalB: CGFloat = 0
            var count: CGFloat = 0

            for y in startY..<(startY + sampleSize) {
                for x in startX..<(startX + sampleSize) {
                    let offset = y * bytesPerRow + x * 4
                    let b = CGFloat(buffer[offset])     / 255.0
                    let g = CGFloat(buffer[offset + 1]) / 255.0
                    let r = CGFloat(buffer[offset + 2]) / 255.0
                    totalR += r
                    totalG += g
                    totalB += b
                    count += 1
                }
            }

            let avgR = totalR / count
            let avgG = totalG / count
            let avgB = totalB / count

            // Convert RGB to HSB
            var hue: CGFloat = 0
            var sat: CGFloat = 0
            var bri: CGFloat = 0
            UIColor(red: avgR, green: avgG, blue: avgB, alpha: 1.0)
                .getHue(&hue, saturation: &sat, brightness: &bri, alpha: nil)

            // Convert hue from 0–1 to 0–360
            onColor(hue * 360, sat, bri)
        }
    }
}

// MARK: - PREVIEW UIVIEW
class PreviewUIView: UIView {
    weak var coordinator: CameraPreview.Coordinator?

    override func layoutSubviews() {
        super.layoutSubviews()
        coordinator?.previewLayer?.frame = bounds
    }
}

#Preview {
    CameraView()
}
