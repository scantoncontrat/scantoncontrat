import { supabase } from './lib/supabase.js'

export default async function handler(req, res) {
  if (req.method !== 'POST') return res.status(405).end()

  const { client_id, contrat_id, type_lead, message } = req.body || {}

  if (!client_id) return res.status(400).json({ error: 'client_id manquant' })

  try {
    // Vérifier que le client a bien donné son consentement (RGPD)
    const { data: client } = await supabase
      .from('clients')
      .select('consent_contact, consent_partage_partenaires')
      .eq('id', client_id)
      .single()

    if (!client?.consent_contact) {
      return res.status(403).json({
        error: 'Consentement manquant — le client doit accepter d\'être recontacté'
      })
    }

    const { data: lead, error } = await supabase
      .from('leads')
      .insert({
        client_id,
        contrat_id: contrat_id || null,
        type_lead: type_lead || 'rappel',
        message: message || null,
        statut: 'nouveau'
      })
      .select('id')
      .single()

    if (error) throw error

    // Mettre à jour le statut du client
    await supabase.from('clients')
      .update({ statut: 'actif' })
      .eq('id', client_id)

    // Événement analytics
    await supabase.from('evenements').insert({
      client_id,
      nom: 'generate_lead',
      proprietes: { type_lead, contrat_id }
    })

    return res.status(200).json({ success: true, lead_id: lead.id })

  } catch (err) {
    console.error('Erreur save-lead:', err)
    return res.status(500).json({ error: 'Erreur serveur' })
  }
}
