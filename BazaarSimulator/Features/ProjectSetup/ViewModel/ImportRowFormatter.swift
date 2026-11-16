import Foundation

struct PlanRowDisplay: Equatable, Sendable, Identifiable {
    enum Status: Equatable, Sendable {
        case done(text: String)
        case reading(progress: Double?, step: String = "Reading...")
        case waiting(text: String)
        case failed(message: String)
        case cancelled(text: String)
    }

    let id: UUID
    let title: String
    let subtitle: String
    let status: Status
    let thumbnailData: Data?

    var isReading: Bool {
        if case .reading = status { return true }
        return false
    }

    var isDone: Bool {
        if case .done = status { return true }
        return false
    }

    init(
        id: UUID,
        title: String,
        subtitle: String,
        status: Status,
        thumbnailData: Data? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.status = status
        self.thumbnailData = thumbnailData
    }
}

enum ImportRowFormatter {
    static func formatByteCount(_ bytes: Int64, locale: Locale = .current) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1

        let megaBytes = Double(bytes) / 1_000_000.0
        if let formattedNumber = formatter.string(from: NSNumber(value: megaBytes)) {
            return "\(formattedNumber) MB"
        }
        return "\(megaBytes) MB"
    }

    static func subtitle(layoutIndex: Int, byteCount: Int64, locale: Locale = .current) -> String {
        let formattedBytes = formatByteCount(byteCount, locale: locale)
        return "Layout \(layoutIndex) · \(formattedBytes)"
    }

    static func boothsAndDoorsText(booths: Int, doors: Int) -> String {
        let boothText = booths == 1 ? "1 booth" : "\(booths) booths"
        let doorText = doors == 1 ? "1 door" : "\(doors) doors"
        return "\(boothText) · \(doorText)"
    }

    static func doneText(booths: Int, doors: Int) -> String {
        "✓ \(boothsAndDoorsText(booths: booths, doors: doors))"
    }

    static func formatRow(file: ImportFile, layoutIndex: Int, locale: Locale = .current) -> PlanRowDisplay {
        PlanRowDisplay(
            id: file.id,
            title: file.url.lastPathComponent,
            subtitle: subtitle(layoutIndex: layoutIndex, byteCount: file.fileSize, locale: locale),
            status: status(for: file.state, doneText: doneText),
            thumbnailData: file.thumbnailData
        )
    }

    static func formatLegendRow(file: ImportFile, locale: Locale = .current) -> PlanRowDisplay {
        let formattedBytes = formatByteCount(file.fileSize, locale: locale)
        return PlanRowDisplay(
            id: file.id,
            title: file.url.lastPathComponent,
            subtitle: "Legend · \(formattedBytes)",
            status: status(for: file.state, doneText: { _, _ in "✓ Done" }),
            thumbnailData: file.thumbnailData
        )
    }

    private static func status(
        for state: ImportFileState,
        doneText: (Int, Int) -> String
    ) -> PlanRowDisplay.Status {
        switch state {
        case .waiting:
            return .waiting(text: "Waiting...")
        case .reading(let progress, let step):
            return .reading(progress: progress, step: step ?? "Reading...")
        case .done(let booths, let doors):
            return .done(text: doneText(booths, doors))
        case .failed(let message):
            return .failed(message: message)
        case .cancelled:
            return .cancelled(text: "Cancelled")
        }
    }
}
