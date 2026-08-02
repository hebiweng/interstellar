import AstroCore
import Foundation

/// Upcoming astronomical events derived from the bundled ephemeris and used by
/// timeline, gantt and season cards. Every date is calculated, never invented.
struct ChartEventData: Equatable, Codable {
    var skyIngresses: [SkyIngress] = []
    var skyExactEvents: [SkyExactEvent] = []
    var skyStations: [SkyStation] = []
    var transitWindows: [TransitWindow] = []
    var progressedMoon: ProgressedMoonWindow?
    var progressedTurningPoints: [ProgressedTurningPoint] = []
    var solarSeasons: [SolarSeason] = []
    var solarYearStart: Date?

    static let empty = ChartEventData()

    struct SkyIngress: Equatable, Codable {
        let body: CelestialBody
        let signIndex: Int
        let date: Date
        let nextDate: Date?
    }

    struct SkyExactEvent: Equatable, Codable {
        let first: CelestialBody
        let second: CelestialBody
        let kind: AspectKind
        let date: Date
    }

    struct SkyStation: Equatable, Codable {
        let body: CelestialBody
        let date: Date
        let retrogradeAfter: Bool
    }

    struct TransitWindow: Equatable, Codable {
        let first: CelestialBody
        let second: CelestialBody
        let kind: AspectKind
        let firstLongitude: Double
        let start: Date
        let exact: Date
        let end: Date
        let nextExact: Date?
    }

    struct ProgressedMoonWindow: Equatable, Codable {
        let signIndex: Int
        let daysInSign: Int
        let nextIngress: Date
    }

    struct ProgressedTurningPoint: Equatable, Codable {
        let first: CelestialBody
        let second: CelestialBody
        let kind: AspectKind
        let exactDate: Date?
        let separationDegrees: Double
        let phase: AspectPhase
    }

    struct SolarSeason: Equatable, Codable {
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
        skyAnchor: Date,
        transitAnchor: Date,
        secondaryTargetDate: Date,
        birthDate: Date,
        location: GeographicLocation,
        skySnapshot: ChartSnapshot,
        skyPreset: CalculationPreset,
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
            if let date = try? await calculator.nextSignIngress(for: body, after: skyAnchor) {
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
                      after: skyAnchor
                  ),
                  date.timeIntervalSince(skyAnchor) <= 7 * 86_400
            else { continue }
            exactEvents.append(
                ChartEventData.SkyExactEvent(first: first, second: second, kind: aspect.kind, date: date)
            )
        }
        exactEvents.sort { $0.date < $1.date }
        data.skyExactEvents = Array(exactEvents.prefix(3))

        // 2b. True station dates for the bodies that can visibly station.
        // These power both upcoming events and retrograde deadlines.
        let stationBodies: [CelestialBody] = [.mercury, .venus, .mars, .jupiter, .saturn, .uranus, .neptune, .pluto]
        var stations: [ChartEventData.SkyStation] = []
        for body in stationBodies {
            guard let station = try? await calculator.nextStation(for: body, after: skyAnchor) else { continue }
            stations.append(.init(body: body, date: station.date, retrogradeAfter: station.retrogradeAfter))
        }
        data.skyStations = stations.sorted { $0.date < $1.date }

        // 3. Transit windows for the strongest active transits: the exact peak
        //    plus the in-orb start and end dates.
        for aspect in transitAspects.prefix(6) {
            guard let first = CelestialBody(rawValue: aspect.firstID),
                  let second = CelestialBody(rawValue: aspect.secondID)
            else { continue }
            let exact: Date
            switch aspect.phase {
            case .applying:
                guard let calculated = try? await calculator.nextTransitNatalExactDate(
                    moving: first,
                    natalReferenceLongitude: aspect.secondLongitude,
                    kind: aspect.kind,
                    after: transitAnchor
                ) else { continue }
                exact = calculated
            case .exact:
                exact = transitAnchor
            case .separating:
                guard let calculated = try? await calculator.previousTransitNatalExactDate(
                    moving: first,
                    natalReferenceLongitude: aspect.secondLongitude,
                    kind: aspect.kind,
                    before: transitAnchor
                ) else { continue }
                exact = calculated
            }
            guard let window = try? await calculator.transitNatalAspectWindow(
                moving: first,
                natalReferenceLongitude: aspect.secondLongitude,
                kind: aspect.kind,
                exactDate: exact,
                orbDegrees: max(aspect.orbDegrees, 0.5)
            ) else { continue }
            let nextExact: Date?
            if exact.timeIntervalSince(transitAnchor) >= 0 {
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
                    start: window.start,
                    exact: exact,
                    end: window.end,
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
                    after: secondaryTargetDate,
                    maxYears: 8
                )
            case .exact:
                exactDate = secondaryTargetDate
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
        LocalizedFormatters.shortDate(self, language: language, timeZone: timeZone)
    }

    /// Month-year label such as "Sep 2026" / "2026年9月".
    func shortEventMonthYear(language: AppLanguage, timeZone: TimeZone = .current) -> String {
        LocalizedFormatters.monthYear(self, language: language, timeZone: timeZone)
    }

    /// Compact range such as "Jul 18–Nov 6" / "7月18日–11月6日".
    func shortEventRange(to end: Date, language: AppLanguage, timeZone: TimeZone = .current) -> String {
        "\(shortEventDate(language: language, timeZone: timeZone))–\(end.shortEventDate(language: language, timeZone: timeZone))"
    }
}
