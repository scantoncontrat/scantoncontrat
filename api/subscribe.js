export default async function handler(req, res) {
  if (req.method !== 'POST') return res.status(405).end();

  const { email, name, source } = req.body || {};
  if (!email || !email.includes('@')) return res.status(400).json({ error: 'Email invalide' });

  try {
    const response = await fetch('https://api.brevo.com/v3/contacts', {
      method: 'POST',
      headers: {
        'accept': 'application/json',
        'content-type': 'application/json',
        'api-key': process.env.BREVO_API_KEY,
      },
      body: JSON.stringify({
        email,
        attributes: { PRENOM: name || '', SOURCE: source || 'site' },
        listIds: [5],
        updateEnabled: true,
      }),
    });

    if (response.ok || response.status === 204) {
      return res.status(200).json({ ok: true });
    }
    const err = await response.json();
    return res.status(500).json({ error: err.message });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
}
