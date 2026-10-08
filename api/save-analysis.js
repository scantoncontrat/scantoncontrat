import { supabase } from './lib/supabase.js'

export default async function handler(req, res) {
  if (req.method !== 'POST') return res.status(405).end()

  const {
    client_id,
    email,
    type_contrat,
    nom_fichier,
    assureur_actuel,
    cotisation_mensuelle,
    garanties,
    analyse_brute,
    score_qualite,
    points_faibles,
    economie_estimee_mensuelle
  } = req.body || {}

  if (!type_contrat || !analyse_brute) {
    return res.status(400).json({ error: 'Données manquantes' })
  }

  try {
    let resolvedClientId = client_id

    // Si pas de client_id mais un email, retrouver ou créer le client
    if (!resolvedClientId && email) {
      const { data: existing } = await supabase
        .from('clients')
        .select('id')
        .eq('email', email)
        .single()

      if (existing) {
        resolvedClientId = existing.id
      }
    }

    // Sauvegarder l'analyse
    const { data: contrat, error } = await supabase
      .from('contrats')
      .insert({
        client_id: resolvedClientId || null,
        nom_fichier_original: nom_fichier || 'contrat.pdf',
        type_contrat,
        assureur_actuel: assureur_actuel || null,
        cotisation_mensuelle: cotisation_mensuelle || null,
        cotisation_annuelle: cotisation_mensuelle ? cotisation_mensuelle * 12 : null,
        garanties: garanties || null,
        analyse_brute,
        score_qualite: score_qualite || null,
        points_faibles: points_faibles || null,
        economie_estimee_mensuelle: economie_estimee_mensuelle || null,
        economie_estimee_annuelle: economie_estimee_mensuelle ? economie_estimee_mensuelle * 12 : null,
        statut: 'complete',
        analyse_le: new Date().toISOString(),
        // Suppression PDF : pas de stockage permanent (minimisation RGPD)
        pdf_supprime: true,
        pdf_supprime_le: new Date().toISOString()
      })
      .select('id')
      .single()

    if (error) throw error

    // Enregistrer l'événement analytics
    await supabase.from('evenements').insert({
      client_id: resolvedClientId || null,
      nom: 'pdf_analyzed',
      proprietes: {
        type_contrat,
        economie_mensuelle: economie_estimee_mensuelle,
        score_qualite
      }
    })

    return res.status(200).json({ success: true, contrat_id: contrat.id })

  } catch (err) {
    console.error('Erreur save-analysis:', err)
    return res.status(500).json({ error: 'Erreur serveur' })
  }
}
