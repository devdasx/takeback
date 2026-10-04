import SwiftUI

/// SF Symbol mark; its screen-specific size and treatment belong to later prompts.
struct AppLogo: View {
    var size: CGFloat = 40
    var foreground: Color = Theme.fg
    var body: some View {
        Image(systemName: "arrow.uturn.backward")
            .font(.system(size: size, weight: .medium)).foregroundStyle(foreground)
            .accessibilityLabel("Takeback")
    }
}

struct StatusChip: View {
    enum Status { case pending, success, error }
    let title: String
    let status: Status
    var resultStyle = false
    private var color: Color {
        switch status { case .pending: Theme.amber; case .success: Theme.green; case .error: Theme.red }
    }
    var body: some View {
        HStack(spacing: 10) {
            Circle().fill(color.opacity(resultStyle ? 0.18 : 0.12)).frame(width: 18, height: 18)
                .overlay { Circle().fill(color).frame(width: resultStyle ? 8 : 6, height: resultStyle ? 8 : 6) }
                .accessibilityHidden(true)
            Text(title).font(Geist.font(13, resultStyle ? .semibold : .medium))
                .foregroundStyle(status == .pending ? Theme.amberText : color)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(status == .pending ? Theme.amberBackground : Theme.card, in: Capsule())
        .overlay { Capsule().stroke(status == .pending ? Theme.amberBorder : Theme.line, lineWidth: 1) }
        .accessibilityElement(children: .combine)
    }
}

struct NoteCard: View {
    let symbol: String
    let text: String
    var title: String? = nil
    var titleSize: CGFloat = 13
    var titleWeight: Geist.Weight = .semibold
    var textColor: Color = Theme.fg
    var footer: AnyView? = nil
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol).font(.system(size: 20)).foregroundStyle(Theme.mute)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                if let title {
                    Text(title).font(Geist.font(titleSize, titleWeight))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(text).font(Geist.font(13)).foregroundStyle(textColor).fixedSize(horizontal: false, vertical: true)
                if let footer { footer }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct WarningCard: View {
    let text: String
    var title: String? = nil
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle").font(.system(size: 20)).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                if let title { Text(title).font(Geist.font(13, .semibold)).fixedSize(horizontal: false, vertical: true) }
                Text(text).font(Geist.font(13)).fixedSize(horizontal: false, vertical: true)
            }
        }
        .foregroundStyle(Theme.amberText)
        .frame(maxWidth: .infinity, alignment: .leading).padding(16)
        .background(Theme.amberBackground, in: RoundedRectangle(cornerRadius: 16))
        .overlay { RoundedRectangle(cornerRadius: 16).stroke(Theme.amberBorder, lineWidth: 1) }
    }
}

struct ProgressBar: View {
    let progress: CGFloat
    private var fraction: CGFloat { progress.isFinite ? min(1, max(0, progress)) : 0 }
    var body: some View {
        GeometryReader { geometry in
            Capsule().fill(Theme.line)
                .overlay(alignment: .leading) {
                    Capsule().fill(Theme.fg).frame(width: geometry.size.width * fraction)
                }
        }
        .frame(height: 4)
        .accessibilityLabel("Progress")
        .accessibilityValue(Text(fraction, format: .percent.precision(.fractionLength(0))))
    }
}

struct Spinner: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            let turns = timeline.date.timeIntervalSinceReferenceDate / 0.8
            Circle().stroke(Theme.fg.opacity(0.2), lineWidth: 2)
                .overlay {
                    Circle().trim(from: 0, to: 0.25).stroke(Theme.fg, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .rotationEffect(.degrees(reduceMotion ? -90 : turns.truncatingRemainder(dividingBy: 1) * 360))
                }
        }
        .frame(width: 32, height: 32).accessibilityLabel("Loading")
    }
}
