# Setup Supabase — Scan Ton Contrat

## Étape 1 — Créer le projet Supabase

1. Va sur https://supabase.com et connecte-toi avec GitHub
2. Clique "New project"
3. Remplis :
   - Name : `scantoncontrat`
   - Password : génère un mot de passe fort (note-le !)
   - Region : **West EU (Ireland)** ou **Central EU (Frankfurt)** ← CNIL
4. Attends ~2 minutes

## Étape 2 — Exécuter le schéma SQL

1. Dans Supabase → menu gauche → **SQL Editor**
2. Clique "New query"
3. Copie-colle le contenu de `schema.sql`
4. Clique **Run** (bouton vert)
5. Tu dois voir "Success. No rows returned"

## Étape 3 — Récupérer les clés API

Dans Supabase → menu gauche → **Project Settings** → **API** :

- **Project URL** → copie (ex: https://xxxx.supabase.co)
- **service_role key** → copie (commence par eyJ...) ← GARDE SECRET

## Étape 4 — Ajouter les variables dans Vercel

Sur https://vercel.com → ton projet scantoncontrat → Settings → Environment Variables :

Ajoute ces 2 variables :

| Nom | Valeur |
|-----|--------|
| SUPABASE_URL | https://xxxx.supabase.co |
| SUPABASE_SERVICE_KEY | eyJ... (service_role key) |

Coche "Production", "Preview" et "Development" pour chacune.

## Étape 5 — Installer le package Supabase

Dans le terminal, dans le dossier scantoncontrat :

```bash
cd "/Users/gadankry/claude codage/scantoncontrat"
npm init -y
npm install @supabase/supabase-js
```

## Étape 6 — Redéployer sur Vercel

```bash
vercel --prod
```

## Étape 7 — Vérifier

Dans Supabase → **Table Editor** → tu dois voir les tables créées.
Fais une analyse sur le site → va dans la table `contrats` → tu dois voir l'enregistrement.

---

## Variables d'environnement complètes (Vercel)

| Variable | Description |
|----------|-------------|
| ANTHROPIC_API_KEY | Clé Claude (déjà configurée) |
| SUPABASE_URL | URL du projet Supabase |
| SUPABASE_SERVICE_KEY | Clé service_role Supabase |
| BREVO_API_KEY | Clé Brevo emails (déjà configurée) |
