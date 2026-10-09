import SwiftUI

/// The pop-out card: header with countdown and progress, sun path, prayer list, footer.
/// Sits on a sky gradient that follows the time of day.
struct SkyCardView: View {
    let model: CardModel
    @Namespace private var highlight

    var body: some View {
        Group {
            if let snapshot = model.snapshot, model.problem == nil {
                content(snapshot)
            } else {
                unavailable(model.problem ?? .locating)
            }
        }
        .frame(width: 360)
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func content(_ snapshot: PrayerSnapshot) -> some View {
        let sky = SkyPalette.sky(at: snapshot.now, schedule: snapshot.schedule)
        let accent = color(SkyPalette.accent(for: snapshot.phase))
        return VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 18) {
                header(snapshot, accent: accent)
                progress(snapshot, accent: accent)
                ArcView(snapshot: snapshot, accent: accent)
                    .frame(height: 150)
                list(snapshot)
                lastThird(snapshot)
            }
            .padding(.horizontal, 22)
            .padding(.top, 22)
            .padding(.bottom, 16)
            footer
        }
        .background(SkyBackground(sky: sky))
        .animation(.easeInOut(duration: 1.2), value: sky)
        .animation(.easeInOut(duration: 0.4), value: snapshot.current?.prayer)
    }

    // MARK: Header

    private func header(_ snapshot: PrayerSnapshot, accent: Color) -> some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text("NOW")
                    .font(.caption.weight(.semibold))
                    .tracking(1.2)
                    .opacity(0.7)
                Text(snapshot.current?.prayer.displayName ?? snapshot.phase.title)
                    .font(.system(size: 40, weight: .bold, design: .serif))
                    .contentTransition(.opacity)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 12)
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(snapshot.next.prayer.displayName) in")
                    .font(.callout)
                    .opacity(0.85)
                Text(countdown(snapshot))
                    .font(.system(size: 28, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(accent)
            }
        }
    }

    private func countdown(_ snapshot: PrayerSnapshot) -> String {
        // "32 min", "1 hr 31 min"
        String(MenuBarText.longCountdown(to: snapshot.next.start, from: snapshot.now).dropFirst(3))
    }

    // MARK: Progress

    /// The current window: the current prayer until the next one, or sunrise → Dhuhr.
    private func window(_ snapshot: PrayerSnapshot) -> (start: Date, end: Date) {
        if let current = snapshot.current {
            return (current.start, current.end)
        }
        return (snapshot.schedule.sunrise, snapshot.next.start)
    }

    private func progress(_ snapshot: PrayerSnapshot, accent: Color) -> some View {
        let (start, end) = window(snapshot)
        let total = end.timeIntervalSince(start)
        let fraction = total > 0 ? max(0, min(1, snapshot.now.timeIntervalSince(start) / total)) : 0
        return VStack(spacing: 6) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.18))
                    Capsule().fill(accent).frame(width: proxy.size.width * fraction)
                }
            }
            .frame(height: 5)
            HStack {
                Text(time(start))
                Spacer()
                Text(time(end))
            }
            .font(.caption)
            .opacity(0.75)
        }
    }

    // MARK: List

    private func list(_ snapshot: PrayerSnapshot) -> some View {
        let schedule = snapshot.schedule
        return VStack(spacing: 4) {
            ForEach(schedule.intervals, id: \.prayer) { interval in
                let isCurrent = snapshot.current == interval
                let isNext = snapshot.next == interval
                let isPast = !isCurrent && interval.end <= snapshot.now
                HStack(spacing: 12) {
                    Circle()
                        .fill(color(SkyPalette.accent(for: interval.prayer.phase)))
                        .frame(width: 8, height: 8)
                    Text(interval.prayer.displayName)
                        .fontWeight(isCurrent ? .bold : .medium)
                    if isNext {
                        Text("NEXT")
                            .font(.caption2.weight(.bold))
                            .tracking(0.8)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(.white.opacity(0.16)))
                    }
                    Spacer()
                    Text(isCurrent ? MenuBarText.timeRange(interval.start, interval.end) : time(interval.start))
                        .fontWeight(isCurrent ? .bold : .medium)
                        .monospacedDigit()
                }
                .font(.system(size: 15))
                .opacity(isPast ? 0.5 : 1)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background {
                    if isCurrent {
                        // Slides to the new row when a prayer begins.
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(.white.opacity(0.10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(.white.opacity(0.22), lineWidth: 1)
                            )
                            .matchedGeometryEffect(id: "current", in: highlight)
                    }
                }
            }
        }
        .padding(.horizontal, -12)
        .animation(.spring(response: 0.55, dampingFraction: 0.85), value: snapshot.current?.prayer)
    }

    private func lastThird(_ snapshot: PrayerSnapshot) -> some View {
        VStack(spacing: 12) {
            Rectangle().fill(.white.opacity(0.15)).frame(height: 1)
            HStack {
                Text("Last third of the night")
                Spacer()
                Text(time(snapshot.schedule.lastThird))
                    .monospacedDigit()
            }
            .font(.callout)
            .opacity(0.8)
        }
    }

    // MARK: Footer / states

    private var footer: some View {
        HStack {
            Text(model.footerText)
                .font(.caption)
                .opacity(0.85)
            Spacer()
            Button(action: model.onSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 13))
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.white.opacity(0.85))
            .help("Settings")
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .background(.black.opacity(0.22))
    }

    private func unavailable(_ problem: CardProblem) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text(problem.title)
                    .font(.system(size: 24, weight: .bold, design: .serif))
                Text(problem.message)
                    .font(.callout)
                    .opacity(0.8)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Open Settings", action: model.onSettings)
                    .buttonStyle(.bordered)
                    .padding(.top, 4)
            }
            .padding(22)
            footer
        }
        .background(SkyBackground(sky: SkyPalette.gradient(for: .night)))
    }

    private func time(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    private func color(_ rgb: RGB) -> Color {
        Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
    }
}

/// Vertical sky gradient with a few stars that fade in at night.
struct SkyBackground: View {
    let sky: SkyGradient

    /// Fixed star positions (unit coordinates, size) so they don't jump between renders.
    private static let stars: [(x: CGFloat, y: CGFloat, r: CGFloat)] = [
        (0.08, 0.05, 1.2), (0.22, 0.12, 0.8), (0.37, 0.03, 1.0), (0.55, 0.09, 0.7),
        (0.71, 0.04, 1.3), (0.88, 0.11, 0.9), (0.15, 0.22, 0.7), (0.63, 0.19, 1.0),
        (0.93, 0.26, 0.8), (0.46, 0.27, 0.6), (0.79, 0.33, 0.7), (0.05, 0.36, 0.9),
    ]

    var body: some View {
        ZStack {
            LinearGradient(colors: [color(sky.top), color(sky.bottom)], startPoint: .top, endPoint: .bottom)
            if sky.stars > 0 {
                Canvas { context, size in
                    for star in Self.stars {
                        let rect = CGRect(x: star.x * size.width, y: star.y * size.height, width: star.r * 2, height: star.r * 2)
                        context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.7)))
                    }
                }
                .opacity(sky.stars)
            }
        }
    }

    private func color(_ rgb: RGB) -> Color {
        Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
    }
}
