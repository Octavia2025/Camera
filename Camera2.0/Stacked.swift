//
//  Stacked.swift
//  Camera2.0
//
//  Created by octavia on 4/5/2026.
//

//  StackedView.swift
//  Pentomino Stack Detector
//  Detects top piece by color, tap to add to stack, pinch to zoom

//  StackedView.swift
//  Pentomino Stack Detector
//  Detects top piece by color, tap to add to stack, pinch to zoom

//  CameraView.swift
//  Pentomino Stack Detector
//  Detects top piece by color, tap to add to stack, builds full stack list

import SwiftUI
import AVFoundation

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
    PieceColorRange(name: "T", uiColor: Color(red: 0.6, green: 0.2, blue: 0.8),
                    hueMin: 270, hueMax: 310, satMin: 0.4, briMin: 0.3),
    PieceColorRange(name: "V", uiColor: .red,
                    hueMin: 0,   hueMax: 15,  satMin: 0.5, briMin: 0.3),
    PieceColorRange(name: "V", uiColor: .red,
                    hueMin: 345, hueMax: 360, satMin: 0.5, briMin: 0.3),
    PieceColorRange(name: "U", uiColor: .pink,
                    hueMin: 310, hueMax: 345, satMin: 0.25, briMin: 0.5),
    PieceColorRange(name: "F", uiColor: .blue,
                    hueMin: 200, hueMax: 250, satMin: 0.4, briMin: 0.2),
    PieceColorRange(name: "X", uiColor: Color(red:0,green:0.6,blue:0.6),
                    hueMin: 165, hueMax: 200, satMin: 0.4, briMin: 0.2),
    PieceColorRange(name: "W", uiColor: .orange,
                    hueMin: 20,  hueMax: 45,  satMin: 0.5, briMin: 0.3),
    PieceColorRange(name: "L", uiColor: .yellow,
                    hueMin: 45,  hueMax: 75,  satMin: 0.4, briMin: 0.4),
    PieceColorRange(name: "Z", uiColor: .green,
                    hueMin: 90,  hueMax: 165, satMin: 0.3, briMin: 0.2),
]

func matchPieceColor(hue: CGFloat, sat: CGFloat, bri: CGFloat) -> (name: String, color: Color)? {
    for range in pieceColors {
        if hue >= range.hueMin && hue <= range.hueMax &&
           sat >= range.satMin && bri >= range.briMin {
            return (range.name, range.uiColor)
        }
    }
    return nil
}

// MARK: - STACK ITEM
struct StackItem: Identifiable {
    let id = UUID()
    let name: String
    let color: Color
    let position: Int // 1 = top
}

// MARK: - MAIN VIEW
struct CameraView: View {
    @State private var detectedPiece: String = "Scanning..."
    @State private var detectedColor: Color = .white
    @State private var isLocked = false
    @State private var stableFrames = 0
    @State private var lastPiece = ""
    @State private var stack: [StackItem] = []
    @State private var currentHue: CGFloat = 0
    @State private var currentSat: CGFloat = 0
    @State private var currentBri: CGFloat = 0
    @State private var showAdded = false

    var body: some View {
        ZStack {
            // Camera feed
            CameraPreview(onColor: handleColor)
                .ignoresSafeArea()

            // Aiming box overlay
            GeometryReader { geo in
                let size = min(geo.size.width, geo.size.height) * 0.6
                let cx = geo.size.width / 2
                let cy = geo.size.height / 2
                let half = size / 2
                let cLen: CGFloat = 36
                let lw: CGFloat = 4
                let cornerColor: Color = isLocked ? detectedColor : .white

                ZStack {
                    // Dim outside box
                    Rectangle()
                        .fill(Color.black.opacity(0.45))
                        .mask(
                            ZStack {
                                Rectangle()
                                Rectangle()
                                    .frame(width: size, height: size)
                                    .position(x: cx, y: cy)
                                    .blendMode(.destinationOut)
                            }.compositingGroup()
                        )

                    // Corner TL
                    Path { p in
                        p.move(to: CGPoint(x: cx-half, y: cy-half+cLen))
                        p.addLine(to: CGPoint(x: cx-half, y: cy-half))
                        p.addLine(to: CGPoint(x: cx-half+cLen, y: cy-half))
                    }.stroke(cornerColor, lineWidth: lw)

                    // Corner TR
                    Path { p in
                        p.move(to: CGPoint(x: cx+half-cLen, y: cy-half))
                        p.addLine(to: CGPoint(x: cx+half, y: cy-half))
                        p.addLine(to: CGPoint(x: cx+half, y: cy-half+cLen))
                    }.stroke(cornerColor, lineWidth: lw)

                    // Corner BL
                    Path { p in
                        p.move(to: CGPoint(x: cx-half, y: cy+half-cLen))
                        p.addLine(to: CGPoint(x: cx-half, y: cy+half))
                        p.addLine(to: CGPoint(x: cx-half+cLen, y: cy+half))
                    }.stroke(cornerColor, lineWidth: lw)

                    // Corner BR
                    Path { p in
                        p.move(to: CGPoint(x: cx+half-cLen, y: cy+half))
                        p.addLine(to: CGPoint(x: cx+half, y: cy+half))
                        p.addLine(to: CGPoint(x: cx+half, y: cy+half-cLen))
                    }.stroke(cornerColor, lineWidth: lw)

                    // Crosshair
                    Path { p in
                        p.move(to: CGPoint(x: cx-14, y: cy))
                        p.addLine(to: CGPoint(x: cx+14, y: cy))
                        p.move(to: CGPoint(x: cx, y: cy-14))
                        p.addLine(to: CGPoint(x: cx, y: cy+14))
                    }.stroke(Color.white.opacity(0.5), lineWidth: 1.5)

                    Text("POINT AT TOP PIECE")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.8))
                        .position(x: cx, y: cy - half - 14)
                }
            }

            // Top — detected piece badge + Add button
            VStack(spacing: 0) {
                // Detected piece
                HStack(spacing: 12) {
                    Circle()
                        .fill(detectedColor)
                        .frame(width: 18, height: 18)
                        .shadow(color: detectedColor.opacity(0.9), radius: 6)

                    Text(detectedPiece == "Scanning..." ? "Scanning..." : "PIECE  \(detectedPiece)")
                        .font(.system(size: 26, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black.opacity(0.75))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(isLocked ? detectedColor : Color.white.opacity(0.15), lineWidth: 2)
                        )
                )
                .padding(.top, 55)

                // Add to stack button — only show when locked
                if isLocked {
                    Button(action: addToStack) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                            Text("ADD TO STACK")
                        }
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.black)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 10)
                        .background(detectedColor)
                        .cornerRadius(12)
                    }
                    .padding(.top, 10)
                    .transition(.scale.combined(with: .opacity))
                }

                // "Added!" flash
                if showAdded {
                    Text("✓ Added to stack!")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.green)
                        .padding(.top, 6)
                        .transition(.opacity)
                }

                Spacer()
            }
            .animation(.spring(response: 0.3), value: isLocked)
            .animation(.easeInOut(duration: 0.2), value: showAdded)

            // Stack panel — bottom
            VStack {
                Spacer()

                if !stack.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text("STACK  (\(stack.count) piece\(stack.count == 1 ? "" : "s"))")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.6))
                            Spacer()
                            Button(action: { stack.removeAll() }) {
                                Text("Clear")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 8)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(stack) { item in
                                    VStack(spacing: 4) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(item.color)
                                                .frame(width: 50, height: 50)
                                            Text(item.name)
                                                .font(.system(size: 20, weight: .black, design: .monospaced))
                                                .foregroundColor(.white)
                                                .shadow(color: .black.opacity(0.4), radius: 2)
                                        }
                                        Text("#\(item.position)")
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundColor(.white.opacity(0.5))
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 14)
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.black.opacity(0.75))
                    )
                    .padding(.horizontal, 16)
                }

                // HSB debug line
                Text("H:\(Int(currentHue))°  S:\(Int(currentSat*100))%  B:\(Int(currentBri*100))%")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.3))
                    .padding(.top, 6)
                    .padding(.bottom, 48)
            }
        }
    }

    // MARK: - ADD TO STACK
    private func addToStack() {
        guard detectedPiece != "Scanning..." else { return }
        let item = StackItem(
            name: detectedPiece,
            color: detectedColor,
            position: stack.count + 1
        )
        withAnimation(.spring()) {
            stack.append(item)
        }
        // Flash "Added!" for 1.5s
        showAdded = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showAdded = false
        }
        // Reset detection so user can scan next piece
        stableFrames = 0
        isLocked = false
        lastPiece = ""
        detectedPiece = "Scanning..."
        detectedColor = .white
    }

    // MARK: - COLOR HANDLER
    private func handleColor(hue: CGFloat, sat: CGFloat, bri: CGFloat) {
        DispatchQueue.main.async {
            currentHue = hue
            currentSat = sat
            currentBri = bri

            let result = matchPieceColor(hue: hue, sat: sat, bri: bri)
            let newPiece = result?.name ?? "Unknown"

            if newPiece == lastPiece && newPiece != "Unknown" {
                stableFrames += 1
            } else {
                stableFrames = 0
            }
            lastPiece = newPiece

            if newPiece == "Unknown" {
                if !isLocked {
                    detectedPiece = "Scanning..."
                    detectedColor = .white
                }
            } else {
                detectedPiece = newPiece
                detectedColor = result?.color ?? .white
                isLocked = stableFrames > 12
            }
        }
    }
}

// MARK: - CAMERA PREVIEW
struct CameraPreview: UIViewRepresentable {
    typealias UIViewType = PreviewUIView
    var onColor: (CGFloat, CGFloat, CGFloat) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onColor: onColor) }

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
            output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "camera.q", qos: .userInitiated))

            if session.canAddOutput(output) {
                session.addOutput(output)
                videoOutput = output
            }
            session.commitConfiguration()

            let preview = AVCaptureVideoPreviewLayer(session: session)
            preview.videoGravity = .resizeAspectFill
            view.layer.addSublayer(preview)
            previewLayer = preview

            DispatchQueue.global(qos: .userInitiated).async { self.session.startRunning() }
        }

        func updateOrientation() {
            guard let previewLayer = previewLayer else { return }
            let orientation = UIDevice.current.orientation
            let vo: AVCaptureVideoOrientation
            switch orientation {
            case .landscapeLeft:       vo = .landscapeRight
            case .landscapeRight:      vo = .landscapeLeft
            case .portraitUpsideDown:  vo = .portraitUpsideDown
            default:                   vo = .portrait
            }
            if previewLayer.connection?.isVideoOrientationSupported == true {
                previewLayer.connection?.videoOrientation = vo
            }
            if let vc = videoOutput?.connection(with: .video), vc.isVideoOrientationSupported {
                vc.videoOrientation = vo
            }
        }

        func captureOutput(_ output: AVCaptureOutput,
                           didOutput sampleBuffer: CMSampleBuffer,
                           from connection: AVCaptureConnection) {
            frameCount += 1
            guard frameCount % 3 == 0 else { return }
            guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

            CVPixelBufferLockBaseAddress(imageBuffer, .readOnly)
            defer { CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly) }

            let width  = CVPixelBufferGetWidth(imageBuffer)
            let height = CVPixelBufferGetHeight(imageBuffer)
            let bpr    = CVPixelBufferGetBytesPerRow(imageBuffer)
            guard let base = CVPixelBufferGetBaseAddress(imageBuffer) else { return }
            let buf = base.assumingMemoryBound(to: UInt8.self)

            let s  = 12
            let cx = width / 2
            let cy = height / 2
            var rT: CGFloat = 0, gT: CGFloat = 0, bT: CGFloat = 0, n: CGFloat = 0

            for y in (cy-s)..<(cy+s) {
                for x in (cx-s)..<(cx+s) {
                    let o = y * bpr + x * 4
                    bT += CGFloat(buf[o])
                    gT += CGFloat(buf[o+1])
                    rT += CGFloat(buf[o+2])
                    n  += 1
                }
            }

            let r = rT/n/255, g = gT/n/255, b = bT/n/255
            var hue: CGFloat = 0, sat: CGFloat = 0, bri: CGFloat = 0
            UIColor(red: r, green: g, blue: b, alpha: 1).getHue(&hue, saturation: &sat, brightness: &bri, alpha: nil)
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
        coordinator?.updateOrientation()
    }
}

#Preview { CameraView() }
