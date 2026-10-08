export default async function handler(req, res) {
  if (req.method !== 'POST') return res.status(405).end();

  const { message, history } = req.body || {};
  if (!message) return res.status(400).json({ error: 'Message manquant' });

  const systemPrompt = `Tu es l'assistant de Scan Ton Contrat, un service français qui analyse les contrats d'assurance avec l'IA et trouve des offres moins chères.

Ton rôle : répondre aux questions des visiteurs sur les assurances (mutuelle santé, auto, habitation, emprunteur), les aider à comprendre leurs contrats, et les encourager à utiliser l'outil d'analyse gratuit.

Règles :
- Réponds toujours en français, de façon concise (2-4 phrases max)
- Tu es friendly, professionnel et bienveillant
- Si quelqu'un demande à parler à un humain ou un expert, dis-leur de laisser leur email dans le formulaire en bas de page
- Ne donne pas de conseils financiers personnalisés spécifiques, mais explique les mécanismes généraux
- Mets en avant que l'analyse est 100% gratuite et que le PDF n'est jamais stocké
- Les économies moyennes constatées sont de 20 à 50 €/mois selon le contrat

Informations clés :
- Service gratuit, rémunération uniquement sur souscription partenaire
- Contrats analysés : mutuelle, auto, habitation, emprunteur
- Délai de résiliation : loi Hamon permet de résilier à tout moment après 1 an (auto, habitation), loi Lemoine pour la mutuelle et l'emprunteur
- PDF analysé en temps réel, jamais stocké sur nos serveurs`;

  const messages = [];
  if (history && Array.isArray(history)) {
    history.slice(-6).forEach(m => {
      messages.push({ role: m.from === 'user' ? 'user' : 'assistant', content: m.text });
    });
  }
  messages.push({ role: 'user', content: message });

  try {
    const response = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': process.env.ANTHROPIC_API_KEY,
        'anthropic-version': '2023-06-01'
      },
      body: JSON.stringify({
        model: 'claude-haiku-4-5-20251001',
        max_tokens: 300,
        system: systemPrompt,
        messages
      })
    });

    if (!response.ok) throw new Error('API error');
    const data = await response.json();
    const reply = data.content?.[0]?.text || "Désolé, je n'ai pas pu répondre. Réessayez ou laissez votre email pour qu'un expert vous contacte.";
    return res.status(200).json({ reply });
  } catch (e) {
    return res.status(500).json({ reply: "Une erreur est survenue. Vous pouvez laisser votre email dans le formulaire et nos experts vous répondront sous 24h !" });
  }
}
