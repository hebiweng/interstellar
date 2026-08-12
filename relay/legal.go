package main

import (
	"html/template"
	"net/http"
	"strings"
)

type legalCopy struct {
	Language string
	Title    string
	Updated  string
	Body     template.HTML
}

var privacyCopies = []legalCopy{
	{"English", "Privacy Policy", "Updated 12 August 2026", `<p>Interstellar calculates astrological facts on your device. When you explicitly request an AI report, the calculated facts required for that report are sent to Interstellar Relay and the configured AI provider.</p><p>Relay stores an anonymous user identifier, installation link, subscription and Credit records, and report delivery metadata. Relay never stores generated report text or birth-profile content. A report is charged only after the app confirms that it saved the report locally.</p><p>If you enable iCloud Backup, profiles, reports and settings are stored in your private iCloud container governed by your Apple account. You can disable backup in Settings.</p>`},
	{"简体中文", "隐私政策", "更新于 2026 年 8 月 12 日", `<p>Interstellar 在设备本地计算占星事实。只有当你明确请求 AI 报告时，该报告所需的已计算事实才会发送至 Interstellar Relay 和当前配置的 AI 提供方。</p><p>Relay 保存匿名用户标识、安装关联、订阅与 Credit 记录，以及报告交付元数据。Relay 永不保存生成的报告正文或出生档案内容。只有 App 确认报告已在本地保存后才会扣除 Credit。</p><p>如果启用 iCloud 备份，人物、报告和设置会保存在由你的 Apple 账户管理的私人 iCloud 容器中；可随时在设置中关闭。</p>`},
	{"Español", "Política de privacidad", "Actualizada el 12 de agosto de 2026", `<p>Interstellar calcula los datos astrológicos en tu dispositivo. Solo cuando solicitas expresamente un informe de IA se envían los datos calculados necesarios a Interstellar Relay y al proveedor de IA configurado.</p><p>Relay conserva un identificador anónimo, la vinculación de la instalación, los registros de suscripción y Credits y metadatos de entrega. Relay nunca almacena el texto del informe ni los datos del perfil natal. El Credit se consume únicamente cuando la app confirma que guardó el informe localmente.</p><p>Si activas la copia en iCloud, los perfiles, informes y ajustes se guardan en tu contenedor privado de iCloud.</p>`},
	{"Français", "Politique de confidentialité", "Mise à jour le 12 août 2026", `<p>Interstellar calcule les faits astrologiques sur votre appareil. Les faits nécessaires ne sont envoyés à Interstellar Relay et au fournisseur d’IA configuré que lorsque vous demandez explicitement un rapport IA.</p><p>Relay conserve un identifiant anonyme, le lien d’installation, les données d’abonnement et de Credits, ainsi que les métadonnées de livraison. Relay ne conserve jamais le texte des rapports ni les données du profil natal. Un Credit n’est consommé qu’après confirmation de l’enregistrement local par l’app.</p><p>Si la sauvegarde iCloud est activée, profils, rapports et réglages sont enregistrés dans votre conteneur iCloud privé.</p>`},
}

var termsCopies = []legalCopy{
	{"English", "Terms of Use", "Updated 12 August 2026", `<p>Interstellar provides astrological calculations and interpretive content for personal reflection and entertainment. It is not medical, legal, financial or emergency advice.</p><p>Premium Monthly and Premium Annual renew automatically unless cancelled in your Apple account settings. Purchased Credits are consumable and do not expire. Free or Premium allowance Credits refill according to the plan and unused allowance may be replaced at the next refill.</p><p>An AI report consumes one Credit only after it passes validation, is saved locally and the app acknowledges delivery. If delivery is not acknowledged, the reservation is released. Purchases and subscriptions are also governed by Apple’s Standard EULA.</p>`},
	{"简体中文", "使用条款", "更新于 2026 年 8 月 12 日", `<p>Interstellar 提供占星计算和解读内容，用于个人思考与娱乐，不构成医疗、法律、财务或紧急建议。</p><p>Premium 月度和年度订阅会自动续订，除非你在 Apple 账户设置中取消。购买的 Credits 属于消耗型项目且永久有效；免费或 Premium 配额按方案补充，未使用的配额可能在下一周期被替换。</p><p>AI 报告只有在通过验证、成功保存到本地并由 App 确认交付后才消费 1 Credit；未确认交付则释放预留。购买和订阅同时受 Apple 标准最终用户许可协议约束。</p>`},
	{"Español", "Términos de uso", "Actualizados el 12 de agosto de 2026", `<p>Interstellar ofrece cálculos astrológicos y contenido interpretativo para reflexión personal y entretenimiento. No constituye asesoramiento médico, jurídico, financiero ni de emergencia.</p><p>Premium Mensual y Anual se renuevan automáticamente salvo cancelación en los ajustes de la cuenta Apple. Los Credits comprados son consumibles y no caducan; los Credits de asignación se renuevan según el plan.</p><p>Un informe de IA consume un Credit solo tras validarse, guardarse localmente y confirmarse la entrega. Sin confirmación, la reserva se libera. También se aplica el EULA estándar de Apple.</p>`},
	{"Français", "Conditions d’utilisation", "Mises à jour le 12 août 2026", `<p>Interstellar fournit des calculs astrologiques et des interprétations à des fins de réflexion personnelle et de divertissement. Il ne s’agit pas d’un conseil médical, juridique, financier ou d’urgence.</p><p>Premium mensuel et annuel se renouvellent automatiquement sauf annulation dans les réglages du compte Apple. Les Credits achetés sont consommables et n’expirent pas ; les Credits d’allocation sont renouvelés selon l’offre.</p><p>Un rapport IA consomme un Credit uniquement après validation, enregistrement local et confirmation de livraison. Sans confirmation, la réservation est libérée. Le contrat de licence standard Apple s’applique également.</p>`},
}

func handleLegalPage(w http.ResponseWriter, r *http.Request) {
	copies := privacyCopies
	if strings.HasPrefix(r.URL.Path, "/terms") {
		copies = termsCopies
	}
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.Header().Set("Cache-Control", "public, max-age=3600")
	_, _ = w.Write([]byte(`<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Interstellar</title><style>body{max-width:760px;margin:40px auto;padding:0 20px;background:#0b0d16;color:#f2f2f7;font:16px/1.65 system-ui}section{padding:20px 0;border-bottom:1px solid #2b3042}h1{margin-bottom:4px}small{color:#9ea5bb}a{color:#a98bff}</style></head><body>`))
	for _, copy := range copies {
		_, _ = w.Write([]byte("<section><small>" + template.HTMLEscapeString(copy.Language) + "</small><h1>" + template.HTMLEscapeString(copy.Title) + "</h1><small>" + template.HTMLEscapeString(copy.Updated) + "</small>" + string(copy.Body) + "</section>"))
	}
	_, _ = w.Write([]byte(`<p><a href="https://www.apple.com/legal/internet-services/itunes/dev/stdeula/">Apple Standard EULA</a></p></body></html>`))
}
