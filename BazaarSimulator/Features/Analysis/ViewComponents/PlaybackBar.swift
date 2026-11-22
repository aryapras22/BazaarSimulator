import SwiftUI

/// Where playback is. Time is seconds of playback, which the view model turns into a time in the window.
struct PlaybackClock {
    static let speeds: [Double] = [1, 2, 4]

    let duration: Double
    private(set) var isRunning = false
    private(set) var speed: Double = 1
    private var anchorTime: Double = 0
    private var anchorDate = Date()

    init(duration: Double) {
        self.duration = duration
    }

    func time(at date: Date) -> Double {
        guard isRunning else { return anchorTime }
        return min(anchorTime + date.timeIntervalSince(anchorDate) * speed, duration)
    }

    mutating func play(from date: Date = Date()) {
        if anchorTime >= duration { anchorTime = 0 }
        anchorDate = date
        isRunning = true
    }

    mutating func pause(at date: Date = Date()) {
        anchorTime = time(at: date)
        isRunning = false
    }

    mutating func setSpeed(_ newSpeed: Double, at date: Date = Date()) {
        anchorTime = time(at: date)
        anchorDate = date
        speed = newSpeed
    }

    mutating func seek(to newTime: Double, at date: Date = Date()) {
        anchorTime = min(max(newTime, 0), duration)
        anchorDate = date
    }
}

struct PlaybackBar: View {
    static let width: CGFloat = 560
    static let height: CGFloat = 58.5

    @Binding var clock: PlaybackClock
    let time: Double
    /// Total simulated event duration in seconds (e.g., 11 hours = 39,600 seconds).
    var eventDurationSeconds: Double = 39_600

    var body: some View {
        let finished = time >= clock.duration
        let isPlaying = clock.isRunning && !finished
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        let progress = clock.duration > 0 ? min(max(time / clock.duration, 0), 1) : 0
        let elapsedSimSeconds = progress * eventDurationSeconds
        let elapsedLabel = Self.formatDuration(elapsedSimSeconds)
        let totalLabel = Self.formatDuration(eventDurationSeconds)

        HStack(spacing: 14) {
            Button {
                if isPlaying { clock.pause() } else { clock.play() }
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : finished ? "arrow.counterclockwise" : "play.fill")
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(.black)
                    .frame(width: 33, height: 33)
                    .background(Circle().fill(Color.white.opacity(0.14)))
                    .overlay { Circle().strokeBorder(Color.white.opacity(0.22), lineWidth: 1) }
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.space, modifiers: [])
            .help(isPlaying ? "Pause (Space)" : "Play (Space)")
            .accessibilityLabel(isPlaying ? "Pause" : "Play")

            Slider(
                value: Binding(
                    get: { min(max(time, 0), clock.duration) },
                    set: { clock.seek(to: $0) }
                ),
                in: 0...max(clock.duration, 1)
            )
            .tint(Palette.accent)
            .frame(maxWidth: .infinity)
            .help("Scrub simulation timeline")

            Text("\(elapsedLabel) / \(totalLabel)")
                .font(.system(size: 13, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(.white)
                .fixedSize()
                .help("Simulated event duration")
                .accessibilityLabel("Played \(elapsedLabel) of \(totalLabel)")

            Menu {
                ForEach(PlaybackClock.speeds, id: \.self) { speed in
                    Button(Self.speedLabel(speed)) { clock.setSpeed(speed) }
                }
            } label: {
                HStack(spacing: 0) {
                    Text(Self.speedLabel(clock.speed))
                        .font(.system(size: 15))
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 10)
                .frame(width: 53, height: 31)
                .background {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.white.opacity(0.22))
                        .overlay {
                            RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
                        }
                }
            }
            .menuStyle(.button)
            .menuIndicator(.hidden)
            .buttonStyle(.plain)
            .fixedSize()
            .help("Playback speed")
        }
        .padding(.leading, 20)
        .padding(.trailing, 20)
        .frame(width: Self.width, height: Self.height)
        .background {
            shape
                .fill(Color(hex: 0xA2AFC2).opacity(0.55))
                .overlay { shape.strokeBorder(Color.white.opacity(0.3), lineWidth: 1) }
                .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
        }
    }

    static func format(_ seconds: Double) -> String {
        let whole = Int(seconds)
        return String(format: "%02d:%02d", whole / 60, whole % 60)
    }

    static func formatDuration(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, secs)
    }

    static func speedLabel(_ speed: Double) -> String {
        "\(Int(speed))x"
    }
}
