import Foundation

enum LocalizedFormatters {
    static func shortDate(_ date: Date, language: AppLanguage, timeZone: TimeZone = .current) -> String {
        formattedDate(date, template: "MMMd", language: language, timeZone: timeZone)
    }

    static func monthYear(_ date: Date, language: AppLanguage, timeZone: TimeZone = .current) -> String {
        formattedDate(date, template: "yMMM", language: language, timeZone: timeZone)
    }

    static func time(_ date: Date, language: AppLanguage, timeZone: TimeZone = .current) -> String {
        formattedDate(date, template: "jm", language: language, timeZone: timeZone)
    }

    static func formattedDate(
        _ date: Date,
        template: String,
        language: AppLanguage,
        timeZone: TimeZone = .current
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = language.locale
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter.string(from: date)
    }

    static func savedQuestions(_ count: Int, language: AppLanguage) -> String {
        switch language {
        case .english: count == 1 ? "1 saved locally" : "\(count) saved locally"
        case .simplifiedChinese: "本机已保存 \(count) 条"
        case .spanish: count == 1 ? "1 pregunta guardada en el dispositivo" : "\(count) preguntas guardadas en el dispositivo"
        case .french: count == 1 ? "1 question enregistrée sur l’appareil" : "\(count) questions enregistrées sur l’appareil"
        }
    }

    static func nextDays(_ count: Int, language: AppLanguage) -> String {
        switch language {
        case .english: count == 1 ? "Next day" : "Next \(count) days"
        case .simplifiedChinese: "未来\(count)天"
        case .spanish: count == 1 ? "Próximo día" : "Próximos \(count) días"
        case .french: count == 1 ? "Jour suivant" : "\(count) prochains jours"
        }
    }

    static func nextMonths(_ count: Int, language: AppLanguage) -> String {
        switch language {
        case .english: count == 1 ? "Next month" : "Next \(count) months"
        case .simplifiedChinese: "未来\(count)个月"
        case .spanish: count == 1 ? "Próximo mes" : "Próximos \(count) meses"
        case .french: count == 1 ? "Mois suivant" : "\(count) prochains mois"
        }
    }

    static func hoursDuration(_ count: Int, language: AppLanguage) -> String {
        switch language {
        case .english: " · about \(count)h"
        case .simplifiedChinese: " · 约\(count)小时"
        case .spanish: " · unas \(count) h"
        case .french: " · environ \(count) h"
        }
    }

    static func remainingDays(_ count: Int, language: AppLanguage) -> String {
        switch language {
        case .english: count == 1 ? "1d left" : "\(count)d left"
        case .simplifiedChinese: "剩 \(count) 天"
        case .spanish: count == 1 ? "Queda 1 día" : "Quedan \(count) días"
        case .french: count == 1 ? "Encore 1 jour" : "Encore \(count) jours"
        }
    }

    static func remainingHours(_ count: Int, language: AppLanguage) -> String {
        switch language {
        case .english: count == 1 ? "1h left" : "\(count)h left"
        case .simplifiedChinese: "剩 \(count) 小时"
        case .spanish: count == 1 ? "Queda 1 hora" : "Quedan \(count) horas"
        case .french: count == 1 ? "Encore 1 heure" : "Encore \(count) heures"
        }
    }

    static func readingMinutes(_ count: Int, language: AppLanguage) -> String {
        switch language {
        case .english: count == 1 ? "1 min read" : "\(count) min read"
        case .simplifiedChinese: "约\(count)分钟"
        case .spanish: count == 1 ? "1 min de lectura" : "\(count) min de lectura"
        case .french: count == 1 ? "1 min de lecture" : "\(count) min de lecture"
        }
    }

    static func viewAllAreas(_ count: Int, language: AppLanguage) -> String {
        switch language {
        case .english: "View all \(count) areas"
        case .simplifiedChinese: "查看全部\(count)个领域"
        case .spanish: "Ver las \(count) áreas"
        case .french: "Voir les \(count) domaines"
        }
    }

    static func day(_ number: Int, language: AppLanguage) -> String {
        switch language {
        case .english: "Day \(number)"
        case .simplifiedChinese: "第\(number)天"
        case .spanish: "Día \(number)"
        case .french: "Jour \(number)"
        }
    }

    static func calendarDay(_ number: Int, language: AppLanguage) -> String {
        switch language {
        case .english: "Day \(number)"
        case .simplifiedChinese: "\(number)日"
        case .spanish: "Día \(number)"
        case .french: "Jour \(number)"
        }
    }

    static func exactAgain(_ date: String, language: AppLanguage) -> String {
        switch language {
        case .english: "Exact again \(date)"
        case .simplifiedChinese: "再次精确 \(date)"
        case .spanish: "Exacto de nuevo el \(date)"
        case .french: "À nouveau exact le \(date)"
        }
    }

    static func quarter(_ number: Int, language: AppLanguage) -> String {
        switch language {
        case .english: "Quarter \(number)"
        case .simplifiedChinese: "第\(number)阶段"
        case .spanish: "Trimestre \(number)"
        case .french: "Trimestre \(number)"
        }
    }

    static func retrogradePlanets(_ count: Int, language: AppLanguage) -> String {
        switch language {
        case .english: count == 1 ? "1 planet retrograde" : "\(count) planets retrograde"
        case .simplifiedChinese: "\(count)颗行星处于逆行"
        case .spanish: count == 1 ? "1 planeta retrógrado" : "\(count) planetas retrógrados"
        case .french: count == 1 ? "1 planète rétrograde" : "\(count) planètes rétrogrades"
        }
    }
}
