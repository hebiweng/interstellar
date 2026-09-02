import Foundation

extension SwissEphemerisCalculator {
    /// Resolves Lilly's Moon testimony from the actual ephemeris across the Moon's
    /// current sign: what she has most recently separated from, and what she will
    /// next apply to before leaving the sign (CA pp.298-299, aphorisms 5, 9-12).
    public func resolveHoraryMoonTestimony(snapshot: ChartSnapshot) throws -> HoraryMoonCondition {
        guard let moon = snapshot.point(.moon) else {
            return HoraryMoonCondition(
                isVoidOfCourse: true,
                nextAspect: nil,
                hoursUntilNextAspect: nil
            )
        }

        let questionDate = snapshot.utcDate
        let signStart = try previousSignIngress(for: .moon, before: questionDate)
        let signEnd = try nextSignIngress(for: .moon, after: questionDate)
        let hoursUntilExit = signEnd.timeIntervalSince(questionDate) / 3_600

        var previousEvents: [HoraryMoonAspectEvent] = []
        var upcomingEvents: [HoraryMoonAspectEvent] = []

        for body in HoraryEngine.traditionalPlanets where body != .moon {
            guard let other = snapshot.point(body) else { continue }
            for kind in AspectKind.allCases {
                // Walk all exact contacts from the Moon's sign ingress up to the question
                // so the previous event really is the latest separating contact, not just
                // the first exact aspect after ingress.
                var cursor = signStart.addingTimeInterval(1)
                var iterations = 0
                while cursor < questionDate, iterations < 4 {
                    iterations += 1
                    let exact = try nextExactAspectDate(
                        moving: .moon,
                        reference: body,
                        kind: kind,
                        after: cursor
                    )
                    guard exact <= questionDate else { break }
                    previousEvents.append(
                        HoraryMoonAspectEvent(
                            aspect: horaryMoonAspect(
                                kind: kind,
                                body: body,
                                moonLongitude: moon.longitudeDegrees,
                                otherLongitude: other.longitudeDegrees,
                                phase: .separating
                            ),
                            hoursFromQuestion: exact.timeIntervalSince(questionDate) / 3_600
                        )
                    )
                    cursor = exact.addingTimeInterval(60)
                }

                let next = try nextExactAspectDate(
                    moving: .moon,
                    reference: body,
                    kind: kind,
                    after: questionDate.addingTimeInterval(1)
                )
                if next < signEnd {
                    upcomingEvents.append(
                        HoraryMoonAspectEvent(
                            aspect: horaryMoonAspect(
                                kind: kind,
                                body: body,
                                moonLongitude: moon.longitudeDegrees,
                                otherLongitude: other.longitudeDegrees,
                                phase: .applying
                            ),
                            hoursFromQuestion: next.timeIntervalSince(questionDate) / 3_600
                        )
                    )
                }
            }
        }

        previousEvents.sort { $0.hoursFromQuestion > $1.hoursFromQuestion }
        upcomingEvents.sort { $0.hoursFromQuestion < $1.hoursFromQuestion }
        let previous = previousEvents.first
        let next = upcomingEvents.first

        return HoraryMoonCondition(
            isVoidOfCourse: next == nil,
            nextAspect: next?.aspect,
            hoursUntilNextAspect: next?.hoursFromQuestion,
            previousAspect: previous,
            upcomingAspects: upcomingEvents,
            hoursUntilSignExit: hoursUntilExit,
            isViaCombusta: HoraryEngine.isViaCombusta(longitudeDegrees: moon.longitudeDegrees)
        )
    }

    private func horaryMoonAspect(
        kind: AspectKind,
        body: CelestialBody,
        moonLongitude: Double,
        otherLongitude: Double,
        phase: AspectPhase
    ) -> ChartAspect {
        ChartAspect(
            firstID: CelestialBody.moon.id,
            secondID: body.id,
            kind: kind,
            orbDegrees: 0,
            phase: phase,
            strength: 1,
            firstLongitude: moonLongitude,
            secondLongitude: otherLongitude
        )
    }
}
