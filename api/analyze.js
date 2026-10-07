export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const { pdfBase64, contractType } = req.body;

  if (!pdfBase64) {
    return res.status(400).json({ error: 'PDF requis' });
  }

  try {
    const response = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': process.env.ANTHROPIC_API_KEY,
        'anthropic-version': '2023-06-01',
      },
      body: JSON.stringify({
        model: 'claude-haiku-4-5-20251001',
        max_tokens: 2048,
        messages: [
          {
            role: 'user',
            content: [
              {
                type: 'document',
                source: {
                  type: 'base64',
                  media_type: 'application/pdf',
                  data: pdfBase64,
                },
              },
              {
                type: 'text',
                text: `Tu es un expert en assurance français. Analyse ce contrat et réponds UNIQUEMENT en JSON valide avec cette structure exacte:
{
  "type_contrat": "mutuelle santé | assurance auto | assurance habitation | assurance emprunteur | autre",
  "assureur_actuel": "nom de l'assureur",
  "cotisation_mensuelle": nombre en euros ou null,
  "garanties_principales": ["garantie 1", "garantie 2", "garantie 3"],
  "points_forts": ["point 1", "point 2"],
  "points_faibles": ["point 1", "point 2"],
  "economie_estimee_mensuelle": nombre en euros (estimation réaliste de ce qu'on peut économiser),
  "recommandations": ["recommandation 1", "recommandation 2"],
  "score_optimisation": nombre entre 1 et 10 (10 = très optimisable)
}
Si tu ne peux pas lire le document ou s'il ne s'agit pas d'un contrat d'assurance/énergie, renvoie: {"erreur": "Document non reconnu"}`,
              },
            ],
          },
        ],
      }),
    });

    if (!response.ok) {
      const err = await response.json();
      console.error('Anthropic error:', err);
      return res.status(500).json({ error: 'Erreur analyse IA' });
    }

    const data = await response.json();
    const text = data.content[0].text;

    let result;
    try {
      const jsonMatch = text.match(/\{[\s\S]*\}/);
      result = JSON.parse(jsonMatch ? jsonMatch[0] : text);
    } catch {
      result = { erreur: 'Impossible de parser la réponse' };
    }

    return res.status(200).json(result);
  } catch (error) {
    console.error('Error:', error);
    return res.status(500).json({ error: 'Erreur serveur' });
  }
}
