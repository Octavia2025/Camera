//
//  ContentView.swift
//  Me
//
//  Created by octavia on 7/4/2026.
import SwiftUI
import AVFoundation
import Vision
import simd

// MARK: - MAIN VIEW
struct CameraView: View {
    @State private var detectedBox: CGRect = .zero
    @State private var detectedShape: String = "Scanning..."
    @State private var isLocked = false

    var body: some View {
        ZStack {
            CameraPreview(
                box: $detectedBox,
                shape: $detectedShape,
                locked: $isLocked
            )
            .ignoresSafeArea()

            // ROI indicator
            GeometryReader { geo in
                let roiSize = min(geo.size.width, geo.size.height) * 0.7
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                    .frame(width: roiSize, height: roiSize)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
            }

            GeometryReader { geo in
                if detectedBox != .zero {
                    let rect = VNImageRectForNormalizedRect(
                        detectedBox,
                        Int(geo.size.width),
                        Int(geo.size.height)
                    )

                    let color: Color = {
                        if isLocked { return .yellow }
                        switch detectedShape {
                        case let s where s.contains("Triangle"):  return .orange
                        case let s where s.contains("Square"):    return .blue
                        case let s where s.contains("Rectangle"): return .green
                        default: return .white
                        }
                    }()

                    ZStack {
                        shapeOverlay(for: detectedShape, color: color, size: CGSize(width: rect.width, height: rect.height))

                        Text(detectedShape)
                            .font(.caption.bold())
                            .padding(6)
                            .background(.black.opacity(0.75))
                            .foregroundColor(.white)
                            .cornerRadius(6)
                            .offset(y: -(rect.height / 2) - 24)
                    }
                    .position(x: rect.midX, y: geo.size.height - rect.midY)
                    .animation(.easeOut(duration: 0.15), value: detectedBox)
                }
            }

            // Status label
            VStack {
                Spacer()
                Text(isLocked ? "Locked: \(detectedShape)" : detectedShape)
                    .font(.headline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.6))
                    .foregroundColor(isLocked ? .yellow : .white)
                    .cornerRadius(10)
                    .padding(.bottom, 40)
            }
        }
    }

    @ViewBuilder
    func shapeOverlay(for shape: String, color: Color, size: CGSize) -> some View {
        if shape.contains("Triangle") {
            TriangleShape().stroke(color, lineWidth: 4).frame(width: size.width, height: size.height)
        } else {
            RoundedRectangle(cornerRadius: 10).stroke(color, lineWidth: 4).frame(width: size.width, height: size.height)
        }
    }
}

// MARK: - TRIANGLE SHAPE
struct TriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.midX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.closeSubpath()
        }
    }
}

// MARK: - CAMERA WRAPPER
struct CameraPreview: UIViewRepresentable {
    @Binding var box: CGRect
    @Binding var shape: String
    @Binding var locked: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(box: $box, shape: $shape, locked: $locked)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        context.coordinator.setupCamera(in: view)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.updateFrame(uiView)
    }

    // MARK: - COORDINATOR
    final class Coordinator: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
        @Binding var box: CGRect
        @Binding var shape: String
        @Binding var locked: Bool

        let session = AVCaptureSession()
        var previewLayer: AVCaptureVideoPreviewLayer?

        private var lastShape = ""
        private var stableFrames = 0
        private let stabilityThreshold = 10

        init(box: Binding<CGRect>, shape: Binding<String>, locked: Binding<Bool>) {
            self._box = box
            self._shape = shape
            self._locked = locked
        }

        // MARK: CAMERA SETUP
        func setupCamera(in view: UIView) {
            guard let device = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: device) else { return }

            session.beginConfiguration()
            session.sessionPreset = .hd1280x720

            if session.canAddInput(input) { session.addInput(input) }

            let output = AVCaptureVideoDataOutput()
            output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
            output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "camera.queue", qos: .userInitiated))

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

        func updateFrame(_ view: UIView) {
            previewLayer?.frame = view.bounds
        }

        // MARK: - VISION PROCESSING
        func captureOutput(_ output: AVCaptureOutput,
                           didOutput sampleBuffer: CMSampleBuffer,
                           from connection: AVCaptureConnection) {

            guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

            let roi = CGRect(x: 0.15, y: 0.15, width: 0.7, height: 0.7)

            let request = VNDetectContoursRequest { [weak self] req, _ in
                guard let self = self,
                      let obs = req.results as? [VNContoursObservation] else { return }

                let topContours = obs.first?.topLevelContours ?? []

                let filtered = topContours.filter {
                    let area = self.contourArea($0)
                    return area > 0.002 && area < 0.4
                }

                guard let best = filtered.max(by: {
                    self.contourArea($0) < self.contourArea($1)
                }) else { return }

                let points: [simd_float2]
                do {
                    points = try best.normalizedPoints
                } catch {
                    print("Contour points error: \(error)")
                    return
                }

                guard points.count > 10 else { return }

                let xs = points.map { CGFloat($0.x) }
                let ys = points.map { CGFloat($0.y) }

                guard let minX = xs.min(), let maxX = xs.max(),
                      let minY = ys.min(), let maxY = ys.max() else { return }

                let bboxW = maxX - minX
                let bboxH = maxY - minY

                guard bboxW < 0.85 && bboxH < 0.85 else { return }
                guard bboxW > 0.04 && bboxH > 0.04 else { return }

                let corners = self.approximateCorners(from: points)
                let newShape = self.classifyShape(corners: corners, points: points)

                guard ["Triangle", "Square", "Rectangle"].contains(newShape) else { return }

                let rawBox = CGRect(x: minX, y: minY, width: bboxW, height: bboxH)

                if newShape == self.lastShape {
                    self.stableFrames += 1
                } else {
                    self.stableFrames = 0
                }
                self.lastShape = newShape
                let locked = self.stableFrames > self.stabilityThreshold

                DispatchQueue.main.async {
                    self.box = rawBox
                    self.shape = locked ? "Locked: \(newShape)" : newShape
                    self.locked = locked
                }
            }

            request.regionOfInterest = roi
            request.contrastAdjustment = 2.5
            request.detectsDarkOnLight = true

            do {
                try VNImageRequestHandler(
                    cvPixelBuffer: buffer,
                    orientation: .right
                ).perform([request])
            } catch {
                print("Vision error: \(error)")
            }
        }

        // MARK: - CORNER APPROXIMATION
        func approximateCorners(from points: [simd_float2]) -> Int {
            guard points.count > 4 else { return points.count }

            var corners = 0
            let count = points.count
            let windowSize = max(2, count / 30)

            for i in 0..<count {
                let prev = points[(i - windowSize + count) % count]
                let curr = points[i]
                let next = points[(i + windowSize) % count]

                let v1 = simd_float2(curr.x - prev.x, curr.y - prev.y)
                let v2 = simd_float2(next.x - curr.x, next.y - curr.y)

                let len1 = simd_length(v1)
                let len2 = simd_length(v2)
                guard len1 > 0.001, len2 > 0.001 else { continue }

                let dot = simd_dot(v1 / len1, v2 / len2)
                let angle = acos(max(-1, min(1, dot))) * (180 / .pi)

                if angle > 40 { corners += 1 }
            }

            return max(3, corners / 4)
        }

        // MARK: - CONTOUR AREA
        func contourArea(_ contour: VNContour) -> Float {
            let points: [simd_float2]
            do {
                points = try contour.normalizedPoints
            } catch {
                return 0
            }
            guard points.count > 2 else { return 0 }

            var area: Float = 0
            for i in 0..<points.count {
                let j = (i + 1) % points.count
                area += points[i].x * points[j].y
                area -= points[j].x * points[i].y
            }
            return abs(area) / 2
        }

        // MARK: - SHAPE CLASSIFICATION
        func classifyShape(corners: Int, points: [simd_float2]) -> String {
            let xs = points.map { $0.x }
            let ys = points.map { $0.y }
            let w = (xs.max() ?? 1) - (xs.min() ?? 0)
            let h = (ys.max() ?? 1) - (ys.min() ?? 0)
            let aspect = w / max(h, 0.0001)
            let isSquarish = abs(aspect - 1.0) < 0.2

            switch corners {
            case 3:
                return "Triangle"
            case 4:
                return isSquarish ? "Square" : "Rectangle"
            default:
                return "Unknown"
            }
        }
    }
}

#Preview {
    CameraView()
}
