import { supabase } from './lib/supabase.js'

export default async function handler(req, res) {
  if (req.method !== 'POST') return res.status(405).end()

  const { email, prenom, type_contrat, economie, source } = req.body || {}
  if (!email) return res.status(400).json({ error: 'Email manquant' })

  try {
    // Vérifier si le client existe déjà
    const { data: existing } = await supabase
      .from('clients')
      .select('id, statut')
      .eq('email', email)
      .single()

    let clientId

    if (existing) {
      clientId = existing.id
      // Mettre à jour si prospect
      if (existing.statut === 'prospect') {
        await supabase.from('clients').update({
          prenom: prenom || undefined,
          mis_a_jour_le: new Date().toISOString()
        }).eq('id', clientId)
      }
    } else {
      // Créer le client
      const ip = req.headers['x-forwarded-for']?.split(',')[0] || req.socket?.remoteAddress
      const { data: newClient, error } = await supabase
        .from('clients')
        .insert({
          email,
          prenom: prenom || null,
          statut: 'prospect',
          source: source || 'web',
          consent_analyse: true,
          consent_contact: true,
          consent_date: new Date().toISOString(),
          consent_ip: ip || null,
          consent_version_cgu: 'v1.0'
        })
        .select('id')
        .single()

      if (error) throw error
      clientId = newClient.id

      // Enregistrer l'événement d'inscription
      await supabase.from('evenements').insert({
        client_id: clientId,
        nom: 'inscription',
        proprietes: { type_contrat, economie, source },
        ip_tronquee: ip ? ip.split('.').slice(0, 3).join('.') + '.XXX' : null
      })
    }

    return res.status(200).json({ success: true, client_id: clientId })

  } catch (err) {
    console.error('Erreur subscribe:', err)
    return res.status(500).json({ error: 'Erreur serveur' })
  }
}
