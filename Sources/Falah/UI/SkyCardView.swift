import SwiftUI

/// The pop-out card: header, arc, prayer list, footer.
struct SkyCardView: View {
    let model: CardModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let snapshot = model.snapshot, !model.isUnavailable {
                header(snapshot)
                ArcView(snapshot: snapshot)
                    .frame(height: 138)
                list(snapshot)
            } else {
                unavailable
            }
            Divider().opacity(0.6)
            footer
        }
        .padding(18)
        .frame(width: 360)
        // Sky colors replace this material in milestone 5.
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: Header

    private func header(_ snapshot: PrayerSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(snapshot.current?.prayer.displayName ?? snapshot.phase.title)
                .font(.system(size: 34, weight: .regular, design: .serif))
            HStack(spacing: 6) {
                if snapshot.current != nil {
                    Text("Now")
                        .fontWeight(.semibold)
                    Text("·").foregroundStyle(.secondary)
                }
                Text("\(snapshot.next.prayer.displayName) \(MenuBarText.longCountdown(to: snapshot.next.start, from: snapshot.now))")
                Text("·").foregroundStyle(.secondary)
                Text(time(snapshot.next.start))
                    .foregroundStyle(.secondary)
            }
            .font(.callout)
        }
    }

    // MARK: List

    private struct Row: Identifiable {
        let id: String
        let name: String
        let time: Date
        let color: Color
        let isCurrent: Bool
    }

    private func rows(_ snapshot: PrayerSnapshot) -> [Row] {
        let schedule = snapshot.schedule
        var rows = schedule.intervals.map { interval in
            Row(
                id: interval.prayer.rawValue,
                name: interval.prayer.displayName,
                time: interval.start,
                color: Color(nsColor: NSColor(SkyPalette.accent(for: interval.prayer.phase))),
                isCurrent: snapshot.current == interval
            )
        }
        rows.append(Row(
            id: "lastThird",
            name: "Last third",
            time: schedule.lastThird,
            color: Color(nsColor: NSColor(SkyPalette.accent(for: .isha))).opacity(0.6),
            isCurrent: false
        ))
        return rows
    }

    private func list(_ snapshot: PrayerSnapshot) -> some View {
        VStack(spacing: 2) {
            ForEach(rows(snapshot)) { row in
                HStack(spacing: 10) {
                    Circle()
                        .fill(row.color)
                        .overlay(Circle().strokeBorder(.primary.opacity(0.15), lineWidth: 0.5))
                        .frame(width: 9, height: 9)
                    Text(row.name)
                        .fontWeight(row.isCurrent ? .semibold : .regular)
                    Spacer()
                    Text(time(row.time))
                        .monospacedDigit()
                        .fontWeight(row.isCurrent ? .semibold : .regular)
                }
                .font(row.id == "lastThird" ? .callout : .body)
                .foregroundStyle(row.id == "lastThird" ? .secondary : .primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background {
                    if row.isCurrent {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(.primary.opacity(0.08))
                    }
                }
            }
        }
    }

    // MARK: Footer / states

    private var footer: some View {
        HStack {
            Text(model.footerText)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button(action: model.onSettings) {
                Image(systemName: "gearshape")
            }
            .help("Settings")
            Button(action: model.onQuit) {
                Image(systemName: "power")
            }
            .help("Quit Falah")
        }
        .buttonStyle(.borderless)
    }

    private var unavailable: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Prayer times unavailable")
                .font(.system(size: 22, design: .serif))
            Text("Times can't be calculated for this location and date. Try a different location or high-latitude rule in Settings.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func time(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
}
