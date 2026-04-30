//
//  ContentView.swift
//  Camera2.0
//
//  Created by octavia on 29/4/2026.
//

//  CameraView.swift
//  Pentomino Block Detector
//  Detects physical pentomino pieces via camera using Vision + grid-cell matching
 
//  CameraView.swift
//  Pentomino Block Detector
//  Back camera — place piece flat on table and aim down

import SwiftUI
import AVFoundation
import Vision
import simd

// MARK: - PENTOMINO DEFINITIONS
struct PentominoPiece {
    let name: String
    let color: Color
    let grids: [[String]] // 5 rows of 5 chars each ("0"/"1"), multiple rotations
}

let allPentominoes: [PentominoPiece] = [

    // T — top bar + centre stem (4 rotations)
    PentominoPiece(name: "T", color: Color(red: 0.6, green: 0.2, blue: 0.8), grids: [
        ["11100",
         "01000",
         "01000",
         "00000",
         "00000"],
        ["10000",
         "11000",
         "10000",
         "00000",
         "00000"],
        ["01000",
         "01000",
         "11100",
         "00000",
         "00000"],
        ["00100",
         "11100",
         "00100",
         "00000",
         "00000"]
    ]),

    // W — staircase (4 rotations)
    PentominoPiece(name: "W", color: .orange, grids: [
        ["10000",
         "11000",
         "01100",
         "00000",
         "00000"],
        ["01100",
         "01000",
         "11000",
         "00000",
         "00000"],
        ["11000",
         "01100",
         "00100",
         "00000",
         "00000"],
        ["00100",
         "01100",
         "11000",
         "00000",
         "00000"]
    ]),

    // Z — zigzag (4 rotations including mirror)
    PentominoPiece(name: "Z", color: .green, grids: [
        ["11000",
         "01000",
         "01100",
         "00000",
         "00000"],
        ["00110",
         "00100",
         "11000",
         "00000",
         "00000"],
        ["11000",
         "01100",
         "00100",
         "00000",
         "00000"],
        ["00100",
         "01100",
         "11000",
         "00000",
         "00000"]
    ]),

    // L — 4 tall, foot right (4 rotations)
    PentominoPiece(name: "L", color: .yellow, grids: [
        ["10000",
         "10000",
         "10000",
         "11000",
         "00000"],
        ["11100",
         "10000",
         "10000",
         "00000",
         "00000"],
        ["11000",
         "01000",
         "01000",
         "01000",
         "00000"],
        ["00100",
         "00100",
         "11100",
         "00000",
         "00000"]
    ]),

    // U — staple / horseshoe (4 rotations)
    PentominoPiece(name: "U", color: .pink, grids: [
        ["10100",
         "11100",
         "00000",
         "00000",
         "00000"],
        ["11000",
         "10000",
         "11000",
         "00000",
         "00000"],
        ["11100",
         "10100",
         "00000",
         "00000",
         "00000"],
        ["01100",
         "00100",
         "01100",
         "00000",
         "00000"]
    ]),

    // F — offset asymmetric (4 rotations)
    PentominoPiece(name: "F", color: .blue, grids: [
        ["01100",
         "11000",
         "01000",
         "00000",
         "00000"],
        ["10000",
         "11000",
         "01100",
         "00000",
         "00000"],
        ["01000",
         "11100",
         "10000",
         "00000",
         "00000"],
        ["00100",
         "11100",
         "01000",
         "00000",
         "00000"]
    ]),

    // V — corner shape (4 rotations)
    PentominoPiece(name: "V", color: .red, grids: [
        ["10000",
         "10000",
         "11100",
         "00000",
         "00000"],
        ["11100",
         "10000",
         "10000",
         "00000",
         "00000"],
        ["11100",
         "00100",
         "00100",
         "00000",
         "00000"],
        ["00100",
         "00100",
         "11100",
         "00000",
         "00000"]
    ]),

    // X — plus sign (rotationally symmetric)
    PentominoPiece(name: "X", color: .teal, grids: [
        ["01000",
         "11100",
         "01000",
         "00000",
         "00000"]
    ])
]

// MARK: - GRID MATCHING ENGINE
struct PentominoMatcher {

    /// Normalize detected cells into a top-left-anchored 5x5 grid
    static func normalize(cells: [(Int, Int)]) -> [String] {
        guard !cells.isEmpty else { return [] }
        let minR = cells.map { $0.1 }.min()!
        let minC = cells.map { $0.0 }.min()!
        let shifted = cells.map { ($0.0 - minC, $0.1 - minR) }
        var grid = Array(repeating: Array(repeating: "0", count: 5), count: 5)
        for (c, r) in shifted where r < 5 && c < 5 {
            grid[r][c] = "1"
        }
        return grid.map { $0.joined() }
    }

    /// Score how many "1" cells match between two grids
    static func similarity(_ a: [String], _ b: [String]) -> Int {
        var matches = 0
        var totalOnes = 0
        for (rowA, rowB) in zip(a, b) {
            for (cA, cB) in zip(rowA, rowB) {
                if cA == "1" { totalOnes += 1 }
                if cA == cB && cA == "1" { matches += 1 }
            }
        }
        // Penalise if detected has far more cells than the template
        return matches
    }

    /// Returns best matching piece name + color, or nil if no confident match
    static func match(cells: [(Int, Int)]) -> (name: String, color: Color)? {
        guard cells.count >= 3 else { return nil }
        let norm = normalize(cells: cells)
        var bestScore = 0
        var bestPiece: PentominoPiece?

        for piece in allPentominoes {
            for rotation in piece.grids {
                let score = similarity(norm, rotation)
                if score > bestScore {
                    bestScore = score
                    bestPiece = piece
                }
            }
        }
        // Need at least 3 cells matching to be confident
        guard bestScore >= 3, let piece = bestPiece else { return nil }
        return (piece.name, piece.color)
    }
}

// MARK: - MAIN VIEW
struct CameraView: View {
    @State private var detectedBox: CGRect = .zero
    @State private var detectedShape: String = "Scanning..."
    @State private var isLocked = false
    @State private var pieceColor: Color = .white
    @State private var filledCells: [(Int, Int)] = []

    var body: some View {
        ZStack {
            CameraPreview(
                box: $detectedBox,
                shape: $detectedShape,
                locked: $isLocked,
                pieceColor: $pieceColor,
                filledCells: $filledCells
            )
            .ignoresSafeArea()

            // Aiming box with corner markers
            GeometryReader { geo in
                let roiSize = min(geo.size.width, geo.size.height) * 0.72
                let cx = geo.size.width / 2
                let cy = geo.size.height / 2
                let half = roiSize / 2
                let cornerLen: CGFloat = 32
                let lw: CGFloat = 4

                ZStack {
                    // Dim area outside box
                    Rectangle()
                        .fill(Color.black.opacity(0.4))
                        .mask(
                            ZStack {
                                Rectangle()
                                Rectangle()
                                    .frame(width: roiSize, height: roiSize)
                                    .position(x: cx, y: cy)
                                    .blendMode(.destinationOut)
                            }
                            .compositingGroup()
                        )

                    // Corner TL
                    Path { p in
                        p.move(to: CGPoint(x: cx - half, y: cy - half + cornerLen))
                        p.addLine(to: CGPoint(x: cx - half, y: cy - half))
                        p.addLine(to: CGPoint(x: cx - half + cornerLen, y: cy - half))
                    }.stroke(Color.white, lineWidth: lw)

                    // Corner TR
                    Path { p in
                        p.move(to: CGPoint(x: cx + half - cornerLen, y: cy - half))
                        p.addLine(to: CGPoint(x: cx + half, y: cy - half))
                        p.addLine(to: CGPoint(x: cx + half, y: cy - half + cornerLen))
                    }.stroke(Color.white, lineWidth: lw)

                    // Corner BL
                    Path { p in
                        p.move(to: CGPoint(x: cx - half, y: cy + half - cornerLen))
                        p.addLine(to: CGPoint(x: cx - half, y: cy + half))
                        p.addLine(to: CGPoint(x: cx - half + cornerLen, y: cy + half))
                    }.stroke(Color.white, lineWidth: lw)

                    // Corner BR
                    Path { p in
                        p.move(to: CGPoint(x: cx + half - cornerLen, y: cy + half))
                        p.addLine(to: CGPoint(x: cx + half, y: cy + half))
                        p.addLine(to: CGPoint(x: cx + half, y: cy + half - cornerLen))
                    }.stroke(Color.white, lineWidth: lw)

                    Text("PLACE PIECE ON TABLE & AIM HERE")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.8))
                        .position(x: cx, y: cy - half - 14)
                }
            }

            // Detection overlay
            GeometryReader { geo in
                if detectedBox != .zero {
                    let rect = VNImageRectForNormalizedRect(
                        detectedBox,
                        Int(geo.size.width),
                        Int(geo.size.height)
                    )

                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isLocked ? Color.yellow : pieceColor, lineWidth: 4)
                            .frame(width: rect.width, height: rect.height)

                        GridOverlay(filledCells: filledCells, color: pieceColor)
                            .frame(width: rect.width, height: rect.height)
                            .opacity(0.45)

                        Text(detectedShape)
                            .font(.system(size: 18, weight: .black, design: .monospaced))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.8))
                            .foregroundColor(isLocked ? .yellow : pieceColor)
                            .cornerRadius(8)
                            .offset(y: -(rect.height / 2) - 28)
                    }
                    .position(x: rect.midX, y: geo.size.height - rect.midY)
                    .animation(.easeOut(duration: 0.12), value: detectedBox)
                }
            }

            // Bottom status bar
            VStack {
                Spacer()
                HStack(spacing: 10) {
                    Circle()
                        .fill(isLocked ? Color.yellow : Color.white.opacity(0.4))
                        .frame(width: 9, height: 9)
                    Text(isLocked ? "✓ LOCKED — \(detectedShape)" : detectedShape)
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundColor(isLocked ? .yellow : .white)
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.7))
                .cornerRadius(14)
                .padding(.bottom, 48)
            }
        }
    }
}

// MARK: - GRID OVERLAY
struct GridOverlay: View {
    let filledCells: [(Int, Int)]
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let cellW = geo.size.width / 5
            let cellH = geo.size.height / 5
            ForEach(0..<filledCells.count, id: \.self) { i in
                let (col, row) = filledCells[i]
                Rectangle()
                    .fill(color.opacity(0.5))
                    .frame(width: cellW - 2, height: cellH - 2)
                    .position(
                        x: CGFloat(col) * cellW + cellW / 2,
                        y: CGFloat(row) * cellH + cellH / 2
                    )
            }
        }
    }
}

// MARK: - CAMERA WRAPPER
struct CameraPreview: UIViewRepresentable {
    typealias UIViewType = PreviewUIView

    @Binding var box: CGRect
    @Binding var shape: String
    @Binding var locked: Bool
    @Binding var pieceColor: Color
    @Binding var filledCells: [(Int, Int)]

    func makeCoordinator() -> Coordinator {
        Coordinator(box: $box, shape: $shape, locked: $locked,
                    pieceColor: $pieceColor, filledCells: $filledCells)
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
        @Binding var box: CGRect
        @Binding var shape: String
        @Binding var locked: Bool
        @Binding var pieceColor: Color
        @Binding var filledCells: [(Int, Int)]

        let session = AVCaptureSession()
        var previewLayer: AVCaptureVideoPreviewLayer?

        private var lastShape = ""
        private var stableFrames = 0
        private let stabilityThreshold = 10

        init(box: Binding<CGRect>, shape: Binding<String>, locked: Binding<Bool>,
             pieceColor: Binding<Color>, filledCells: Binding<[(Int, Int)]>) {
            self._box = box
            self._shape = shape
            self._locked = locked
            self._pieceColor = pieceColor
            self._filledCells = filledCells
        }

        // MARK: - CAMERA SETUP (back camera)
        func setupCamera(in view: UIView) {
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: device) else { return }

            session.beginConfiguration()
            session.sessionPreset = .hd1280x720

            if session.canAddInput(input) { session.addInput(input) }

            let output = AVCaptureVideoDataOutput()
            output.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
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

        // MARK: - VISION PROCESSING
        func captureOutput(_ output: AVCaptureOutput,
                           didOutput sampleBuffer: CMSampleBuffer,
                           from connection: AVCaptureConnection) {

            guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

            // ROI matches the aiming box (centre 72% of frame)
            let roi = CGRect(x: 0.14, y: 0.14, width: 0.72, height: 0.72)

            let contourRequest = VNDetectContoursRequest { [weak self] req, _ in
                guard let self = self,
                      let obs = req.results as? [VNContoursObservation] else { return }

                let topContours = obs.first?.topLevelContours ?? []

                // Filter by area — ignore tiny noise and full-frame blobs
                let filtered = topContours.filter {
                    let area = self.contourArea($0)
                    return area > 0.002 && area < 0.5
                }

                // Pick largest contour — the piece
                guard let best = filtered.max(by: {
                    self.contourArea($0) < self.contourArea($1)
                }) else { return }

                let points: [simd_float2]
                do { points = try best.normalizedPoints } catch { return }
                guard points.count > 10 else { return }

                let xs = points.map { CGFloat($0.x) }
                let ys = points.map { CGFloat($0.y) }

                guard let minX = xs.min(), let maxX = xs.max(),
                      let minY = ys.min(), let maxY = ys.max() else { return }

                let bboxW = maxX - minX
                let bboxH = maxY - minY

                guard bboxW > 0.04 && bboxH > 0.04 else { return }
                guard bboxW < 0.88 && bboxH < 0.88 else { return }

                let rawBox = CGRect(x: minX, y: minY, width: bboxW, height: bboxH)

                // --- GRID CELL DETECTION ---
                // Split bounding box into 5x5 grid
                // Count contour points per cell — filled cells form the shape pattern
                var cellCounts = Array(repeating: Array(repeating: 0, count: 5), count: 5)

                for pt in points {
                    let normX = (CGFloat(pt.x) - minX) / bboxW
                    // Flip Y: Vision origin is bottom-left, grids are top-left
                    let normY = 1.0 - (CGFloat(pt.y) - minY) / bboxH
                    let col = min(4, max(0, Int(normX * 5)))
                    let row = min(4, max(0, Int(normY * 5)))
                    cellCounts[row][col] += 1
                }

                // A cell is "filled" if it has enough contour points
                let threshold = max(2, points.count / 35)
                var filledCells: [(Int, Int)] = []
                for r in 0..<5 {
                    for c in 0..<5 {
                        if cellCounts[r][c] >= threshold {
                            filledCells.append((c, r))
                        }
                    }
                }

                let match = PentominoMatcher.match(cells: filledCells)
                let newShape = match?.name ?? "Unknown"

                if newShape == self.lastShape && newShape != "Unknown" {
                    self.stableFrames += 1
                } else {
                    self.stableFrames = 0
                }
                self.lastShape = newShape
                let locked = self.stableFrames > self.stabilityThreshold

                DispatchQueue.main.async {
                    self.box = rawBox
                    self.shape = newShape == "Unknown" ? "Scanning..." : (locked ? "\(newShape)" : newShape)
                    self.locked = locked
                    self.pieceColor = match?.color ?? .white
                    self.filledCells = filledCells
                }
            }

            contourRequest.regionOfInterest = roi
            contourRequest.contrastAdjustment = 3.0   // Higher contrast for table surfaces
            contourRequest.detectsDarkOnLight = true   // Dark piece on light table

            do {
                // .up orientation for iPad held overhead pointing down at table
                try VNImageRequestHandler(cvPixelBuffer: buffer,
                                          orientation: .up).perform([contourRequest])
            } catch {
                print("Vision error: \(error)")
            }
        }

        // MARK: - CONTOUR AREA (Shoelace formula)
        func contourArea(_ contour: VNContour) -> Float {
            let points: [simd_float2]
            do { points = try contour.normalizedPoints } catch { return 0 }
            guard points.count > 2 else { return 0 }
            var area: Float = 0
            for i in 0..<points.count {
                let j = (i + 1) % points.count
                area += points[i].x * points[j].y
                area -= points[j].x * points[i].y
            }
            return abs(area) / 2
        }
    }
}

// MARK: - PREVIEW UIVIEW (fixes white screen on iPad)
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
