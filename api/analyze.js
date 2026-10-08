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
        model: 'claude-haiku-4-5',
        max_tokens: 3000,
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
                text: `Tu es un expert courtier en assurance français avec 20 ans d'expérience. Analyse ce contrat d'assurance en détail et réponds UNIQUEMENT en JSON valide avec cette structure exacte (sans texte avant ou après) :

{
  "type_contrat": "mutuelle santé" | "assurance auto" | "assurance habitation" | "assurance emprunteur" | "contrat énergie" | "autre",
  "assureur_actuel": "nom exact de l'assureur tel qu'écrit dans le document",
  "cotisation_mensuelle": nombre décimal en euros (cherche le montant mensuel, divise par 12 si annuel) ou null si introuvable,
  "garanties_principales": ["liste de 3 à 6 garanties clés détectées dans le contrat, formulées simplement"],
  "points_forts": ["2 à 4 vrais points forts de ce contrat spécifique"],
  "points_faibles": ["2 à 4 vraies lacunes ou surcoûts détectés dans ce contrat"],
  "economie_estimee_mensuelle": nombre entier en euros (estimation réaliste entre 10% et 35% de la cotisation selon le marché actuel),
  "recommandations": ["3 à 5 recommandations concrètes et actionnables pour l'assuré"],
  "score_optimisation": nombre entier entre 1 et 10 (1=contrat optimal difficile à battre, 10=contrat très coûteux à changer absolument),
  "details_garanties": {
    "franchise": "montant de la franchise si mentionné ou null",
    "plafond_annuel": "plafond de remboursement annuel si mentionné ou null",
    "delai_carence": "délai de carence si mentionné ou null"
  }
}

Règles importantes :
- Si la cotisation est annuelle, divise par 12 pour obtenir le mensuel
- Le score_optimisation doit refléter la réalité : un contrat récent bien négocié mérite 3-4, un vieux contrat jamais renégocié mérite 7-8
- Les économies doivent être réalistes (entre 10% et 35% de la cotisation)
- Si le document n'est pas un contrat d'assurance ou d'énergie, renvoie uniquement : {"erreur": "Document non reconnu - veuillez soumettre un contrat d'assurance ou d'énergie"}`,
              },
            ],
          },
        ],
      }),
    });

    if (!response.ok) {
      const err = await response.json();
      console.error('Anthropic error:', err);
      return res.status(500).json({ error: 'Erreur analyse IA', detail: err });
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
