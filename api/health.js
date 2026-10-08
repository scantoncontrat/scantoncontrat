// Point 5 : monitoring — appelé par un cron externe (ex: UptimeRobot)
// Si l'API Claude ou Supabase est down, envoie une alerte email via Brevo
export default async function handler(req, res) {
  const checks = { anthropic: false, supabase: false }
  const errors = []

  // Check Anthropic
  try {
    const r = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': process.env.ANTHROPIC_API_KEY,
        'anthropic-version': '2023-06-01',
      },
      body: JSON.stringify({
        model: 'claude-haiku-4-5',
        max_tokens: 10,
        messages: [{ role: 'user', content: 'ping' }],
      }),
    })
    checks.anthropic = r.ok
    if (!r.ok) errors.push('Anthropic API down: ' + r.status)
  } catch (e) {
    errors.push('Anthropic unreachable: ' + e.message)
  }

  // Check Supabase
  try {
    const r = await fetch(`${process.env.SUPABASE_URL}/rest/v1/`, {
      headers: { 'apikey': process.env.SUPABASE_SERVICE_KEY }
    })
    checks.supabase = r.ok
    if (!r.ok) errors.push('Supabase down: ' + r.status)
  } catch (e) {
    errors.push('Supabase unreachable: ' + e.message)
  }

  const healthy = checks.anthropic && checks.supabase

  // Alerte email si problème
  if (!healthy && process.env.BREVO_API_KEY) {
    await fetch('https://api.brevo.com/v3/smtp/email', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'api-key': process.env.BREVO_API_KEY },
      body: JSON.stringify({
        sender: { name: 'Scan Ton Contrat Monitor', email: 'contact@scantoncontrat.fr' },
        to: [{ email: 'gad.ankry@gmail.com' }],
        subject: '🚨 ALERTE — Scan Ton Contrat : service dégradé',
        htmlContent: `<p>Des services sont en erreur :</p><ul>${errors.map(e => `<li>${e}</li>`).join('')}</ul><p>Vérifie immédiatement sur <a href="https://scantoncontrat.fr">scantoncontrat.fr</a></p>`,
      }),
    }).catch(() => {})
  }

  return res.status(healthy ? 200 : 503).json({ healthy, checks, errors })
}
