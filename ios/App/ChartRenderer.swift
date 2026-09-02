import AstroCore
import SwiftUI

enum AstrologyWheelGeometry {
    /// ASC is fixed at the left edge. Increasing zodiac longitude proceeds
    /// from ASC toward the lower half of the screen, matching the conventional
    /// counter-clockwise house order in a screen coordinate system (positive Y
    /// points downward).
    static func point(
        center: CGPoint,
        radius: Double,
        longitude: Double,
        ascendantRotation: Double
    ) -> CGPoint {
        let angle = (180 - (longitude - ascendantRotation)) * .pi / 180
        return CGPoint(
            x: center.x + cos(angle) * radius,
            y: center.y + sin(angle) * radius
        )
    }
}

enum ChartWheelPresentation: String, Sendable {
    case standard
    case ask
    case theme
    case compare
}

// MARK: - Wheel Display Architecture

enum ChartDisplayMode: String, CaseIterable, Identifiable, Sendable {
    case simple
    case pro

    var id: String { rawValue }
}

enum ZodiacLabelDensity: Sendable {
    case glyphOnly
    case glyphAndDegree
}

enum DegreePrecision: Sendable {
    case whole
    case minute
}

enum AspectDensity: Sendable {
    case major
    case extended
}

struct ChartDisplayConfig: Sendable {
    let mode: ChartDisplayMode
    let showMinorAspects: Bool
    let showFullDegreePrecision: Bool
    let showPlanetTable: Bool
    let showChartMetadata: Bool
    let showSummary: Bool
    let zodiacLabelDensity: ZodiacLabelDensity
    let degreePrecision: DegreePrecision
    let aspectDensity: AspectDensity

    static let simple = ChartDisplayConfig(
        mode: .simple,
        showMinorAspects: false,
        showFullDegreePrecision: false,
        showPlanetTable: false,
        showChartMetadata: false,
        showSummary: true,
        zodiacLabelDensity: .glyphOnly,
        degreePrecision: .whole,
        aspectDensity: .major
    )

    static let pro = ChartDisplayConfig(
        mode: .pro,
        // AstroCore currently emits the five major aspect kinds only.
        // Keep the UI honest instead of inventing minor aspects.
        showMinorAspects: false,
        showFullDegreePrecision: true,
        showPlanetTable: true,
        showChartMetadata: true,
        showSummary: false,
        zodiacLabelDensity: .glyphAndDegree,
        degreePrecision: .minute,
        aspectDensity: .extended
    )

    static func config(for mode: ChartDisplayMode) -> ChartDisplayConfig {
        switch mode {
        case .simple: .simple
        case .pro: .pro
        }
    }
}

struct ChartVisualTokens {
    let background: Color
    let wheelSurface: Color
    let primaryText: Color
    let secondaryText: Color
    let gridStrong: Color
    let gridNormal: Color
    let gridWeak: Color
    let axisColor: Color
    let accentColor: Color
    let aspectPositive: Color
    let aspectChallenging: Color
    let aspectNeutral: Color

    static var adaptive: ChartVisualTokens {
        ChartVisualTokens(
            background: AppTheme.background,
            wheelSurface: AppTheme.panel,
            primaryText: AppTheme.text,
            secondaryText: AppTheme.muted,
            gridStrong: AppTheme.text.opacity(0.34),
            gridNormal: AppTheme.text.opacity(0.16),
            gridWeak: AppTheme.text.opacity(0.085),
            axisColor: AppTheme.violet,
            accentColor: AppTheme.violet,
            aspectPositive: AppTheme.blue,
            aspectChallenging: AppTheme.coral,
            aspectNeutral: AppTheme.amber
        )
    }

    func planetColor(_ body: CelestialBody) -> Color {
        switch body {
        case .sun: AppTheme.amber
        case .moon: AppTheme.blue
        case .mercury: AppTheme.violet
        case .venus: AppTheme.mint
        case .mars: AppTheme.coral
        case .jupiter: AppTheme.amber
        case .saturn: AppTheme.muted
        case .uranus: AppTheme.blue
        case .neptune: AppTheme.mint
        case .pluto: AppTheme.violet
        case .trueNode, .lilith, .partOfFortune, .juno:
            AppTheme.muted
        }
    }

    func aspectColor(_ kind: AspectKind) -> Color {
        switch kind {
        case .trine, .sextile:
            aspectPositive
        case .square, .opposition:
            aspectChallenging
        case .conjunction:
            aspectNeutral
        }
    }
}

struct ChartGeometry {
    let bounds: CGRect
    let safeLabelBounds: CGRect
    let center: CGPoint
    let wheelRadius: CGFloat
    let outerTickRadius: CGFloat
    let zodiacRadius: CGFloat
    let outerPlanetRadius: CGFloat
    let innerPlanetRadius: CGFloat
    let houseOuterRadius: CGFloat
    let houseInnerRadius: CGFloat
    let houseNumberRadius: CGFloat
    let aspectRadius: CGFloat
    let comparisonOuterAspectRadius: CGFloat
    let comparisonInnerAspectRadius: CGFloat

    init(
        size: CGSize,
        mode: ChartDisplayMode,
        externalLabelReserve: CGFloat = 12
    ) {
        let bounds = CGRect(origin: .zero, size: size)
        self.bounds = bounds

        // All visible content, including ASC/DSC/MC/IC labels, must stay inside
        // this area. The renderer does not use clipping to hide overflow.
        let edgeInset: CGFloat = 8
        let safe = bounds.insetBy(
            dx: edgeInset + externalLabelReserve,
            dy: edgeInset
        )
        safeLabelBounds = safe

        let diameter = min(safe.width, safe.height)
        let radius = max(1, diameter / 2)
        center = CGPoint(x: bounds.midX, y: bounds.midY)
        wheelRadius = radius

        switch mode {
        case .simple:
            outerTickRadius = radius
            zodiacRadius = radius * 0.90
            outerPlanetRadius = radius * 0.69
            innerPlanetRadius = radius * 0.50
            houseOuterRadius = radius * 0.80
            houseInnerRadius = radius * 0.59
            houseNumberRadius = radius * 0.625
            aspectRadius = radius * 0.555
            comparisonOuterAspectRadius = radius * 0.61
            comparisonInnerAspectRadius = radius * 0.47

        case .pro:
            outerTickRadius = radius
            zodiacRadius = radius * 0.89
            outerPlanetRadius = radius * 0.70
            innerPlanetRadius = radius * 0.51
            houseOuterRadius = radius * 0.81
            houseInnerRadius = radius * 0.595
            houseNumberRadius = radius * 0.625
            aspectRadius = radius * 0.56
            comparisonOuterAspectRadius = radius * 0.615
            comparisonInnerAspectRadius = radius * 0.475
        }
    }

    func point(
        longitude: Double,
        rotation: Double,
        radius: CGFloat
    ) -> CGPoint {
        AstrologyWheelGeometry.point(
            center: center,
            radius: Double(radius),
            longitude: longitude,
            ascendantRotation: rotation
        )
    }

    func clampedLabelPoint(
        longitude: Double,
        rotation: Double,
        radius: CGFloat,
        horizontalReserve: CGFloat = 18,
        verticalReserve: CGFloat = 10
    ) -> CGPoint {
        let raw = point(
            longitude: longitude,
            rotation: rotation,
            radius: radius
        )
        return CGPoint(
            x: min(
                safeLabelBounds.maxX - horizontalReserve,
                max(safeLabelBounds.minX + horizontalReserve, raw.x)
            ),
            y: min(
                safeLabelBounds.maxY - verticalReserve,
                max(safeLabelBounds.minY + verticalReserve, raw.y)
            )
        )
    }
}

struct ChartSummaryItem: Identifiable, Sendable {
    let id: String
    let glyph: String
    let title: String
    let primary: String
    let secondary: String
}


enum ChartWheelCopyKey {
    case simple
    case pro
    case planets
    case aspects
    case houses
    case table
    case sign
    case degree
    case house
    case retro
    case speed
}

enum ChartWheelCopy {
    static func text(
        _ key: ChartWheelCopyKey,
        language: AppLanguage
    ) -> String {
        let code = language.rawValue.lowercased()
        switch code {
        case let value where value.hasPrefix("zh"):
            return chinese(key)
        case let value where value.hasPrefix("es"):
            return spanish(key)
        case let value where value.hasPrefix("fr"):
            return french(key)
        case let value where value.hasPrefix("tr"):
            return turkish(key)
        case let value where value.hasPrefix("de"):
            return german(key)
        case let value where value.hasPrefix("it"):
            return italian(key)
        case let value where value.hasPrefix("ko"):
            return korean(key)
        case let value where value.hasPrefix("pt"):
            return portuguese(key)
        default:
            return english(key)
        }
    }

    private static func english(_ key: ChartWheelCopyKey) -> String {
        switch key {
        case .simple: "Simple"
        case .pro: "Pro"
        case .planets: "Planets"
        case .aspects: "Aspects"
        case .houses: "Houses"
        case .table: "Table"
        case .sign: "Sign"
        case .degree: "Degree"
        case .house: "House"
        case .retro: "Retro"
        case .speed: "Speed"
        }
    }

    private static func chinese(_ key: ChartWheelCopyKey) -> String {
        switch key {
        case .simple: "简洁"
        case .pro: "专业"
        case .planets: "行星"
        case .aspects: "相位"
        case .houses: "宫位"
        case .table: "表格"
        case .sign: "星座"
        case .degree: "度数"
        case .house: "宫位"
        case .retro: "逆行"
        case .speed: "速度"
        }
    }

    private static func spanish(_ key: ChartWheelCopyKey) -> String {
        switch key {
        case .simple: "Simple"
        case .pro: "Pro"
        case .planets: "Planetas"
        case .aspects: "Aspectos"
        case .houses: "Casas"
        case .table: "Tabla"
        case .sign: "Signo"
        case .degree: "Grado"
        case .house: "Casa"
        case .retro: "Retró."
        case .speed: "Velocidad"
        }
    }

    private static func french(_ key: ChartWheelCopyKey) -> String {
        switch key {
        case .simple: "Simple"
        case .pro: "Pro"
        case .planets: "Planètes"
        case .aspects: "Aspects"
        case .houses: "Maisons"
        case .table: "Tableau"
        case .sign: "Signe"
        case .degree: "Degré"
        case .house: "Maison"
        case .retro: "Rétro."
        case .speed: "Vitesse"
        }
    }

    private static func turkish(_ key: ChartWheelCopyKey) -> String {
        switch key {
        case .simple: "Basit"
        case .pro: "Pro"
        case .planets: "Gezegenler"
        case .aspects: "Açılar"
        case .houses: "Evler"
        case .table: "Tablo"
        case .sign: "Burç"
        case .degree: "Derece"
        case .house: "Ev"
        case .retro: "Retro"
        case .speed: "Hız"
        }
    }

    private static func german(_ key: ChartWheelCopyKey) -> String {
        switch key {
        case .simple: "Einfach"
        case .pro: "Pro"
        case .planets: "Planeten"
        case .aspects: "Aspekte"
        case .houses: "Häuser"
        case .table: "Tabelle"
        case .sign: "Zeichen"
        case .degree: "Grad"
        case .house: "Haus"
        case .retro: "Retro"
        case .speed: "Tempo"
        }
    }

    private static func italian(_ key: ChartWheelCopyKey) -> String {
        switch key {
        case .simple: "Semplice"
        case .pro: "Pro"
        case .planets: "Pianeti"
        case .aspects: "Aspetti"
        case .houses: "Case"
        case .table: "Tabella"
        case .sign: "Segno"
        case .degree: "Grado"
        case .house: "Casa"
        case .retro: "Retro"
        case .speed: "Velocità"
        }
    }

    private static func korean(_ key: ChartWheelCopyKey) -> String {
        switch key {
        case .simple: "간단"
        case .pro: "프로"
        case .planets: "행성"
        case .aspects: "애스펙트"
        case .houses: "하우스"
        case .table: "표"
        case .sign: "사인"
        case .degree: "도수"
        case .house: "하우스"
        case .retro: "역행"
        case .speed: "속도"
        }
    }

    private static func portuguese(_ key: ChartWheelCopyKey) -> String {
        switch key {
        case .simple: "Simples"
        case .pro: "Pro"
        case .planets: "Planetas"
        case .aspects: "Aspectos"
        case .houses: "Casas"
        case .table: "Tabela"
        case .sign: "Signo"
        case .degree: "Grau"
        case .house: "Casa"
        case .retro: "Retró."
        case .speed: "Velocidade"
        }
    }
}


struct ChartWheelView: View {
    let snapshot: ChartSnapshot
    let reference: ChartSnapshot?
    let comparisonAspects: [ChartAspect]
    let language: AppLanguage
    let horaryOverlay: HoraryOverlay?
    let presentation: ChartWheelPresentation
    let displayMode: ChartDisplayMode

    init(
        snapshot: ChartSnapshot,
        reference: ChartSnapshot?,
        comparisonAspects: [ChartAspect],
        language: AppLanguage,
        horaryOverlay: HoraryOverlay? = nil,
        presentation: ChartWheelPresentation = .standard,
        displayMode: ChartDisplayMode = .simple
    ) {
        self.snapshot = snapshot
        self.reference = reference
        self.comparisonAspects = comparisonAspects
        self.language = language
        self.horaryOverlay = horaryOverlay
        self.presentation = presentation
        self.displayMode = displayMode
    }

    var body: some View {
        let config = ChartDisplayConfig.config(for: displayMode)
        VStack(spacing: displayMode == .simple ? 14 : 10) {
            Canvas { context, size in
                let geometry = ChartGeometry(
                    size: size,
                    mode: displayMode,
                    externalLabelReserve: 0
                )
                let tokens = ChartVisualTokens.adaptive
                let rotation = reference?.angles.ascendantDegrees
                    ?? snapshot.angles.ascendantDegrees
                let minDimension = min(size.width, size.height)
                let scale = min(1.12, max(0.88, minDimension / 350))

                drawWheelSurface(
                    context: &context,
                    geometry: geometry,
                    tokens: tokens
                )
                drawHouses(
                    snapshot: reference ?? snapshot,
                    context: &context,
                    geometry: geometry,
                    rotation: rotation,
                    tokens: tokens,
                    scale: scale
                )
                drawTicks(
                    context: &context,
                    geometry: geometry,
                    rotation: rotation,
                    tokens: tokens,
                    config: config
                )
                drawZodiac(
                    context: &context,
                    geometry: geometry,
                    rotation: rotation,
                    tokens: tokens,
                    config: config,
                    scale: scale
                )

                if reference != nil {
                    drawComparisonAspects(
                        comparisonAspects,
                        context: &context,
                        geometry: geometry,
                        rotation: rotation,
                        tokens: tokens,
                        config: config
                    )
                } else {
                    drawAspects(
                        snapshot.aspects,
                        context: &context,
                        geometry: geometry,
                        rotation: rotation,
                        tokens: tokens,
                        config: config,
                        keyAspectIDs: horaryOverlay?.keyAspectIDs ?? []
                    )
                }

                drawAxes(
                    snapshot: reference ?? snapshot,
                    context: &context,
                    geometry: geometry,
                    rotation: rotation,
                    tokens: tokens,
                    config: config,
                    scale: scale
                )

                if let reference {
                    drawPlanets(
                        reference.points,
                        context: &context,
                        geometry: geometry,
                        radius: geometry.innerPlanetRadius,
                        rotation: rotation,
                        tokens: tokens,
                        config: config,
                        scale: scale,
                        secondaryRing: true,
                        labels: [:]
                    )
                    drawPlanets(
                        snapshot.points,
                        context: &context,
                        geometry: geometry,
                        radius: geometry.outerPlanetRadius,
                        rotation: rotation,
                        tokens: tokens,
                        config: config,
                        scale: scale,
                        secondaryRing: false,
                        labels: [:]
                    )
                } else {
                    drawPlanets(
                        snapshot.points,
                        context: &context,
                        geometry: geometry,
                        radius: geometry.outerPlanetRadius,
                        rotation: rotation,
                        tokens: tokens,
                        config: config,
                        scale: scale,
                        secondaryRing: false,
                        labels: horaryOverlay?.planetLabels ?? [:]
                    )
                }

                drawPresentationCenter(
                    context: &context,
                    center: geometry.center,
                    tokens: tokens,
                    referenceExists: reference != nil
                )
            }
            .aspectRatio(1, contentMode: .fit)
            .accessibilityLabel(
                reference == nil
                    ? localized("chart.astrology-wheel", language: language)
                    : localized("chart.double-astrology-wheel", language: language)
            )
            .accessibilityIdentifier("astrology-wheel")

            if config.showSummary,
               reference == nil,
               presentation == .standard
            {
                simpleSummary
            }
        }
    }

    private var simpleSummary: some View {
        HStack(alignment: .top, spacing: 8) {
            summaryCard(for: .sun)
            summaryCard(for: .moon)
            risingSummaryCard
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func summaryCard(for body: CelestialBody) -> some View {
        if let point = snapshot.point(body) {
            let house = snapshot.house(containing: point.longitudeDegrees)
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 5) {
                    Text(body.symbol)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(ChartVisualTokens.adaptive.planetColor(body))
                    Text(bodyName(body, language: language))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.text)
                        .lineLimit(1)
                }
                Text(
                    "\(Int(point.degreeInSign))° \(Zodiac.name(index: point.signIndex, language: language))"
                )
                .font(.caption)
                .foregroundStyle(AppTheme.text)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                Text("H\(house)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppTheme.muted)
            }
            .frame(maxWidth: .infinity, minHeight: 76, alignment: .topLeading)
            .padding(10)
            .background(
                AppTheme.panelRaised.opacity(0.78),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppTheme.line, lineWidth: 0.8)
            )
        }
    }

    private var risingSummaryCard: some View {
        let longitude = snapshot.angles.ascendantDegrees
        let signIndex = normalizedSignIndex(longitude)
        let degree = normalizedDegreeInSign(longitude)

        return VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                Text("ASC")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.violet)
                Text(localized("chart.rising", language: language))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.text)
                    .lineLimit(1)
            }
            Text(
                "\(Int(degree))° \(Zodiac.name(index: signIndex, language: language))"
            )
            .font(.caption)
            .foregroundStyle(AppTheme.text)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            Text("H1")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppTheme.muted)
        }
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .topLeading)
        .padding(10)
        .background(
            AppTheme.panelRaised.opacity(0.78),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.line, lineWidth: 0.8)
        )
    }

    private func drawWheelSurface(
        context: inout GraphicsContext,
        geometry: ChartGeometry,
        tokens: ChartVisualTokens
    ) {
        let outer = circleRect(
            center: geometry.center,
            radius: geometry.wheelRadius
        )
        context.fill(
            Path(ellipseIn: outer),
            with: .color(tokens.wheelSurface.opacity(0.34))
        )
        context.stroke(
            Path(ellipseIn: outer),
            with: .color(tokens.gridStrong),
            lineWidth: displayMode == .simple ? 1.0 : 1.1
        )

        for radius in [
            geometry.houseOuterRadius,
            geometry.houseInnerRadius,
        ] {
            context.stroke(
                Path(ellipseIn: circleRect(center: geometry.center, radius: radius)),
                with: .color(
                    radius == geometry.houseOuterRadius
                        ? tokens.gridNormal
                        : tokens.gridWeak
                ),
                lineWidth: radius == geometry.houseOuterRadius ? 0.8 : 0.65
            )
        }
    }

    private func drawHouses(
        snapshot: ChartSnapshot,
        context: inout GraphicsContext,
        geometry: ChartGeometry,
        rotation: Double,
        tokens: ChartVisualTokens,
        scale: CGFloat
    ) {
        drawHighlightedHouses(
            horaryOverlay?.highlightedHouses ?? [],
            houses: snapshot.houses,
            context: &context,
            geometry: geometry,
            rotation: rotation,
            tokens: tokens
        )

        guard snapshot.houses.count == 12 else { return }
        for index in snapshot.houses.indices {
            let house = snapshot.houses[index]
            let isAxisHouse = house.number == 1 || house.number == 10
            var line = Path()
            line.move(
                to: geometry.point(
                    longitude: house.cuspDegrees,
                    rotation: rotation,
                    radius: geometry.houseInnerRadius
                )
            )
            line.addLine(
                to: geometry.point(
                    longitude: house.cuspDegrees,
                    rotation: rotation,
                    radius: geometry.houseOuterRadius
                )
            )
            context.stroke(
                line,
                with: .color(isAxisHouse ? tokens.axisColor.opacity(0.72) : tokens.gridNormal),
                lineWidth: isAxisHouse ? 1.25 : 0.65
            )

            let next = snapshot.houses[(index + 1) % snapshot.houses.count]
            let midpoint = circularMidpoint(
                from: house.cuspDegrees,
                to: next.cuspDegrees
            )
            context.draw(
                Text("\(house.number)")
                    .font(
                        .system(
                            size: (displayMode == .simple ? 9.5 : 10.5) * scale,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(
                        horaryOverlay?.highlightedHouses.contains(house.number) == true
                            ? tokens.axisColor
                            : tokens.secondaryText.opacity(
                                displayMode == .simple ? 0.68 : 0.84
                            )
                    ),
                at: geometry.point(
                    longitude: midpoint,
                    rotation: rotation,
                    radius: geometry.houseNumberRadius
                )
            )
        }
    }

    private func drawTicks(
        context: inout GraphicsContext,
        geometry: ChartGeometry,
        rotation: Double,
        tokens: ChartVisualTokens,
        config: ChartDisplayConfig
    ) {
        for degree in 0 ..< 360 {
            if displayMode == .simple, !degree.isMultiple(of: 5) {
                continue
            }

            let isTen = degree.isMultiple(of: 10)
            let isFive = degree.isMultiple(of: 5)
            let length: CGFloat
            let opacity: Double

            if displayMode == .simple {
                length = isTen ? 5.5 : 3.0
                opacity = isTen ? 0.22 : 0.11
            } else {
                length = isTen ? 7 : isFive ? 4.5 : 2
                opacity = isTen ? 0.28 : isFive ? 0.16 : 0.07
            }

            var tick = Path()
            tick.move(
                to: geometry.point(
                    longitude: Double(degree),
                    rotation: rotation,
                    radius: geometry.outerTickRadius - length
                )
            )
            tick.addLine(
                to: geometry.point(
                    longitude: Double(degree),
                    rotation: rotation,
                    radius: geometry.outerTickRadius
                )
            )
            context.stroke(
                tick,
                with: .color(tokens.primaryText.opacity(opacity)),
                lineWidth: isTen ? 0.7 : 0.45
            )
        }
    }

    private func drawZodiac(
        context: inout GraphicsContext,
        geometry: ChartGeometry,
        rotation: Double,
        tokens: ChartVisualTokens,
        config: ChartDisplayConfig,
        scale: CGFloat
    ) {
        for index in 0 ..< 12 {
            let boundary = Double(index * 30)
            var divider = Path()
            divider.move(
                to: geometry.point(
                    longitude: boundary,
                    rotation: rotation,
                    radius: geometry.houseOuterRadius
                )
            )
            divider.addLine(
                to: geometry.point(
                    longitude: boundary,
                    rotation: rotation,
                    radius: geometry.wheelRadius
                )
            )
            context.stroke(
                divider,
                with: .color(tokens.gridNormal),
                lineWidth: 0.75
            )

            let midpoint = boundary + 15
            let glyph = zodiacGlyph(index)
            let glyphSize = (displayMode == .simple ? 20.0 : 17.0) * scale

            context.draw(
                Text(glyph)
                    .font(.system(size: glyphSize, weight: .medium))
                    .foregroundStyle(
                        tokens.secondaryText.opacity(
                            displayMode == .simple ? 0.78 : 0.72
                        )
                    ),
                at: geometry.point(
                    longitude: midpoint,
                    rotation: rotation,
                    radius: geometry.zodiacRadius
                )
            )

            if config.zodiacLabelDensity == .glyphAndDegree {
                context.draw(
                    Text("\(index * 30)°")
                        .font(.system(size: 8.5 * scale, weight: .medium))
                        .foregroundStyle(tokens.secondaryText.opacity(0.55)),
                    at: geometry.point(
                        longitude: midpoint,
                        rotation: rotation,
                        radius: geometry.zodiacRadius - 15
                    )
                )
            }
        }
    }

    private func drawAxes(
        snapshot: ChartSnapshot,
        context: inout GraphicsContext,
        geometry: ChartGeometry,
        rotation: Double,
        tokens: ChartVisualTokens,
        config: ChartDisplayConfig,
        scale: CGFloat
    ) {
        let axes: [(String, Double, Bool)] = [
            ("ASC", snapshot.angles.ascendantDegrees, true),
            ("DSC", snapshot.angles.ascendantDegrees + 180, false),
            ("MC", snapshot.angles.midheavenDegrees, true),
            ("IC", snapshot.angles.midheavenDegrees + 180, false),
        ]

        for (label, longitude, emphasized) in axes {
            var path = Path()
            path.move(to: geometry.center)
            path.addLine(
                to: geometry.point(
                    longitude: longitude,
                    rotation: rotation,
                    radius: geometry.houseOuterRadius
                )
            )
            context.stroke(
                path,
                with: .color(
                    emphasized
                        ? tokens.axisColor.opacity(0.72)
                        : tokens.primaryText.opacity(0.17)
                ),
                lineWidth: emphasized ? 1.25 : 0.8
            )

            let degree = normalizedDegreeInSign(longitude)
            let text = displayMode == .simple
                ? label
                : "\(label)\n\(formatDegree(degree, precision: config.degreePrecision))"

            context.draw(
                Text(text)
                    .font(
                        .system(
                            size: (displayMode == .simple ? 9.5 : 9.0) * scale,
                            weight: .bold
                        )
                    )
                    .foregroundColor(
                        emphasized
                            ? tokens.axisColor
                            : tokens.secondaryText
                    ),
                at: geometry.clampedLabelPoint(
                    longitude: longitude,
                    rotation: rotation,
                    radius: geometry.wheelRadius - 6,
                    horizontalReserve: displayMode == .simple ? 17 : 22,
                    verticalReserve: displayMode == .simple ? 9 : 15
                )
            )
        }
    }

    private func drawPlanets(
        _ points: [ChartPoint],
        context: inout GraphicsContext,
        geometry: ChartGeometry,
        radius: CGFloat,
        rotation: Double,
        tokens: ChartVisualTokens,
        config: ChartDisplayConfig,
        scale: CGFloat,
        secondaryRing: Bool,
        labels: [CelestialBody: String]
    ) {
        let adjusted = collisionAdjusted(points)
        for (pointValue, displayLongitude) in adjusted {
            let color = secondaryRing
                ? tokens.secondaryText
                : tokens.planetColor(pointValue.body)
            let glyphSize = (
                displayMode == .simple ? 19.0 : 17.0
            ) * scale
            let degreeSize = (
                displayMode == .simple ? 10.5 : 9.5
            ) * scale

            let anchor = geometry.point(
                longitude: pointValue.longitudeDegrees,
                rotation: rotation,
                radius: radius - 12
            )
            let leaderEnd = geometry.point(
                longitude: displayLongitude,
                rotation: rotation,
                radius: radius - 5
            )
            var leader = Path()
            leader.move(to: anchor)
            leader.addLine(to: leaderEnd)
            context.stroke(
                leader,
                with: .color(color.opacity(secondaryRing ? 0.16 : 0.24)),
                lineWidth: 0.55
            )

            let degree = formatDegree(
                pointValue.degreeInSign,
                precision: config.degreePrecision
            )
            let retrograde = pointValue.retrograde ? " R" : ""
            let role = labels[pointValue.body].map { "\n\($0)" } ?? ""
            let house = snapshot.house(containing: pointValue.longitudeDegrees)
            let secondaryLine = displayMode == .simple
                ? "\(degree) · H\(house)\(retrograde)"
                : "\(degree)\(retrograde)"

            let label = Text(pointValue.body.symbol)
                .font(.system(size: glyphSize, weight: .semibold))
                .foregroundColor(color)
                + Text("\n\(secondaryLine)")
                .font(.system(size: degreeSize, weight: .medium))
                .foregroundColor(color.opacity(secondaryRing ? 0.72 : 0.82))
                + Text(role)
                .font(.system(size: max(8, degreeSize - 0.5), weight: .bold))
                .foregroundColor(tokens.axisColor)

            context.draw(
                label,
                at: geometry.point(
                    longitude: displayLongitude,
                    rotation: rotation,
                    radius: radius
                )
            )
        }
    }

    private func drawAspects(
        _ aspects: [ChartAspect],
        context: inout GraphicsContext,
        geometry: ChartGeometry,
        rotation: Double,
        tokens: ChartVisualTokens,
        config: ChartDisplayConfig,
        keyAspectIDs: Set<String>
    ) {
        let limit = config.aspectDensity == .major ? 14 : 28
        for aspect in aspects
            .sorted(by: { $0.strength > $1.strength })
            .prefix(limit)
        {
            let emphasized = keyAspectIDs.contains(aspect.id)
            var path = Path()
            path.move(
                to: geometry.point(
                    longitude: aspect.firstLongitude,
                    rotation: rotation,
                    radius: geometry.aspectRadius
                )
            )
            path.addLine(
                to: geometry.point(
                    longitude: aspect.secondLongitude,
                    rotation: rotation,
                    radius: geometry.aspectRadius
                )
            )

            let baseOpacity = displayMode == .simple ? 0.22 : 0.27
            let strengthOpacity = min(0.48, aspect.strength * 0.34)
            context.stroke(
                path,
                with: .color(
                    tokens.aspectColor(aspect.kind)
                        .opacity(
                            emphasized
                                ? 0.78
                                : baseOpacity + strengthOpacity
                        )
                ),
                lineWidth: emphasized
                    ? 1.6
                    : (displayMode == .simple ? 0.75 : 0.85)
            )
        }
    }

    private func drawComparisonAspects(
        _ aspects: [ChartAspect],
        context: inout GraphicsContext,
        geometry: ChartGeometry,
        rotation: Double,
        tokens: ChartVisualTokens,
        config: ChartDisplayConfig
    ) {
        let limit = config.aspectDensity == .major ? 14 : 28
        for aspect in aspects
            .sorted(by: { $0.strength > $1.strength })
            .prefix(limit)
        {
            var path = Path()
            path.move(
                to: geometry.point(
                    longitude: aspect.firstLongitude,
                    rotation: rotation,
                    radius: geometry.comparisonOuterAspectRadius
                )
            )
            path.addLine(
                to: geometry.point(
                    longitude: aspect.secondLongitude,
                    rotation: rotation,
                    radius: geometry.comparisonInnerAspectRadius
                )
            )
            context.stroke(
                path,
                with: .color(
                    tokens.aspectColor(aspect.kind)
                        .opacity(
                            (displayMode == .simple ? 0.22 : 0.28)
                                + min(0.42, aspect.strength * 0.32)
                        )
                ),
                lineWidth: displayMode == .simple ? 0.75 : 0.9
            )
        }
    }

    private func drawHighlightedHouses(
        _ highlighted: Set<Int>,
        houses: [ChartHouse],
        context: inout GraphicsContext,
        geometry: ChartGeometry,
        rotation: Double,
        tokens: ChartVisualTokens
    ) {
        guard !highlighted.isEmpty, houses.count == 12 else { return }

        for index in houses.indices
        where highlighted.contains(houses[index].number) {
            let start = houses[index].cuspDegrees
            var end = houses[(index + 1) % houses.count].cuspDegrees
            while end <= start { end += 360 }

            var path = Path()
            let steps = max(6, Int((end - start) / 2))
            path.move(
                to: geometry.point(
                    longitude: start,
                    rotation: rotation,
                    radius: geometry.houseInnerRadius
                )
            )
            for step in 0 ... steps {
                let longitude = start
                    + (end - start) * Double(step) / Double(steps)
                path.addLine(
                    to: geometry.point(
                        longitude: longitude,
                        rotation: rotation,
                        radius: geometry.houseOuterRadius
                    )
                )
            }
            for step in (0 ... steps).reversed() {
                let longitude = start
                    + (end - start) * Double(step) / Double(steps)
                path.addLine(
                    to: geometry.point(
                        longitude: longitude,
                        rotation: rotation,
                        radius: geometry.houseInnerRadius
                    )
                )
            }
            path.closeSubpath()
            context.fill(
                path,
                with: .color(
                    tokens.axisColor.opacity(
                        presentation == .ask ? 0.13 : 0.08
                    )
                )
            )
        }
    }

    private func drawPresentationCenter(
        context: inout GraphicsContext,
        center: CGPoint,
        tokens: ChartVisualTokens,
        referenceExists: Bool
    ) {
        let text: String = switch presentation {
        case .standard:
            referenceExists ? "◉" : "◎"
        case .ask:
            "✦"
        case .theme:
            "✦"
        case .compare:
            "⇄"
        }

        context.draw(
            Text(text)
                .font(
                    .system(
                        size: displayMode == .simple ? 16 : 15,
                        weight: .medium
                    )
                )
                .foregroundStyle(tokens.axisColor.opacity(0.58)),
            at: center
        )
    }

    private func collisionAdjusted(
        _ points: [ChartPoint]
    ) -> [(ChartPoint, Double)] {
        let sorted = circularlySorted(points)
        let minimumSpacing = displayMode == .simple ? 16.0 : 13.0
        var adjusted: [(ChartPoint, Double)] = []

        for pointValue in sorted {
            var longitude = pointValue.longitudeDegrees
            if let first = adjusted.first?.1 {
                while longitude < first { longitude += 360 }
            }
            if let previous = adjusted.last?.1,
               longitude - previous < minimumSpacing
            {
                longitude = previous + minimumSpacing
            }
            adjusted.append((pointValue, longitude))
        }

        // Prevent the final stagger from wrapping on top of the first label.
        guard adjusted.count > 1,
              let first = adjusted.first,
              let last = adjusted.last
        else {
            return adjusted
        }
        let closingGap = (first.1 + 360) - last.1
        if closingGap < minimumSpacing {
            let correction = (minimumSpacing - closingGap)
                / Double(adjusted.count)
            adjusted = adjusted.enumerated().map { index, pair in
                (pair.0, pair.1 - correction * Double(index))
            }
        }
        return adjusted
    }

    private func circularlySorted(_ points: [ChartPoint]) -> [ChartPoint] {
        let sorted = points.sorted {
            $0.longitudeDegrees < $1.longitudeDegrees
        }
        guard sorted.count > 1 else { return sorted }

        var largestGap = -Double.infinity
        var startIndex = 0
        for index in sorted.indices {
            let nextIndex = (index + 1) % sorted.count
            let nextLongitude = nextIndex == 0
                ? sorted[nextIndex].longitudeDegrees + 360
                : sorted[nextIndex].longitudeDegrees
            let gap = nextLongitude - sorted[index].longitudeDegrees
            if gap > largestGap {
                largestGap = gap
                startIndex = nextIndex
            }
        }

        return Array(sorted[startIndex...])
            + Array(sorted[..<startIndex])
    }

    private func circleRect(
        center: CGPoint,
        radius: CGFloat
    ) -> CGRect {
        CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )
    }

    private func circularMidpoint(
        from start: Double,
        to rawEnd: Double
    ) -> Double {
        var end = rawEnd
        while end < start { end += 360 }
        return (start + (end - start) / 2)
            .truncatingRemainder(dividingBy: 360)
    }

    private func normalizedSignIndex(_ longitude: Double) -> Int {
        Int(normalizedLongitude(longitude) / 30)
    }

    private func normalizedDegreeInSign(_ longitude: Double) -> Double {
        normalizedLongitude(longitude)
            .truncatingRemainder(dividingBy: 30)
    }

    private func normalizedLongitude(_ longitude: Double) -> Double {
        let raw = longitude.truncatingRemainder(dividingBy: 360)
        return raw >= 0 ? raw : raw + 360
    }

    private func formatDegree(
        _ value: Double,
        precision: DegreePrecision
    ) -> String {
        switch precision {
        case .whole:
            return "\(Int(value.rounded()))°"
        case .minute:
            let degrees = Int(value)
            let minutes = Int(((value - Double(degrees)) * 60).rounded())
            if minutes == 60 {
                return "\(degrees + 1)°00′"
            }
            return String(format: "%d°%02d′", degrees, minutes)
        }
    }

    private func zodiacGlyph(_ index: Int) -> String {
        let glyphs = [
            "♈︎", "♉︎", "♊︎", "♋︎",
            "♌︎", "♍︎", "♎︎", "♏︎",
            "♐︎", "♑︎", "♒︎", "♓︎",
        ]
        return glyphs[((index % 12) + 12) % 12]
    }
}

struct AspectChartView: View {
    let aspects: [ChartAspect]
    let movingPoints: [ChartPoint]
    let referencePoints: [ChartPoint]
    let language: AppLanguage
    let comparison: Bool
    @ScaledMetric(relativeTo: .caption) private var matrixScale: CGFloat = 1

    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(
                        comparison
                            ? localized("chart.moving-natal", language: language)
                            : localized("chart.single-chart-aspects", language: language)
                    )
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.text)
                    Spacer()
                    Text(
                        comparison
                            ? localized("chart.rows-move", language: language)
                            : localized("chart.lower-triangle", language: language)
                    )
                    .font(.footnote)
                    .foregroundStyle(AppTheme.muted)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    aspectMatrix
                        .padding(.vertical, 2)
                }

                HStack(spacing: 12) {
                    legend(.supportive, label: localized("chart.flow", language: language))
                    legend(.challenging, label: localized("chart.tone.tension", language: language))
                    legend(.transition, label: localized("chart.change", language: language))
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(localized("chart.aspect-matrix", language: language))

            VStack(spacing: 0) {
                ForEach(aspects.prefix(12)) { aspect in
                    HStack(spacing: 12) {
                        Text(aspect.kind.symbol)
                            .font(.title3)
                            .foregroundStyle(AppTheme.tone(tone(aspect.kind)))
                            .frame(width: 26)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(displayTitle(aspect))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.text)
                            Text("\(localized("chart.orb", language: language)) \(formatOrb(aspect.orbDegrees)) · \(phaseLabel(aspect.phase, language: language))")
                                .font(.caption)
                                .foregroundStyle(AppTheme.muted)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 10)
                    if aspect.id != aspects.prefix(12).last?.id {
                        Divider().overlay(AppTheme.line)
                    }
                }
            }
        }
        .padding(16)
        .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(AppTheme.line))
    }

    private var matrixColumns: [CelestialBody] {
        let points = comparison ? referencePoints : movingPoints
        return CelestialBody.allCases.filter { body in
            points.contains { $0.body == body }
        }
    }

    private var matrixRows: [CelestialBody] {
        let points = movingPoints
        return CelestialBody.allCases.filter { body in
            points.contains { $0.body == body }
        }
    }

    private var aspectMatrix: some View {
        let rows = matrixRows
        let columns = matrixColumns
        return VStack(spacing: 3) {
            HStack(spacing: 3) {
                matrixCorner
                ForEach(columns) { body in
                    Text(body.symbol)
                        .font(AppTypography.scaled(comparison ? 14 : 13, weight: .semibold))
                        .foregroundStyle(comparison ? AppTheme.muted : AppTheme.violet)
                        .frame(width: matrixCellSize, height: matrixCellSize)
                        .accessibilityLabel(bodyName(body, language: language))
                }
            }

            ForEach(Array(rows.enumerated()), id: \.element.id) { rowIndex, rowBody in
                HStack(spacing: 3) {
                    Text(rowBody.symbol)
                        .font(AppTypography.scaled(comparison ? 14 : 13, weight: .semibold))
                        .foregroundStyle(comparison ? AppTheme.violet : AppTheme.muted)
                        .frame(width: matrixCellSize, height: matrixCellSize)
                        .accessibilityLabel(bodyName(rowBody, language: language))

                    ForEach(Array(columns.enumerated()), id: \.element.id) { columnIndex, columnBody in
                        matrixCell(
                            row: rowBody,
                            column: columnBody,
                            rowIndex: rowIndex,
                            columnIndex: columnIndex
                        )
                    }
                }
            }
        }
    }

    private var matrixCorner: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(AppTheme.panelRaised.opacity(0.65))
            if comparison {
                Path { path in
                    path.move(to: CGPoint(x: 4, y: matrixCellSize - 4))
                    path.addLine(to: CGPoint(x: matrixCellSize - 4, y: 4))
                }
                .stroke(AppTheme.line, lineWidth: 1)
            }
        }
        .frame(width: matrixCellSize, height: matrixCellSize)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func matrixCell(
        row: CelestialBody,
        column: CelestialBody,
        rowIndex: Int,
        columnIndex: Int
    ) -> some View {
        if !comparison, columnIndex >= rowIndex {
            RoundedRectangle(cornerRadius: 5)
                .fill(
                    columnIndex == rowIndex
                        ? AppTheme.violet.opacity(0.09)
                        : Color.clear
                )
                .frame(width: matrixCellSize, height: matrixCellSize)
                .accessibilityHidden(true)
        } else if let aspect = matrixAspect(row: row, column: column) {
            Text(aspect.kind.symbol)
                .font(AppTypography.scaled(comparison ? 14 : 13, weight: .bold))
                .foregroundStyle(AppTheme.tone(tone(aspect.kind)))
                .frame(width: matrixCellSize, height: matrixCellSize)
                .background(
                    AppTheme.tone(tone(aspect.kind)).opacity(0.12 + aspect.strength * 0.13),
                    in: RoundedRectangle(cornerRadius: 5)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(
                            AppTheme.tone(tone(aspect.kind)).opacity(0.24),
                            lineWidth: 0.7
                        )
                )
                .accessibilityLabel(displayTitle(aspect))
                .accessibilityValue(
                    "\(localized("chart.orb", language: language)) \(formatOrb(aspect.orbDegrees)), \(phaseLabel(aspect.phase, language: language))"
                )
        } else {
            RoundedRectangle(cornerRadius: 5)
                .fill(AppTheme.panelRaised.opacity(0.42))
                .frame(width: matrixCellSize, height: matrixCellSize)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(AppTheme.line, lineWidth: 0.6)
                )
                .accessibilityLabel(
                    localizedTemplate("dynamic.a9c7b4e126", substitutions: ["value1": String(describing: bodyName(row, language: language)), "value2": String(describing: bodyName(column, language: language))], language: language)
                )
        }
    }

    private func matrixAspect(
        row: CelestialBody,
        column: CelestialBody
    ) -> ChartAspect? {
        aspects.first { aspect in
            if comparison {
                return aspect.firstID == row.id && aspect.secondID == column.id
            }
            return (aspect.firstID == row.id && aspect.secondID == column.id)
                || (aspect.firstID == column.id && aspect.secondID == row.id)
        }
    }

    private var matrixCellSize: CGFloat {
        (comparison ? 34 : 28) * matrixScale
    }

    private func legend(_ tone: InsightTone, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(AppTheme.tone(tone))
                .frame(width: 6, height: 6)
            Text(label)
                .font(.footnote)
                .foregroundStyle(AppTheme.muted)
        }
    }

    private func displayTitle(_ aspect: ChartAspect) -> String {
        guard comparison else { return aspectTitle(aspect, language: language) }
        let moving = CelestialBody(rawValue: aspect.firstID)
            .map { bodyName($0, language: language) } ?? aspect.firstID
        let natal = CelestialBody(rawValue: aspect.secondID)
            .map { bodyName($0, language: language) } ?? aspect.secondID
        return localizedTemplate("dynamic.c7aa5a5c6b", substitutions: ["value1": String(describing: moving), "value2": String(describing: aspect.kind.symbol), "value3": String(describing: natal)], language: language)
    }
}
