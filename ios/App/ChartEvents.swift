import AstroCore
import Foundation

/// Upcoming astronomical events derived from the bundled ephemeris and used by
/// timeline, gantt and season cards. Every date is calculated, never invented.
struct ChartEventData: Equatable {
    var skyIngresses: [SkyIngress] = []
    var skyExactEvents: [SkyExactEvent] = []
    var transitWindows: [TransitWindow] = []
    var progressedMoon: ProgressedMoonWindow?
    var progressedTurningPoints: [ProgressedTurningPoint] = []
    var solarSeasons: [SolarSeason] = []
    var solarYearStart: Date?

    static let empty = ChartEventData()

    struct SkyIngress: Equatable {
        let body: CelestialBody
        let signIndex: Int
        let date: Date
        let nextDate: Date?
    }

    struct SkyExactEvent: Equatable {
        let first: CelestialBody
        let second: CelestialBody
        let kind: AspectKind
        let date: Date
    }

    struct TransitWindow: Equatable {
        let first: CelestialBody
        let second: CelestialBody
        let kind: AspectKind
        let firstLongitude: Double
        let start: Date
        let exact: Date
        let end: Date
        let nextExact: Date?
    }

    struct ProgressedMoonWindow: Equatable {
        let signIndex: Int
        let daysInSign: Int
        let nextIngress: Date
    }

    struct ProgressedTurningPoint: Equatable {
        let first: CelestialBody
        let second: CelestialBody
        let kind: AspectKind
        let exactDate: Date?
        let separationDegrees: Double
        let phase: AspectPhase
    }

    struct SolarSeason: Equatable {
        let index: Int
        let start: Date
        let end: Date
    }
}

/// Builds `ChartEventData` from the already-computed snapshots. This runs on the
/// main refresh path so the cards are ready the moment the chart is shown.
enum ChartEventBuilder {
    static func build(
        calculator: SwissEphemerisCalculator,
        now: Date,
        birthDate: Date,
        location: GeographicLocation,
        skySnapshot: ChartSnapshot,
        skyPreset: CalculationPreset,
        transitMoving: ChartSnapshot,
        transitAspects: [ChartAspect],
        progressedSnapshot: ChartSnapshot,
        progressedAspects: [ChartAspect],
        solarReturnMoment: Date?
    ) async throws -> ChartEventData {
        var data = ChartEventData()

        // 1. Sky sign changes: next ingresses of the fast-moving bodies,
        //    keeping at most two Moon rows so the card stays varied.
        let ingressBodies: [CelestialBody] = [.moon, .mercury, .venus, .sun, .mars]
        var pending: [(body: CelestialBody, date: Date)] = []
        for body in ingressBodies {
            if let date = try? await calculator.nextSignIngress(for: body, after: now) {
                pending.append((body, date))
            }
        }
        pending.sort { $0.date < $1.date }
        var moonRows = 0
        for item in pending {
            guard data.skyIngresses.count < 4 else { break }
            if item.body == .moon, moonRows >= 2 { continue }
            if item.body == .moon { moonRows += 1 }
            let snapshot = try await calculator.calculateSnapshot(
                NatalInput(utcDate: item.date, location: location),
                preset: skyPreset
            )
            let signIndex = snapshot.point(item.body)?.signIndex ?? 0
            let nextDate = (try? await calculator.nextSignIngress(for: item.body, after: item.date))
            data.skyIngresses.append(
                ChartEventData.SkyIngress(body: item.body, signIndex: signIndex, date: item.date, nextDate: nextDate)
            )
        }

        // 2. Sky exact events within the next 7 days, from the aspects already
        //    within orb in the current sky.
        var exactEvents: [ChartEventData.SkyExactEvent] = []
        for aspect in skySnapshot.aspects.prefix(8) {
            guard let first = CelestialBody(rawValue: aspect.firstID),
                  let second = CelestialBody(rawValue: aspect.secondID),
                  let date = try? await calculator.nextSkyExactDate(
                      moving: first,
                      reference: second,
                      kind: aspect.kind,
                      after: now
                  ),
                  date.timeIntervalSince(now) <= 7 * 86_400
            else { continue }
            exactEvents.append(
                ChartEventData.SkyExactEvent(first: first, second: second, kind: aspect.kind, date: date)
            )
        }
        exactEvents.sort { $0.date < $1.date }
        data.skyExactEvents = Array(exactEvents.prefix(3))

        // 3. Transit windows for the strongest active transits: the exact peak
        //    plus the in-orb start and end dates.
        for aspect in transitAspects.prefix(6) {
            guard let first = CelestialBody(rawValue: aspect.firstID),
                  let second = CelestialBody(rawValue: aspect.secondID)
            else { continue }
            let speed = transitMoving.point(first)?.position.longitudeSpeedDegreesPerDay ?? 0
            let absSpeed = max(abs(speed), 0.02)
            let separation = aspect.orbDegrees
            let effectiveOrb = aspect.strength >= 0.999
                ? max(separation, 0.5)
                : separation / max(1 - aspect.strength, 0.05)
            let exact: Date
            switch aspect.phase {
            case .applying:
                exact = (try? await calculator.nextTransitNatalExactDate(
                    moving: first,
                    natalReferenceLongitude: aspect.secondLongitude,
                    kind: aspect.kind,
                    after: now
                )) ?? now.addingTimeInterval(separation / absSpeed * 86_400)
            case .exact:
                exact = now
            case .separating:
                exact = now.addingTimeInterval(-(separation / absSpeed) * 86_400)
            }
            let halfWindow = effectiveOrb / absSpeed * 86_400
            let nextExact: Date?
            if exact.timeIntervalSince(now) >= 0 {
                nextExact = exact
            } else {
                nextExact = try? await calculator.nextTransitNatalExactDate(
                    moving: first,
                    natalReferenceLongitude: aspect.secondLongitude,
                    kind: aspect.kind,
                    after: exact.addingTimeInterval(0.1 * 86_400)
                )
            }
            data.transitWindows.append(
                ChartEventData.TransitWindow(
                    first: first,
                    second: second,
                    kind: aspect.kind,
                    firstLongitude: aspect.firstLongitude,
                    start: exact.addingTimeInterval(-halfWindow),
                    exact: exact,
                    end: exact.addingTimeInterval(halfWindow),
                    nextExact: nextExact
                )
            )
        }

        // 4. Progressed Moon: how long it has already been in the current sign
        //    and when it next changes sign.
        if let moon = progressedSnapshot.point(.moon),
           let window = try? await calculator.progressionWindow(
               moving: .moon,
               at: progressedSnapshot.utcDate,
               signLabel: ""
           )
        {
            data.progressedMoon = ChartEventData.ProgressedMoonWindow(
                signIndex: moon.signIndex,
                daysInSign: Int(window.daysInSign.rounded()),
                nextIngress: window.ingressDate
            )
        }

        // 5. Progressed turning points: upcoming exact contacts with real months.
        for aspect in progressedAspects.prefix(3) {
            guard let first = CelestialBody(rawValue: aspect.firstID),
                  let second = CelestialBody(rawValue: aspect.secondID)
            else { continue }
            let exactDate: Date?
            switch aspect.phase {
            case .applying:
                exactDate = try? await calculator.nextProgressedNatalExactDate(
                    moving: first,
                    natalReferenceLongitude: aspect.secondLongitude,
                    kind: aspect.kind,
                    birthDate: birthDate,
                    after: now,
                    maxYears: 8
                )
            case .exact:
                exactDate = now
            case .separating:
                exactDate = nil
            }
            data.progressedTurningPoints.append(
                ChartEventData.ProgressedTurningPoint(
                    first: first,
                    second: second,
                    kind: aspect.kind,
                    exactDate: exactDate,
                    separationDegrees: aspect.orbDegrees,
                    phase: aspect.phase
                )
            )
        }

        // 6. Solar return seasons: four three-month phases from the return moment.
        if let moment = solarReturnMoment {
            data.solarYearStart = moment
            let calendar = Calendar(identifier: .gregorian)
            for index in 0 ..< 4 {
                let start = calendar.date(byAdding: .month, value: index * 3, to: moment) ?? moment
                let end = calendar.date(byAdding: .month, value: (index + 1) * 3, to: moment) ?? moment
                data.solarSeasons.append(ChartEventData.SolarSeason(index: index, start: start, end: end))
            }
        }

        return data
    }
}

// MARK: - Consumer date formatting

extension Date {
    /// Short event label such as "Aug 2" / "8月2日".
    func shortEventDate(language: AppLanguage, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = language == .english ? Locale(identifier: "en_US") : Locale(identifier: "zh_CN")
        formatter.timeZone = timeZone
        formatter.dateFormat = language == .english ? "MMM d" : "M月d日"
        return formatter.string(from: self)
    }

    /// Month-year label such as "Sep 2026" / "2026年9月".
    func shortEventMonthYear(language: AppLanguage, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = language == .english ? Locale(identifier: "en_US") : Locale(identifier: "zh_CN")
        formatter.timeZone = timeZone
        formatter.dateFormat = language == .english ? "MMM yyyy" : "yyyy年M月"
        return formatter.string(from: self)
    }

    /// Compact range such as "Jul 18–Nov 6" / "7月18日–11月6日".
    func shortEventRange(to end: Date, language: AppLanguage, timeZone: TimeZone = .current) -> String {
        "\(shortEventDate(language: language, timeZone: timeZone))–\(end.shortEventDate(language: language, timeZone: timeZone))"
    }
}
