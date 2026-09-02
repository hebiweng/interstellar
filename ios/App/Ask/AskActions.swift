import AstroCore
import SwiftUI

extension AskView {
    func generate(_ mode: HoraryQuestionMode) {
        guard let location else { return }
        calculationTask?.cancel()
        isCalculating = true
        progress = 0
        errorMessage = nil
        let requestLocation = GeographicLocation(
            latitudeDegrees: location.latitude,
            longitudeDegrees: location.longitude
        )
        calculationTask = Task {
            do {
                let newSession: HorarySession
                switch mode {
                case .yesNo:
                    guard let primaryHouse else { return }
                    let moment = chartDate
                    let snapshot = try await model.calculateHorarySnapshot(
                        at: moment,
                        location: requestLocation
                    )
                    newSession = HorarySession(
                        mode: mode,
                        question: question.trimmed,
                        createdAt: moment,
                        locationName: location.name,
                        timezoneID: location.timezoneID,
                        snapshot: snapshot,
                        analysis: try await model.calculateHoraryJudgment(
                            snapshot: snapshot,
                            targetHouse: primaryHouse,
                            relatedHouses: Array(relatedHouses).sorted(),
                            timeZone: TimeZone(identifier: location.timezoneID)
                        ),
                        choices: [],
                        timingCandidates: []
                    )
                case .choice:
                    let moment = chartDate
                    let snapshot = try await model.calculateHorarySnapshot(
                        at: moment,
                        location: requestLocation
                    )
                    let candidates = options.enumerated().compactMap { index, option -> HoraryChoiceCandidate? in
                        guard let house = effectivePrimaryHouse(for: option) else { return nil }
                        return HoraryChoiceCandidate(
                            id: option.id,
                            label: option.label.trimmed,
                            house: house,
                            relatedHouses: Array(effectiveRelatedHouses(for: option)).sorted(),
                            originalIndex: index
                        )
                    }
                    let choiceMode: HoraryChoiceSignificatorMode = if let sharedPrimaryHouse,
                                                                     sharedSamePrimary == true {
                        .sharedPrimary(house: sharedPrimaryHouse)
                    } else {
                        .independentPrimary
                    }
                    newSession = HorarySession(
                        mode: mode,
                        question: "",
                        createdAt: moment,
                        locationName: location.name,
                        timezoneID: location.timezoneID,
                        snapshot: snapshot,
                        analysis: nil,
                        choices: try await model.calculateHoraryChoices(
                            snapshot: snapshot,
                            candidates: candidates,
                            mode: choiceMode,
                            timeZone: TimeZone(identifier: location.timezoneID)
                        ),
                        timingCandidates: []
                    )
                case .timing:
                    guard let primaryHouse else { return }
                    let moment = chartDate
                    await MainActor.run { progress = 0.2 }
                    let snapshot = try await model.calculateHorarySnapshot(
                        at: moment,
                        location: requestLocation
                    )
                    await MainActor.run { progress = 0.6 }
                    let analysis = try await model.calculateHoraryJudgment(
                        snapshot: snapshot,
                        targetHouse: primaryHouse,
                        relatedHouses: Array(relatedHouses).sorted(),
                        timeZone: TimeZone(identifier: location.timezoneID)
                    )
                    let timingResult = model.calculateHoraryTiming(
                        snapshot: snapshot,
                        analysis: analysis
                    )
                    await MainActor.run { progress = 0.9 }
                    newSession = HorarySession(
                        mode: mode,
                        question: question.trimmed,
                        createdAt: moment,
                        locationName: location.name,
                        timezoneID: location.timezoneID,
                        snapshot: snapshot,
                        analysis: analysis,
                        choices: [],
                        timingResult: timingResult,
                        timingCandidates: []
                    )
                    try Task.checkCancellation()
                case .bestTime:
                    guard let primaryHouse else { return }
                    guard let timeZone = TimeZone(identifier: location.timezoneID) else {
                        throw AskViewError.invalidTimeZone
                    }
                    var calendar = Calendar(identifier: .gregorian)
                    calendar.timeZone = timeZone
                    let start = max(chartDate, Date())
                    guard let end = calendar.date(
                        byAdding: .day,
                        value: bestTimeWindow.rawValue,
                        to: start
                    ) else {
                        throw ElectionTimingError.invalidRange
                    }
                    let request = ElectionTimingRequest(
                        targetHouse: primaryHouse,
                        relatedHouses: Array(relatedHouses).sorted(),
                        startDate: start,
                        endDate: end,
                        location: requestLocation,
                        timeZone: timeZone,
                        calendarIdentifier: .gregorian,
                        precision: .day
                    )
                    let candidates = try await model.searchElectionTiming(request) { value in
                        Task { @MainActor in
                            progress = value
                        }
                    }
                    guard let first = candidates.first else {
                        throw ElectionTimingError.noCandidates
                    }
                    newSession = HorarySession(
                        mode: mode,
                        question: question.trimmed,
                        createdAt: start,
                        locationName: location.name,
                        timezoneID: location.timezoneID,
                        snapshot: first.snapshot,
                        analysis: nil,
                        choices: [],
                        electionCandidates: candidates
                    )
                    try Task.checkCancellation()
                }
                try Task.checkCancellation()
                await MainActor.run {
                    session = newSession
                    isCalculating = false
                    progress = 1
                    askHistoryStore.append(historyEntry(from: newSession))
                    askHistory = askHistoryStore.load()
                }
            } catch is CancellationError {
                await MainActor.run {
                    isCalculating = false
                    progress = 0
                }
            } catch {
                await MainActor.run {
                    errorMessage = localized("ask.the-chart-could-not-be-calculated-check-the-time-and-location-then-try-a", language: model.language)
                    isCalculating = false
                }
            }
        }
    }

    func select(_ selectedMode: HoraryQuestionMode) {
        mode = selectedMode
        focusedInputID = nil
        chartDate = Date()
        session = nil
        errorMessage = nil
    }

    func resetToModes() {
        calculationTask?.cancel()
        calculationTask = nil
        mode = nil
        session = nil
        focusedInputID = nil
        question = ""
        primaryHouse = nil
        relatedHouses = []
        options = [AskOptionDraft(), AskOptionDraft()]
        sharedSamePrimary = nil
        sharedPrimaryHouse = nil
        sharedRelatedHouses = []
        chartDate = Date()
        bestTimeWindow = .thirtyDays
        isCalculating = false
        progress = 0
        errorMessage = nil
    }


    func historyEntry(from session: HorarySession) -> AskHistoryEntry {
        let title: String
        let text: String
        switch session.mode {
        case .yesNo:
            title = session.analysis.map { judgmentLabel($0) } ?? localized("ask.result", language: model.language)
            if let reliability = session.analysis?.judgment?.considerations?.reliability {
                text = localized("ask.judgment-clarity", language: model.language) + ": " + judgmentReliabilityText(reliability)
            } else {
                text = ""
            }
        case .choice:
            if let first = session.choices.first {
                title = first.isTiedForLead
                    ? localized("ask.no-clear-option", language: model.language)
                    : first.label
                text = first.isTiedForLead
                    ? localized("ask.close-call", language: model.language)
                    : localized("ask.leading", language: model.language)
            } else {
                title = localized("ask.result", language: model.language)
                text = ""
            }
        case .timing:
            if let timing = session.timingResult {
                title = timingHistoryTitle(timing)
                text = timingHistoryText(timing)
            } else {
                title = session.timingCandidates.first.map { formatDateRange($0.interval) }
                    ?? localized("ask.result", language: model.language)
                text = localized("ask.recommended-window", language: model.language)
            }
        case .bestTime:
            title = session.electionCandidates.first.map { formatDateRange($0.interval) }
                ?? localized("ask.no-timing-found", language: model.language)
            text = localized("ask.best-time-history-detail", language: model.language)
        }
        return AskHistoryEntry(
            id: session.snapshot.utcDate.timeIntervalSince1970.description + session.question,
            mode: session.mode.rawValue,
            question: session.question.isEmpty ? modeTitle(session.mode) : session.question,
            answerTitle: title,
            answerText: text,
            createdAt: session.createdAt,
            locationName: session.locationName,
            significators: [],
            session: session
        )
    }

    func openHistoryEntry(_ entry: AskHistoryEntry) {
        guard let restoredSession = entry.session else { return }
        withTransaction(Transaction(animation: nil)) {
            session = restoredSession
            mode = restoredSession.mode
            showAskHistory = false
        }
    }

    func formatDateRange(_ interval: DateInterval) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: interval.start)
    }

    func timingHistoryTitle(_ timing: HoraryTimingResult) -> String {
        switch timing.status {
        case .indicated: localized("ask.timing-indicated", language: model.language)
        case .prevented: localized("ask.timing-prevented", language: model.language)
        case .notIndicated: localized("ask.timing-not-indicated", language: model.language)
        case .ambiguous: localized("ask.timing-ambiguous", language: model.language)
        }
    }

    func timingHistoryText(_ timing: HoraryTimingResult) -> String {
        guard timing.status == .indicated else { return localized("ask.timing-no-promise", language: model.language) }
        let scales = timing.scales.map { timingScaleLabel($0) }.joined(separator: " · ")
        return timing.isMixed
            ? localized("ask.timing-mixed-explanation", language: model.language)
            : scales
    }

    func timingScaleLabel(_ scale: HoraryTimingScale) -> String {
        switch scale {
        case .days: localized("ask.timing-days", language: model.language)
        case .weeksOrMonths: localized("ask.timing-weeks-months", language: model.language)
        case .monthsOrYears: localized("ask.timing-months-years", language: model.language)
        }
    }

    var profileLocation: LocationSelection {
        LocationSelection(
            name: model.profile.placeName,
            latitude: model.profile.latitude,
            longitude: model.profile.longitude,
            timezoneID: model.profile.timezoneID
        )
    }


}
