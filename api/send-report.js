export default async function handler(req, res) {
  if (req.method !== 'POST') return res.status(405).end()

  const { email, prenom, analyse } = req.body || {}
  if (!email || !analyse) return res.status(400).json({ error: 'Données manquantes' })

  const nom = prenom || 'là'
  const economie = analyse.economie_estimee_mensuelle || 0
  const assureur = analyse.assureur_actuel || 'votre assureur actuel'
  const score = analyse.score_optimisation || 5
  const type = analyse.type_contrat || 'contrat d\'assurance'

  const scoreLabel = score >= 7 ? '🔴 À changer rapidement' : score >= 5 ? '🟡 Optimisable' : '🟢 Contrat correct'

  const garanties = (analyse.garanties_principales || []).map(g => `<li style="margin-bottom:6px">✓ ${g}</li>`).join('')
  const pointsFaibles = (analyse.points_faibles || []).map(p => `<li style="margin-bottom:6px">⚠️ ${p}</li>`).join('')
  const recommandations = (analyse.recommandations || []).map(r => `<li style="margin-bottom:8px">${r}</li>`).join('')

  const html = `
<!DOCTYPE html>
<html lang="fr">
<head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
<body style="margin:0;padding:0;background:#f0f4f8;font-family:'Helvetica Neue',Arial,sans-serif">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#f0f4f8;padding:40px 20px">
    <tr><td align="center">
      <table width="600" cellpadding="0" cellspacing="0" style="max-width:600px;width:100%">

        <!-- Header -->
        <tr><td style="background:#0f1f4a;border-radius:12px 12px 0 0;padding:28px 32px;text-align:center">
          <div style="font-size:22px;font-weight:700;color:#ffffff">Scan Ton <span style="color:#10b981">Contrat</span></div>
          <div style="font-size:13px;color:#94a3b8;margin-top:4px">Votre rapport d'analyse</div>
        </td></tr>

        <!-- Body -->
        <tr><td style="background:#ffffff;padding:32px">
          <p style="font-size:16px;color:#0d1526;margin:0 0 24px">Bonjour ${nom},</p>
          <p style="color:#4a5578;margin:0 0 24px">Voici votre rapport d'analyse pour votre <strong>${type}</strong> chez <strong>${assureur}</strong>.</p>

          <!-- Score -->
          <div style="background:#f8f9fb;border-radius:10px;padding:20px;margin-bottom:24px;text-align:center">
            <div style="font-size:13px;color:#4a5578;margin-bottom:8px;text-transform:uppercase;letter-spacing:0.5px">Score d'optimisation</div>
            <div style="font-size:48px;font-weight:700;color:#0f1f4a">${score}<span style="font-size:24px">/10</span></div>
            <div style="font-size:14px;margin-top:8px">${scoreLabel}</div>
          </div>

          <!-- Économie -->
          ${economie > 0 ? `
          <div style="background:#ecfdf5;border:1px solid #10b981;border-radius:10px;padding:20px;margin-bottom:24px;text-align:center">
            <div style="font-size:13px;color:#065f46;margin-bottom:4px">Économie estimée</div>
            <div style="font-size:36px;font-weight:700;color:#10b981">${economie}€<span style="font-size:16px">/mois</span></div>
            <div style="font-size:13px;color:#065f46">soit <strong>${economie * 12}€/an</strong> d'économies potentielles</div>
          </div>` : ''}

          <!-- Garanties -->
          ${garanties ? `
          <h3 style="font-size:15px;color:#0d1526;margin:0 0 12px">Garanties détectées</h3>
          <ul style="color:#4a5578;padding-left:20px;margin:0 0 24px">${garanties}</ul>` : ''}

          <!-- Points faibles -->
          ${pointsFaibles ? `
          <h3 style="font-size:15px;color:#0d1526;margin:0 0 12px">Points à améliorer</h3>
          <ul style="color:#4a5578;padding-left:20px;margin:0 0 24px">${pointsFaibles}</ul>` : ''}

          <!-- Recommandations -->
          ${recommandations ? `
          <h3 style="font-size:15px;color:#0d1526;margin:0 0 12px">Nos recommandations</h3>
          <ol style="color:#4a5578;padding-left:20px;margin:0 0 24px">${recommandations}</ol>` : ''}

          <!-- CTA -->
          <div style="text-align:center;margin-top:32px">
            <a href="https://www.scantoncontrat.fr" style="background:#10b981;color:#ffffff;padding:14px 32px;border-radius:8px;text-decoration:none;font-weight:600;font-size:15px;display:inline-block">
              Trouver une meilleure offre →
            </a>
          </div>
        </td></tr>

        <!-- Footer -->
        <tr><td style="background:#f8f9fb;border-radius:0 0 12px 12px;padding:20px 32px;text-align:center">
          <p style="font-size:12px;color:#94a3b8;margin:0">
            AGA Consulting SASU — SIRET 89168438300021<br>
            Ce rapport est fourni à titre informatif et ne constitue pas un conseil en assurance.<br>
            <a href="https://www.scantoncontrat.fr/legal.html" style="color:#94a3b8">Mentions légales</a> ·
            <a href="mailto:contact@scantoncontrat.fr" style="color:#94a3b8">Se désinscrire</a>
          </p>
        </td></tr>

      </table>
    </td></tr>
  </table>
</body>
</html>`

  try {
    const response = await fetch('https://api.brevo.com/v3/smtp/email', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'api-key': process.env.BREVO_API_KEY,
      },
      body: JSON.stringify({
        sender: { name: 'Scan Ton Contrat', email: 'contact@scantoncontrat.fr' },
        to: [{ email, name: prenom || '' }],
        subject: `📋 Votre rapport d'analyse — économie estimée ${economie}€/mois`,
        htmlContent: html,
      }),
    })

    if (!response.ok) {
      const err = await response.json()
      console.error('Brevo error:', err)
      return res.status(500).json({ error: 'Erreur envoi email' })
    }

    return res.status(200).json({ success: true })
  } catch (err) {
    console.error('Erreur send-report:', err)
    return res.status(500).json({ error: 'Erreur serveur' })
  }
}
