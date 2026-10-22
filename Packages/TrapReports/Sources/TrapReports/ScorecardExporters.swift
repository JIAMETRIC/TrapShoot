import SwiftUI
import UIKit
import TrapCore

/// PNG at 2× for sharing to messages and photos. Call from the main actor (exports start from screens).
public struct ScorecardImageExporter: DocumentExporter {
    public typealias Input = Round
    public let format = ExportFormat.png
    let breakModel: BreakDistanceModel
    let appVersion: String
    public var scale: CGFloat = 2
    public init(breakModel: BreakDistanceModel, appVersion: String) { self.breakModel = breakModel; self.appVersion = appVersion }

    public func filename(for r: Round) -> String { Exporters.reportBase(for: r) + "-scorecard.png" }
    public func data(for r: Round) throws -> Data {
        try MainActor.assumeIsolated {
            let renderer = ImageRenderer(content: ScorecardView(round: r, breakModel: breakModel, appVersion: appVersion))
            renderer.scale = scale
            renderer.proposedSize = ProposedViewSize(ScorecardView.pageSize)
            guard let image = renderer.uiImage, let png = image.pngData() else { throw ExportError.renderFailed }
            return png
        }
    }
}

/// A4 PDF with vector text (selectable, crisp at any zoom), one page per round. Call from the main actor.
public struct ScorecardPDFExporter: DocumentExporter {
    public typealias Input = Round
    public let format = ExportFormat.pdf
    let breakModel: BreakDistanceModel
    let appVersion: String
    public init(breakModel: BreakDistanceModel, appVersion: String) { self.breakModel = breakModel; self.appVersion = appVersion }

    public func filename(for r: Round) -> String { Exporters.reportBase(for: r) + "-scorecard.pdf" }
    public func data(for r: Round) throws -> Data {
        try MainActor.assumeIsolated { try render(r) }
    }

    private func render(_ r: Round) throws -> Data {
        var box = CGRect(origin: .zero, size: ScorecardView.pageSize)
        let data = NSMutableData()
        let info: [CFString: Any] = [kCGPDFContextTitle: "TrapShooterPro scorecard \(r.sessionId)", kCGPDFContextCreator: "TrapShooterPro \(appVersion)"]
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let pdf = CGContext(consumer: consumer, mediaBox: &box, info as CFDictionary) else { throw ExportError.renderFailed }
        let renderer = ImageRenderer(content: ScorecardView(round: r, breakModel: breakModel, appVersion: appVersion))
        renderer.proposedSize = ProposedViewSize(ScorecardView.pageSize)
        // Apple's documented pattern: ImageRenderer draws into a Core Graphics PDF page with vector text.
        renderer.render { _, draw in
            pdf.beginPDFPage(nil)
            draw(pdf)
            pdf.endPDFPage()
        }
        pdf.closePDF()
        guard data.length > 0 else { throw ExportError.renderFailed }
        return data as Data
    }
}
