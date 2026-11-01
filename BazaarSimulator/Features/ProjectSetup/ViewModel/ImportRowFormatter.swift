import Foundation

struct PlanRowDisplay: Equatable, Sendable, Identifiable {
    enum Status: Equatable, Sendable {
        case done(text: String)
        case reading(progress: Double?)
        case waiting(text: String)
        case failed(message: String)
        case cancelled(text: String)
    }

    let id: UUID
    let title: String
    let subtitle: String
    let status: Status
    let hasThumbnail: Bool
    let thumbnailData: Data?

    var isReading: Bool {
        if case .reading = status { return true }
        return false
    }

    init(
        id: UUID,
        title: String,
        subtitle: String,
        status: Status,
        hasThumbnail: Bool = false,
        thumbnailData: Data? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.status = status
        self.hasThumbnail = hasThumbnail
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
        let title = file.url.lastPathComponent
        let sub = subtitle(layoutIndex: layoutIndex, byteCount: file.fileSize, locale: locale)

        let status: PlanRowDisplay.Status
        switch file.state {
        case .waiting:
            status = .waiting(text: "Waiting...")
        case .reading(let progress):
            status = .reading(progress: progress)
        case .done(let booths, let doors):
            status = .done(text: doneText(booths: booths, doors: doors))
        case .failed(let message):
            status = .failed(message: message)
        case .cancelled:
            status = .cancelled(text: "Cancelled")
        }

        return PlanRowDisplay(
            id: file.id,
            title: title,
            subtitle: sub,
            status: status,
            hasThumbnail: file.thumbnailData != nil,
            thumbnailData: file.thumbnailData
        )
    }

    static func formatLegendRow(file: ImportFile, locale: Locale = .current) -> PlanRowDisplay {
        let title = file.url.lastPathComponent
        let formattedBytes = formatByteCount(file.fileSize, locale: locale)
        let sub = "Legend · \(formattedBytes)"

        let status: PlanRowDisplay.Status
        switch file.state {
        case .waiting:
            status = .waiting(text: "Waiting...")
        case .reading(let progress):
            status = .reading(progress: progress)
        case .done:
            status = .done(text: "✓ Done")
        case .failed(let message):
            status = .failed(message: message)
        case .cancelled:
            status = .cancelled(text: "Cancelled")
        }

        return PlanRowDisplay(
            id: file.id,
            title: title,
            subtitle: sub,
            status: status,
            hasThumbnail: file.thumbnailData != nil,
            thumbnailData: file.thumbnailData
        )
    }
}
