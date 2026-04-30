import SwiftUI
import AVFoundation
import simd

struct CameraView: View {
    @State private var detections: [DetectedPiece] = []
    @State private var statusText = "Point the camera at the pieces"

    var body: some View {
        ZStack {
            CameraPreview(
                detections: $detections,
                statusText: $statusText
            )
            .ignoresSafeArea()

            GeometryReader { geo in
                let roiSize = min(geo.size.width, geo.size.height) * 0.72
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.35), lineWidth: 2)
                    .frame(width: roiSize, height: roiSize)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
            }

            VStack(spacing: 12) {
                Spacer()

                if detections.isEmpty {
                    Text(statusText)
                        .font(.headline)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.black.opacity(0.68))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(statusText)
                            .font(.headline)
                            .foregroundColor(.white)

                        ForEach(detections) { detection in
                            HStack(spacing: 10) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(detection.displayColor)
                                    .frame(width: 16, height: 16)

                                Text("\(detection.shapeName) pentomino")
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(.black.opacity(0.72))
                    .cornerRadius(16)
                    .padding(.horizontal, 20)
                }
                .padding(.top, 60)
                .frame(maxHeight: .infinity, alignment: .top)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: detectedPiece)
            }
            .padding(.bottom, 36)
        }
    }
}

struct DetectedPiece: Identifiable, Equatable {
    let id: String
    let shapeName: String
    let colorName: String

    var displayColor: Color {
        switch colorName {
        case "red":
            return .red
        case "orange":
            return .orange
        case "yellow":
            return .yellow
        case "green":
            return .green
        case "teal":
            return .mint
        case "blue":
            return .blue
        case "purple":
            return .purple
        case "pink":
            return .pink
        default:
            return .white
        }
    }
}

struct CameraPreview: UIViewRepresentable {
    @Binding var detections: [DetectedPiece]
    @Binding var statusText: String

    func makeCoordinator() -> Coordinator {
        Coordinator(detections: $detections, statusText: $statusText)
    }

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.coordinator = context.coordinator
        context.coordinator.setupCamera(in: view)
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) { }

    final class Coordinator: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
        struct GridPoint: Hashable {
            let x: Int
            let y: Int
        }

        struct GridComponent {
            let color: ColorProfile
            let points: Set<GridPoint>
        }

        struct ColorProfile {
            let name: String
            let rgb: SIMD3<Double>
        }

        @Binding var detections: [DetectedPiece]
        @Binding var statusText: String

        let session = AVCaptureSession()
        var previewLayer: AVCaptureVideoPreviewLayer?
        private var frameCount = 0

        private let roi = CGRect(x: 0.14, y: 0.14, width: 0.72, height: 0.72)
        private let sampleResolution = 160
        private let templateResolution = 24
        private let minimumComponentPixels = 180
        private let colorProfiles: [ColorProfile] = [
            ColorProfile(name: "red", rgb: SIMD3(0.84, 0.22, 0.22)),
            ColorProfile(name: "orange", rgb: SIMD3(0.95, 0.57, 0.23)),
            ColorProfile(name: "yellow", rgb: SIMD3(0.90, 0.82, 0.20)),
            ColorProfile(name: "green", rgb: SIMD3(0.47, 0.86, 0.24)),
            ColorProfile(name: "teal", rgb: SIMD3(0.53, 0.83, 0.78)),
            ColorProfile(name: "blue", rgb: SIMD3(0.19, 0.45, 0.78)),
            ColorProfile(name: "purple", rgb: SIMD3(0.51, 0.19, 0.72)),
            ColorProfile(name: "pink", rgb: SIMD3(0.90, 0.27, 0.59))
        ]
        private lazy var pentominoTemplates = Self.makePentominoTemplates(resolution: templateResolution)

        init(detections: Binding<[DetectedPiece]>, statusText: Binding<String>) {
            self._detections = detections
            self._statusText = statusText
        }

        func setupCamera(in view: UIView) {
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
                  let input = try? AVCaptureDeviceInput(device: device) else {
                return
            }

            session.beginConfiguration()
            session.sessionPreset = .medium  // Lower res is fine for color sampling

            if session.canAddInput(input) {
                session.addInput(input)
            }

            let output = AVCaptureVideoDataOutput()
            output.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            output.alwaysDiscardsLateVideoFrames = true
            output.setSampleBufferDelegate(
                self,
                queue: DispatchQueue(label: "camera.queue", qos: .userInitiated)
            )

            if session.canAddOutput(output) {
                session.addOutput(output)
            }

            session.commitConfiguration()

            let preview = AVCaptureVideoPreviewLayer(session: session)
            preview.videoGravity = .resizeAspectFill
            view.layer.addSublayer(preview)
            previewLayer = preview
            configureVideoConnections()

            DispatchQueue.global(qos: .userInitiated).async {
                self.session.startRunning()
            }
        }

        func updateFrame(_ view: UIView) {
            previewLayer?.frame = view.bounds
            configureVideoConnections()
        }

        private func configureVideoConnections() {
            guard let orientation = currentVideoOrientation() else { return }

            if let previewConnection = previewLayer?.connection {
                if previewConnection.isVideoOrientationSupported {
                    previewConnection.videoOrientation = orientation
                }
                if previewConnection.isVideoMirroringSupported {
                    previewConnection.automaticallyAdjustsVideoMirroring = false
                    previewConnection.isVideoMirrored = false
                }
            }

            for connection in session.connections {
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = orientation
                }
                if connection.isVideoMirroringSupported {
                    connection.automaticallyAdjustsVideoMirroring = false
                    connection.isVideoMirrored = false
                }
            }
        }

        private func currentVideoOrientation() -> AVCaptureVideoOrientation? {
            switch UIDevice.current.orientation {
            case .landscapeLeft:
                return .landscapeRight
            case .landscapeRight:
                return .landscapeLeft
            case .portraitUpsideDown:
                return .portraitUpsideDown
            case .portrait:
                return .portrait
            default:
                return previewLayer?.connection?.videoOrientation ?? .landscapeRight
            }
        }

        func captureOutput(
            _ output: AVCaptureOutput,
            didOutput sampleBuffer: CMSampleBuffer,
            from connection: AVCaptureConnection
        ) {
            guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

            let components = extractColorComponents(from: buffer)
            let detectedPieces = components.compactMap(classifyComponent(_:))
            let sortedDetections = detectedPieces.sorted {
                if $0.colorName == $1.colorName {
                    return $0.shapeName < $1.shapeName
                }
                return $0.colorName < $1.colorName
            }

            DispatchQueue.main.async {
                self.detections = sortedDetections

                if sortedDetections.isEmpty {
                    self.statusText = "Searching for pieces"
                } else if sortedDetections.count == 1 {
                    self.statusText = "Detected 1 piece"
                } else {
                    self.statusText = "Detected \(sortedDetections.count) pieces"
                }
            }
        }

        private func extractColorComponents(from buffer: CVPixelBuffer) -> [GridComponent] {
            CVPixelBufferLockBaseAddress(buffer, .readOnly)
            defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }

            guard let baseAddress = CVPixelBufferGetBaseAddress(buffer) else { return [] }

            let width = CVPixelBufferGetWidth(buffer)
            let height = CVPixelBufferGetHeight(buffer)
            let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
            let bytes = baseAddress.assumingMemoryBound(to: UInt8.self)

            let roiMinX = Int(CGFloat(width) * roi.minX)
            let roiMaxX = Int(CGFloat(width) * (roi.minX + roi.width))
            let roiMinY = Int(CGFloat(height) * roi.minY)
            let roiMaxY = Int(CGFloat(height) * (roi.minY + roi.height))

            let roiWidth = max(roiMaxX - roiMinX, 1)
            let roiHeight = max(roiMaxY - roiMinY, 1)

            var colorGrid = Array(
                repeating: -1,
                count: sampleResolution * sampleResolution
            )

            for sampleY in 0..<sampleResolution {
                let pixelY = roiMinY + (sampleY * roiHeight / sampleResolution)

                for sampleX in 0..<sampleResolution {
                    let pixelX = roiMinX + (sampleX * roiWidth / sampleResolution)
                    let offset = (pixelY * bytesPerRow) + (pixelX * 4)

                    let blue = Double(bytes[offset]) / 255.0
                    let green = Double(bytes[offset + 1]) / 255.0
                    let red = Double(bytes[offset + 2]) / 255.0

                    let rgb = SIMD3(red, green, blue)
                    let index = sampleY * sampleResolution + sampleX
                    colorGrid[index] = colorIndex(for: rgb)
                }
            }

            return connectedComponents(in: colorGrid)
        }

        private func colorIndex(for rgb: SIMD3<Double>) -> Int {
            let brightness = max(rgb.x, max(rgb.y, rgb.z))
            let darkness = min(rgb.x, min(rgb.y, rgb.z))
            let saturation = brightness - darkness

            guard brightness > 0.18, saturation > 0.12 else {
                return -1
            }

            let tableDistance = distance(rgb, SIMD3<Double>(repeating: 0.86))
            guard tableDistance > 0.16 else {
                return -1
            }

            var bestIndex = -1
            var bestDistance = Double.greatestFiniteMagnitude

            for (index, profile) in colorProfiles.enumerated() {
                let candidateDistance = distance(rgb, profile.rgb)
                if candidateDistance < bestDistance {
                    bestDistance = candidateDistance
                    bestIndex = index
                }
            }

            return bestDistance < 0.34 ? bestIndex : -1
        }

        private func connectedComponents(in colorGrid: [Int]) -> [GridComponent] {
            var visited = Array(repeating: false, count: colorGrid.count)
            var components: [GridComponent] = []

            for y in 0..<sampleResolution {
                for x in 0..<sampleResolution {
                    let index = y * sampleResolution + x
                    let colorIndex = colorGrid[index]

                    guard colorIndex >= 0, !visited[index] else { continue }

                    var stack = [GridPoint(x: x, y: y)]
                    var points = Set<GridPoint>()
                    visited[index] = true

                    while let point = stack.popLast() {
                        points.insert(point)

                        let neighbors = [
                            GridPoint(x: point.x + 1, y: point.y),
                            GridPoint(x: point.x - 1, y: point.y),
                            GridPoint(x: point.x, y: point.y + 1),
                            GridPoint(x: point.x, y: point.y - 1)
                        ]

                        for neighbor in neighbors {
                            guard (0..<sampleResolution).contains(neighbor.x),
                                  (0..<sampleResolution).contains(neighbor.y) else {
                                continue
                            }

                            let neighborIndex = neighbor.y * sampleResolution + neighbor.x
                            guard !visited[neighborIndex],
                                  colorGrid[neighborIndex] == colorIndex else {
                                continue
                            }

                            visited[neighborIndex] = true
                            stack.append(neighbor)
                        }
                    }

                    guard points.count >= minimumComponentPixels else { continue }
                    components.append(
                        GridComponent(color: colorProfiles[colorIndex], points: points)
                    )
                }
            }

            return components
        }

        private func classifyComponent(_ component: GridComponent) -> DetectedPiece? {
            let normalizedMask = normalize(points: component.points, to: templateResolution)
            guard normalizedMask.count > 30 else { return nil }

            var bestShape: String?
            var bestScore = 0.0

            for (shapeName, variants) in pentominoTemplates {
                for variant in variants {
                    let score = intersectionOverUnion(lhs: normalizedMask, rhs: variant)
                    if score > bestScore {
                        bestScore = score
                        bestShape = shapeName
                    }
                }
            }

            guard let shapeName = bestShape, bestScore > 0.58 else {
                return nil
            }

            return DetectedPiece(
                id: "\(component.color.name)-\(shapeName)",
                shapeName: shapeName,
                colorName: component.color.name
            )
        }

        private func normalize(points: Set<GridPoint>, to resolution: Int) -> Set<GridPoint> {
            let xs = points.map(\.x)
            let ys = points.map(\.y)

            guard let minX = xs.min(),
                  let maxX = xs.max(),
                  let minY = ys.min(),
                  let maxY = ys.max() else {
                return []
            }

            let width = max(maxX - minX + 1, 1)
            let height = max(maxY - minY + 1, 1)
            let localPoints = Set(points.map { GridPoint(x: $0.x - minX, y: $0.y - minY) })
            let scale = Double(resolution) / Double(max(width, height))
            let scaledWidth = Double(width) * scale
            let scaledHeight = Double(height) * scale
            let xInset = (Double(resolution) - scaledWidth) / 2
            let yInset = (Double(resolution) - scaledHeight) / 2

            var normalized = Set<GridPoint>()

            for y in 0..<resolution {
                for x in 0..<resolution {
                    let sampleX = Double(x) + 0.5
                    let sampleY = Double(y) + 0.5

                    guard sampleX >= xInset,
                          sampleX < xInset + scaledWidth,
                          sampleY >= yInset,
                          sampleY < yInset + scaledHeight else {
                        continue
                    }

                    let localX = (sampleX - xInset) / scale
                    let localY = (sampleY - yInset) / scale
                    let sourceX = min(width - 1, max(0, Int(localX.rounded(.down))))
                    let sourceY = min(height - 1, max(0, Int(localY.rounded(.down))))

                    if localPoints.contains(GridPoint(x: sourceX, y: sourceY)) {
                        normalized.insert(GridPoint(x: x, y: y))
                    }
                }
            }

            return normalized
        }
    }
}

        private func intersectionOverUnion(lhs: Set<GridPoint>, rhs: Set<GridPoint>) -> Double {
            let intersection = lhs.intersection(rhs).count
            let union = lhs.union(rhs).count
            guard union > 0 else { return 0 }
            return Double(intersection) / Double(union)
        }

        private static func makePentominoTemplates(resolution: Int) -> [String: [Set<GridPoint>]] {
            let baseShapes: [String: [GridPoint]] = [
                "F": [GridPoint(x: 1, y: 0), GridPoint(x: 0, y: 1), GridPoint(x: 1, y: 1), GridPoint(x: 1, y: 2), GridPoint(x: 2, y: 2)],
                "I": [GridPoint(x: 0, y: 0), GridPoint(x: 1, y: 0), GridPoint(x: 2, y: 0), GridPoint(x: 3, y: 0), GridPoint(x: 4, y: 0)],
                "L": [GridPoint(x: 0, y: 0), GridPoint(x: 0, y: 1), GridPoint(x: 0, y: 2), GridPoint(x: 0, y: 3), GridPoint(x: 1, y: 3)],
                "N": [GridPoint(x: 0, y: 0), GridPoint(x: 0, y: 1), GridPoint(x: 1, y: 1), GridPoint(x: 1, y: 2), GridPoint(x: 1, y: 3)],
                "P": [GridPoint(x: 0, y: 0), GridPoint(x: 1, y: 0), GridPoint(x: 0, y: 1), GridPoint(x: 1, y: 1), GridPoint(x: 0, y: 2)],
                "T": [GridPoint(x: 0, y: 0), GridPoint(x: 1, y: 0), GridPoint(x: 2, y: 0), GridPoint(x: 1, y: 1), GridPoint(x: 1, y: 2)],
                "U": [GridPoint(x: 0, y: 0), GridPoint(x: 2, y: 0), GridPoint(x: 0, y: 1), GridPoint(x: 1, y: 1), GridPoint(x: 2, y: 1)],
                "V": [GridPoint(x: 0, y: 0), GridPoint(x: 0, y: 1), GridPoint(x: 0, y: 2), GridPoint(x: 1, y: 2), GridPoint(x: 2, y: 2)],
                "W": [GridPoint(x: 0, y: 0), GridPoint(x: 0, y: 1), GridPoint(x: 1, y: 1), GridPoint(x: 1, y: 2), GridPoint(x: 2, y: 2)],
                "X": [GridPoint(x: 1, y: 0), GridPoint(x: 0, y: 1), GridPoint(x: 1, y: 1), GridPoint(x: 2, y: 1), GridPoint(x: 1, y: 2)],
                "Y": [GridPoint(x: 0, y: 0), GridPoint(x: 0, y: 1), GridPoint(x: 0, y: 2), GridPoint(x: 0, y: 3), GridPoint(x: 1, y: 1)],
                "Z": [GridPoint(x: 0, y: 0), GridPoint(x: 1, y: 0), GridPoint(x: 1, y: 1), GridPoint(x: 2, y: 1), GridPoint(x: 3, y: 1)]
            ]

            return baseShapes.mapValues { cells in
                transformedVariants(of: cells).map { rasterize(cells: $0, resolution: resolution) }
            }
        }

        private static func transformedVariants(of cells: [GridPoint]) -> [[GridPoint]] {
            var variants = Set<[GridPoint]>()

            for mirror in [false, true] {
                for rotation in 0..<4 {
                    let transformed = canonicalize(
                        cells.map { point in
                            let mirroredX = mirror ? -point.x : point.x

                            switch rotation {
                            case 0:
                                return GridPoint(x: mirroredX, y: point.y)
                            case 1:
                                return GridPoint(x: -point.y, y: mirroredX)
                            case 2:
                                return GridPoint(x: -mirroredX, y: -point.y)
                            default:
                                return GridPoint(x: point.y, y: -mirroredX)
                            }
                        }
                    )

                    variants.insert(transformed)
                }
            }

            return Array(variants)
        }

        private static func canonicalize(_ cells: [GridPoint]) -> [GridPoint] {
            let minX = cells.map(\.x).min() ?? 0
            let minY = cells.map(\.y).min() ?? 0

            return cells
                .map { GridPoint(x: $0.x - minX, y: $0.y - minY) }
                .sorted {
                    if $0.y == $1.y {
                        return $0.x < $1.x
                    }
                    return $0.y < $1.y
                }
        }

        private static func rasterize(cells: [GridPoint], resolution: Int) -> Set<GridPoint> {
            let maxX = cells.map(\.x).max() ?? 0
            let maxY = cells.map(\.y).max() ?? 0
            let width = max(maxX + 1, 1)
            let height = max(maxY + 1, 1)
            let cellSet = Set(cells)
            let scale = Double(resolution) / Double(max(width, height))
            let scaledWidth = Double(width) * scale
            let scaledHeight = Double(height) * scale
            let xInset = (Double(resolution) - scaledWidth) / 2
            let yInset = (Double(resolution) - scaledHeight) / 2

            var occupied = Set<GridPoint>()

            for y in 0..<resolution {
                for x in 0..<resolution {
                    let sampleX = Double(x) + 0.5
                    let sampleY = Double(y) + 0.5

                    guard sampleX >= xInset,
                          sampleX < xInset + scaledWidth,
                          sampleY >= yInset,
                          sampleY < yInset + scaledHeight else {
                        continue
                    }

                    let localX = (sampleX - xInset) / scale
                    let localY = (sampleY - yInset) / scale
                    let cellX = min(width - 1, max(0, Int(localX.rounded(.down))))
                    let cellY = min(height - 1, max(0, Int(localY.rounded(.down))))

                    if cellSet.contains(GridPoint(x: cellX, y: cellY)) {
                        occupied.insert(GridPoint(x: x, y: y))
                    }
                }
            }

            return occupied
        }
    }
}

#Preview {
    CameraView()
}
