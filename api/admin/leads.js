import { createClient } from '@supabase/supabase-js'

const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_KEY, {
  auth: { persistSession: false }
})

const ADMIN_TOKEN = process.env.ADMIN_TOKEN

export default async function handler(req, res) {
  // Auth simple par token
  const token = req.headers['x-admin-token'] || req.query.token
  if (!ADMIN_TOKEN || token !== ADMIN_TOKEN) {
    return res.status(401).json({ error: 'Non autorisé' })
  }

  try {
    const { data: analyses, error } = await supabase
      .from('contrats')
      .select('id, type_contrat, assureur_actuel, cotisation_mensuelle, economie_estimee_mensuelle, score_qualite, statut, analyse_le, client_id')
      .order('analyse_le', { ascending: false })
      .limit(100)

    if (error) throw error

    // Leads (clients avec email)
    const { data: clients } = await supabase
      .from('clients')
      .select('id, email, prenom, telephone, statut, created_at')
      .order('created_at', { ascending: false })
      .limit(100)

    const stats = {
      total_analyses: analyses?.length || 0,
      total_leads: clients?.length || 0,
      economie_moyenne: analyses?.length
        ? Math.round(analyses.filter(a => a.economie_estimee_mensuelle).reduce((s, a) => s + a.economie_estimee_mensuelle, 0) / analyses.filter(a => a.economie_estimee_mensuelle).length)
        : 0,
    }

    return res.status(200).json({ stats, analyses, clients })
  } catch (err) {
    console.error('Admin error:', err)
    return res.status(500).json({ error: 'Erreur serveur' })
  }
}
