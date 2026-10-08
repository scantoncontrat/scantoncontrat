import { createClient } from '@supabase/supabase-js'

const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_KEY, { auth: { persistSession: false } })

export default async function handler(req, res) {
  if (req.method !== 'POST') return res.status(405).end()

  const { email, prenom, telephone, type_contrat, source, message } = req.body || {}
  if (!email) return res.status(400).json({ error: 'Email manquant' })

  try {
    // Upsert client
    const { data: client, error: clientErr } = await supabase
      .from('clients')
      .upsert({ email, prenom: prenom || null, telephone: telephone || null, statut: 'actif', consent_contact: true }, { onConflict: 'email' })
      .select('id').single()

    if (clientErr) throw clientErr

    // Créer le lead
    await supabase.from('leads').insert({
      client_id: client.id,
      type_lead: source || 'devis_formulaire',
      message: message || type_contrat || null,
      statut: 'nouveau'
    })

    // Événement analytics
    await supabase.from('evenements').insert({
      client_id: client.id,
      nom: 'lead_created',
      proprietes: { source, type_contrat }
    })

    return res.status(200).json({ success: true })
  } catch (err) {
    console.error('Erreur save-lead:', err)
    return res.status(500).json({ error: 'Erreur serveur' })
  }
}
