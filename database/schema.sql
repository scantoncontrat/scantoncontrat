-- ============================================================
--  SCAN TON CONTRAT — Schéma base de données
--  Conforme RGPD / CNIL / DDA / Code des assurances
--  AGA Consulting SASU — SIRET 89168438300021 — 2026
--
--  Références réglementaires appliquées :
--  - RGPD art. 4, 5, 6, 7, 9, 13, 17, 25, 30, 32
--  - Loi Informatique et Libertés modifiée
--  - Directive Distribution Assurance (DDA) 2016/97/UE
--  - Code des assurances art. L521-1 et suivants
--  - CNIL : durées de conservation (guide avril 2026)
--  - eIDAS pour la signature électronique
-- ============================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================
-- NOTE CNIL — DONNÉES DE SANTÉ (art. 9 RGPD)
-- Les contrats mutuelle/emprunteur contiennent potentiellement
-- des données de santé (catégorie "sensible" art. 9 RGPD).
-- Obligations supplémentaires :
--   1. Consentement EXPLICITE et SÉPARÉ requis
--   2. Chiffrement obligatoire (colonne garanties pour mutuelle)
--   3. Registre des traitements mis à jour
--   4. Pas de transfert hors UE sans garanties adéquates
--   5. DPO recommandé si traitement à grande échelle
-- ============================================================

-- ============================================================
-- 1. CLIENTS
-- Durée conservation CNIL :
--   - Données actives : durée de la relation commerciale
--   - Archivage intermédiaire : 5 ans après fin relation (DDA)
--   - Facturation : 10 ans (Code de commerce art. L123-22)
--   - Prospection : 3 ans sans contact (CNIL recommandation)
-- ============================================================
CREATE TABLE clients (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email           VARCHAR(255) NOT NULL UNIQUE,
  prenom          VARCHAR(100),
  nom             VARCHAR(100),
  telephone       VARCHAR(20),
  date_naissance  DATE,
  code_postal     VARCHAR(10),
  ville           VARCHAR(100),

  -- ── CONSENTEMENTS RGPD (art. 7 RGPD — preuve du consentement) ──
  -- Chaque consentement doit être granulaire, libre, documenté
  consent_analyse         BOOLEAN NOT NULL DEFAULT FALSE, -- Analyse contrat par IA
  consent_contact         BOOLEAN NOT NULL DEFAULT FALSE, -- Être recontacté par partenaire
  consent_marketing       BOOLEAN NOT NULL DEFAULT FALSE, -- Emails marketing
  consent_donnees_sante   BOOLEAN NOT NULL DEFAULT FALSE, -- OBLIGATOIRE si mutuelle/emprunteur (art. 9)
  consent_partage_partenaires BOOLEAN NOT NULL DEFAULT FALSE, -- Transmission aux assureurs
  -- Horodatage et preuve (art. 7 RGPD — charge de la preuve sur le RT)
  consent_date            TIMESTAMPTZ,
  consent_ip              INET,      -- IP au moment du consentement
  consent_version_cgu     VARCHAR(20), -- Ex: "v1.2" — version CGU acceptée
  -- Demandes d'exercice des droits (art. 15-22 RGPD)
  droit_acces_demande_le  TIMESTAMPTZ,
  droit_rectif_demande_le TIMESTAMPTZ,
  droit_efface_demande_le TIMESTAMPTZ, -- Droit à l'effacement art. 17
  droit_portab_demande_le TIMESTAMPTZ, -- Portabilité art. 20
  droit_oppos_demande_le  TIMESTAMPTZ, -- Opposition art. 21

  -- ── AUTHENTIFICATION ──
  mot_de_passe_hash       TEXT,      -- bcrypt ou argon2 UNIQUEMENT
  token_reset             VARCHAR(255),
  token_reset_exp         TIMESTAMPTZ,
  email_verifie           BOOLEAN DEFAULT FALSE,
  token_verification      VARCHAR(255),
  derniere_connexion      TIMESTAMPTZ,
  nb_tentatives_echec     INTEGER DEFAULT 0, -- Anti-bruteforce
  compte_bloque_jusqu     TIMESTAMPTZ,

  -- ── STATUT ──
  statut          VARCHAR(20) DEFAULT 'prospect'
                  CHECK (statut IN ('prospect','actif','converti','desabonne','supprime')),
  source          VARCHAR(50),   -- 'web','app','partenaire','seo'
  utm_source      VARCHAR(100),
  utm_medium      VARCHAR(100),
  utm_campaign    VARCHAR(100),

  -- ── DURÉES CONSERVATION (CNIL) ──
  -- Suppression auto si prospect sans activité depuis 3 ans (calculé à l'insert)
  supprimer_si_inactif_le DATE,
  -- Archivage après fin relation commerciale (5 ans DDA)
  archiver_le             DATE,  -- Mis à jour à chaque souscription
  -- Anonymisation (alternative à la suppression pour stats)
  anonymise               BOOLEAN DEFAULT FALSE,
  anonymise_le            TIMESTAMPTZ,

  -- ── TIMESTAMPS ──
  cree_le         TIMESTAMPTZ DEFAULT NOW(),
  mis_a_jour_le   TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_clients_email           ON clients(email);
CREATE INDEX idx_clients_statut          ON clients(statut);
CREATE INDEX idx_clients_cree_le         ON clients(cree_le);
CREATE INDEX idx_clients_supprimer       ON clients(supprimer_si_inactif_le);


-- ============================================================
-- 2. REGISTRE DES TRAITEMENTS (art. 30 RGPD — OBLIGATOIRE)
-- Tenu par le Responsable de Traitement (AGA Consulting SASU)
-- Doit être présenté à la CNIL en cas de contrôle
-- ============================================================
CREATE TABLE registre_traitements (
  id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  nom_traitement      VARCHAR(200) NOT NULL,
  finalite            TEXT NOT NULL,          -- Pourquoi ces données
  base_legale         VARCHAR(50) NOT NULL    -- Voir CHECK ci-dessous
                      CHECK (base_legale IN (
                        'consentement',        -- art. 6.1.a
                        'execution_contrat',   -- art. 6.1.b
                        'obligation_legale',   -- art. 6.1.c
                        'interet_vital',       -- art. 6.1.d
                        'mission_publique',    -- art. 6.1.e
                        'interet_legitime'     -- art. 6.1.f
                      )),
  categories_donnees  TEXT,                  -- Types de données traitées
  categories_personnes TEXT,                 -- Qui est concerné
  destinataires       TEXT,                  -- Qui reçoit les données
  transferts_hors_ue  BOOLEAN DEFAULT FALSE,
  garanties_transfert TEXT,                  -- Clauses contractuelles types, etc.
  duree_conservation  TEXT NOT NULL,         -- Durée en base active
  duree_archivage     TEXT,                  -- Archivage intermédiaire
  mesures_securite    TEXT,                  -- Chiffrement, pseudonymisation, etc.
  donnees_sensibles   BOOLEAN DEFAULT FALSE, -- Art. 9 RGPD
  aipd_requise        BOOLEAN DEFAULT FALSE, -- Analyse d'impact requise
  aipd_realisee_le    DATE,
  -- Timestamps
  cree_le             TIMESTAMPTZ DEFAULT NOW(),
  mis_a_jour_le       TIMESTAMPTZ DEFAULT NOW()
);

-- Pré-remplissage du registre pour Scan Ton Contrat
INSERT INTO registre_traitements (
  nom_traitement, finalite, base_legale, categories_donnees,
  categories_personnes, destinataires, duree_conservation,
  duree_archivage, mesures_securite, donnees_sensibles, aipd_requise
) VALUES
(
  'Analyse de contrats d''assurance par IA',
  'Analyser les contrats PDF uploadés par les utilisateurs pour identifier les surcoûts et recommander des offres alternatives',
  'consentement',
  'Email, contrats PDF (pouvant contenir données de santé pour mutuelles)',
  'Prospects et clients particuliers',
  'Prestataire IA (Anthropic/Claude), hébergeur (Vercel/AWS EU)',
  'Durée de la relation + 5 ans (DDA)',
  '5 ans archivage intermédiaire (DDA art. L521-1)',
  'Chiffrement AES-256 au repos, TLS 1.3 en transit, accès restreint',
  TRUE, TRUE
),
(
  'Gestion des leads et mise en relation avec assureurs',
  'Transmettre les leads qualifiés aux partenaires assureurs partenaires',
  'consentement',
  'Email, téléphone, type de contrat, économie estimée',
  'Prospects ayant consenti à être recontactés',
  'Partenaires assureurs (April, Néoliane, etc.)',
  '3 ans depuis dernier contact si non converti',
  '5 ans après souscription (DDA)',
  'Transmission sécurisée API, minimisation des données',
  FALSE, FALSE
),
(
  'Prospection commerciale par email',
  'Envoyer des emails de suivi et d''offres aux prospects',
  'consentement',
  'Email, prénom, type de contrat',
  'Prospects ayant consenti aux emails marketing',
  'Prestataire emailing (Brevo)',
  '3 ans sans ouverture ou clic',
  'N/A',
  'Liste de désabonnement, lien de désinscription systématique',
  FALSE, FALSE
),
(
  'Comptabilité et facturation',
  'Établir les factures de commission et tenir la comptabilité',
  'obligation_legale',
  'Données de facturation, montants, références',
  'Partenaires assureurs',
  'Expert-comptable',
  '10 ans (Code de commerce art. L123-22)',
  '10 ans archivage définitif',
  'Accès restreint comptable, sauvegarde chiffrée',
  FALSE, FALSE
);


-- ============================================================
-- 3. CONTRATS UPLOADÉS
-- ATTENTION : peut contenir des DONNÉES DE SANTÉ (art. 9 RGPD)
-- → Chiffrement obligatoire du PDF en stockage
-- → Consentement explicite requis AVANT l'analyse
-- Durée conservation :
--   - Base active : durée de la relation
--   - Archivage DDA : 5 ans après fin de la relation
--   - Suppression PDF : dès que l'analyse est faite (minimisation)
-- ============================================================
CREATE TABLE contrats (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  client_id         UUID REFERENCES clients(id) ON DELETE CASCADE,

  -- ── FICHIER ──
  nom_fichier_original  VARCHAR(255) NOT NULL,
  nom_fichier_stocke    VARCHAR(255),   -- Nom pseudonymisé (pas le nom original)
  taille_octets         INTEGER,
  -- URL chiffrée côté applicatif (jamais en clair dans la DB)
  stockage_url_chiffree TEXT,
  -- Clé de déchiffrement (optionnel, si chiffrement par client)
  cle_chiffrement_ref   VARCHAR(100),
  hash_fichier          VARCHAR(64),    -- SHA-256 pour intégrité
  -- Le PDF original DOIT être supprimé après analyse (minimisation RGPD)
  pdf_supprime          BOOLEAN DEFAULT FALSE,
  pdf_supprime_le       TIMESTAMPTZ,

  -- ── TYPE ──
  type_contrat      VARCHAR(30) NOT NULL
                    CHECK (type_contrat IN (
                      'mutuelle','auto','habitation','emprunteur',
                      'electricite','gaz','prevoyance','vie'
                    )),
  -- Flag données sensibles (mutuelle, emprunteur = données de santé potentielles)
  contient_donnees_sante BOOLEAN DEFAULT FALSE,

  -- ── DONNÉES EXTRAITES PAR L'IA ──
  assureur_actuel          VARCHAR(150),
  cotisation_mensuelle     DECIMAL(10,2),
  cotisation_annuelle      DECIMAL(10,2),
  date_echeance            DATE,
  numero_contrat           VARCHAR(100),
  -- JSONB chiffré si données de santé présentes
  garanties                JSONB,
  -- Texte brut de l'analyse (ne pas stocker les données de santé ici)
  analyse_brute            TEXT,
  score_qualite            INTEGER CHECK (score_qualite BETWEEN 0 AND 100),
  points_faibles           JSONB,
  economie_estimee_mensuelle DECIMAL(10,2),
  economie_estimee_annuelle  DECIMAL(10,2),

  -- ── STATUT ──
  statut            VARCHAR(20) DEFAULT 'en_attente'
                    CHECK (statut IN ('en_attente','analyse','complete','erreur','supprime')),
  erreur_message    TEXT,

  -- ── DURÉES CONSERVATION CNIL / DDA ──
  -- Art. 521-1 Code assurances + DDA : 5 ans après fin relation
  a_archiver_le     DATE,
  a_supprimer_le    DATE,  -- Renseigné à l'insert
  -- Minimisation : flag pour purge des données sensibles après traitement
  donnees_purgees   BOOLEAN DEFAULT FALSE,
  donnees_purgees_le TIMESTAMPTZ,

  -- ── TIMESTAMPS ──
  cree_le           TIMESTAMPTZ DEFAULT NOW(),
  analyse_le        TIMESTAMPTZ
);

CREATE INDEX idx_contrats_client        ON contrats(client_id);
CREATE INDEX idx_contrats_type          ON contrats(type_contrat);
CREATE INDEX idx_contrats_statut        ON contrats(statut);
CREATE INDEX idx_contrats_sante         ON contrats(contient_donnees_sante);
CREATE INDEX idx_contrats_supprimer     ON contrats(a_supprimer_le);


-- ============================================================
-- 4. PARTENAIRES / ASSUREURS
-- Convention DDA obligatoire avant toute transmission de leads
-- ============================================================
CREATE TABLE partenaires (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  nom             VARCHAR(150) NOT NULL,
  slug            VARCHAR(100) NOT NULL UNIQUE,
  logo_url        TEXT,
  site_web        VARCHAR(255),
  -- ORIAS du partenaire (vérification obligation DDA)
  numero_orias    VARCHAR(20),
  orias_verifie   BOOLEAN DEFAULT FALSE,
  orias_verifie_le DATE,
  -- Contact commercial
  contact_nom     VARCHAR(150),
  contact_email   VARCHAR(255),
  contact_tel     VARCHAR(20),
  -- Convention DDA (obligatoire avant transmission leads)
  numero_convention     VARCHAR(100),
  date_signature        DATE,
  date_expiration       DATE,
  convention_url        TEXT,   -- PDF signé stocké
  -- Taux de commission par type de contrat
  commission_mutuelle     DECIMAL(5,2),
  commission_auto         DECIMAL(5,2),
  commission_habitation   DECIMAL(5,2),
  commission_emprunteur   DECIMAL(5,2),
  commission_electricite  DECIMAL(5,2),
  commission_gaz          DECIMAL(5,2),
  -- API
  api_url               TEXT,
  api_key_chiffree      TEXT,  -- CHIFFRÉ, jamais en clair
  api_actif             BOOLEAN DEFAULT FALSE,
  -- Statut
  statut          VARCHAR(20) DEFAULT 'prospect'
                  CHECK (statut IN ('prospect','en_negociation','actif','suspendu','termine')),
  -- Timestamps
  cree_le         TIMESTAMPTZ DEFAULT NOW(),
  mis_a_jour_le   TIMESTAMPTZ DEFAULT NOW()
);


-- ============================================================
-- 5. OFFRES PARTENAIRES
-- ============================================================
CREATE TABLE offres (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  partenaire_id   UUID REFERENCES partenaires(id) ON DELETE CASCADE,
  nom             VARCHAR(200) NOT NULL,
  type_contrat    VARCHAR(30) NOT NULL
                  CHECK (type_contrat IN (
                    'mutuelle','auto','habitation','emprunteur',
                    'electricite','gaz','prevoyance','vie'
                  )),
  description     TEXT,
  garanties       JSONB,
  tarif_min       DECIMAL(10,2),
  tarif_max       DECIMAL(10,2),
  unite_tarif     VARCHAR(10) DEFAULT 'mois',
  age_min         INTEGER,
  age_max         INTEGER,
  zones_geo       JSONB,
  url_souscription TEXT,
  actif           BOOLEAN DEFAULT TRUE,
  cree_le         TIMESTAMPTZ DEFAULT NOW(),
  mis_a_jour_le   TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_offres_partenaire   ON offres(partenaire_id);
CREATE INDEX idx_offres_type         ON offres(type_contrat);
CREATE INDEX idx_offres_actif        ON offres(actif);


-- ============================================================
-- 6. RECOMMANDATIONS IA
-- La DDA impose de tracer les conseils donnés (5 ans)
-- ============================================================
CREATE TABLE recommandations (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  contrat_id        UUID REFERENCES contrats(id) ON DELETE CASCADE,
  offre_id          UUID REFERENCES offres(id) ON DELETE SET NULL,
  rang              INTEGER DEFAULT 1,
  economie_mensuelle  DECIMAL(10,2),
  economie_annuelle   DECIMAL(10,2),
  -- DDA : justification du conseil obligatoire
  raison_conseil    TEXT NOT NULL,  -- Explication IA du choix
  criteres_utilises JSONB,          -- {"garanties_manquantes":[], "prix":...}
  score_pertinence  INTEGER CHECK (score_pertinence BETWEEN 0 AND 100),
  -- Interaction
  vue               BOOLEAN DEFAULT FALSE,
  vue_le            TIMESTAMPTZ,
  clic              BOOLEAN DEFAULT FALSE,
  clic_le           TIMESTAMPTZ,
  -- Timestamps (conservation 5 ans DDA)
  cree_le           TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_reco_contrat ON recommandations(contrat_id);


-- ============================================================
-- 7. LEADS
-- Transmission uniquement si consentement consent_partage_partenaires = TRUE
-- ============================================================
CREATE TABLE leads (
  id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  client_id           UUID REFERENCES clients(id) ON DELETE SET NULL,
  contrat_id          UUID REFERENCES contrats(id) ON DELETE SET NULL,
  recommandation_id   UUID REFERENCES recommandations(id) ON DELETE SET NULL,
  partenaire_id       UUID REFERENCES partenaires(id) ON DELETE SET NULL,
  -- Vérification consentement AVANT transmission (DDA + RGPD)
  consent_verifie     BOOLEAN DEFAULT FALSE, -- Système vérifie consent_partage_partenaires
  consent_verifie_le  TIMESTAMPTZ,
  -- Type de lead
  type_lead           VARCHAR(30) DEFAULT 'rappel'
                      CHECK (type_lead IN ('rappel','devis','souscription')),
  message             TEXT,
  -- Transmission
  transmis            BOOLEAN DEFAULT FALSE,
  transmis_le         TIMESTAMPTZ,
  ref_partenaire      VARCHAR(100),
  -- Commission
  commission_due      DECIMAL(10,2),
  commission_payee    BOOLEAN DEFAULT FALSE,
  commission_payee_le TIMESTAMPTZ,
  -- Statut
  statut              VARCHAR(20) DEFAULT 'nouveau'
                      CHECK (statut IN (
                        'nouveau','contact','devis_envoye',
                        'souscrit','perdu','rembourse'
                      )),
  notes               TEXT,
  -- Timestamps (5 ans DDA)
  cree_le             TIMESTAMPTZ DEFAULT NOW(),
  mis_a_jour_le       TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_leads_client     ON leads(client_id);
CREATE INDEX idx_leads_partenaire ON leads(partenaire_id);
CREATE INDEX idx_leads_statut     ON leads(statut);


-- ============================================================
-- 8. SIGNATURES ÉLECTRONIQUES (eIDAS / Yousign)
-- Valeur légale en France — Règlement eIDAS 910/2014/UE
-- Conservation : durée de vie du contrat + 5 ans (preuve)
-- ============================================================
CREATE TABLE signatures (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  lead_id         UUID REFERENCES leads(id) ON DELETE CASCADE,
  client_id       UUID REFERENCES clients(id) ON DELETE SET NULL,
  -- Prestataire qualifié eIDAS
  prestataire     VARCHAR(50) DEFAULT 'yousign'
                  CHECK (prestataire IN ('yousign','docusign','adobe_sign','universign')),
  id_externe      VARCHAR(255),
  -- Document
  document_url    TEXT,
  document_hash   VARCHAR(64),
  -- Statut
  statut          VARCHAR(20) DEFAULT 'en_attente'
                  CHECK (statut IN ('en_attente','envoye','signe','refuse','expire')),
  -- Horodatage légal eIDAS
  envoye_le       TIMESTAMPTZ,
  signe_le        TIMESTAMPTZ,
  expire_le       TIMESTAMPTZ,
  -- Preuve d'audit (eIDAS niveau avancé minimum)
  certificat_url  TEXT,
  ip_signataire   INET,
  user_agent_signataire TEXT,
  -- Conservation : durée du contrat + 5 ans
  a_supprimer_le  DATE,
  cree_le         TIMESTAMPTZ DEFAULT NOW()
);


-- ============================================================
-- 9. EMAILS (Brevo)
-- Désabonnement OBLIGATOIRE dans chaque email (art. L34-5 CPCE)
-- Conservation : 1 an pour prouver le consentement
-- ============================================================
CREATE TABLE emails (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  client_id       UUID REFERENCES clients(id) ON DELETE CASCADE,
  type_email      VARCHAR(50),
  sujet           VARCHAR(255),
  statut          VARCHAR(20) DEFAULT 'envoye'
                  CHECK (statut IN ('envoye','delivre','ouvert','clique','bounce','desabonne','spam')),
  id_brevo        VARCHAR(100),
  ouvert_le       TIMESTAMPTZ,
  clique_le       TIMESTAMPTZ,
  -- Désabonnement tracé
  desabonne_le    TIMESTAMPTZ,
  raison_desabo   VARCHAR(100),
  cree_le         TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_emails_client ON emails(client_id);
CREATE INDEX idx_emails_statut ON emails(statut);


-- ============================================================
-- 10. JOURNAL DES ACCÈS AUX DONNÉES (art. 32 RGPD — sécurité)
-- Traçabilité de qui accède aux données sensibles
-- Conservation : 6 mois minimum (CNIL recommandation logs)
-- ============================================================
CREATE TABLE journal_acces (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  -- Qui
  utilisateur_id  UUID,          -- Admin ou système
  type_acteur     VARCHAR(20)    -- 'admin','api','systeme','client'
                  CHECK (type_acteur IN ('admin','api','systeme','client')),
  ip_source       INET,
  -- Quoi
  table_cible     VARCHAR(100),  -- 'contrats', 'clients', etc.
  enregistrement_id UUID,
  action          VARCHAR(20)    -- 'lecture','creation','modification','suppression'
                  CHECK (action IN ('lecture','creation','modification','suppression','export')),
  donnees_sensibles BOOLEAN DEFAULT FALSE,
  -- Contexte
  raison          TEXT,          -- Justification de l'accès
  -- Timestamp
  cree_le         TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_journal_cible   ON journal_acces(table_cible);
CREATE INDEX idx_journal_cree_le ON journal_acces(cree_le);


-- ============================================================
-- 11. CONVERSATIONS CHATBOT
-- ============================================================
CREATE TABLE conversations (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  client_id       UUID REFERENCES clients(id) ON DELETE SET NULL,
  session_id      VARCHAR(100),
  messages        JSONB DEFAULT '[]',
  nb_messages     INTEGER DEFAULT 0,
  cree_le         TIMESTAMPTZ DEFAULT NOW(),
  mis_a_jour_le   TIMESTAMPTZ DEFAULT NOW()
);


-- ============================================================
-- 12. ANALYTIQUES / ÉVÉNEMENTS
-- Pseudonymisation des IPs (CNIL : IP = donnée personnelle)
-- ============================================================
CREATE TABLE evenements (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  client_id       UUID REFERENCES clients(id) ON DELETE SET NULL,
  session_id      VARCHAR(100),
  nom             VARCHAR(100) NOT NULL,
  proprietes      JSONB,
  page_url        TEXT,
  source          VARCHAR(50),
  medium          VARCHAR(50),
  campaign        VARCHAR(100),
  -- CNIL : tronquer la dernière partie de l'IP (pseudonymisation)
  -- Ex: 192.168.1.XXX au lieu de 192.168.1.123
  ip_tronquee     VARCHAR(50),
  cree_le         TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_evt_nom     ON evenements(nom);
CREATE INDEX idx_evt_cree_le ON evenements(cree_le);


-- ============================================================
-- 13. COMMISSIONS
-- Conservation 10 ans (Code de commerce art. L123-22)
-- ============================================================
CREATE TABLE commissions (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  lead_id         UUID REFERENCES leads(id) ON DELETE SET NULL,
  partenaire_id   UUID REFERENCES partenaires(id) ON DELETE SET NULL,
  montant_ht      DECIMAL(10,2) NOT NULL,
  tva             DECIMAL(10,2) DEFAULT 0,
  montant_ttc     DECIMAL(10,2) NOT NULL,
  numero_facture  VARCHAR(50),
  date_facture    DATE,
  statut          VARCHAR(20) DEFAULT 'en_attente'
                  CHECK (statut IN ('en_attente','facture','regle','litige')),
  date_reglement  DATE,
  mode_paiement   VARCHAR(30),
  reference_virement VARCHAR(100),
  -- Conservation 10 ans légale
  a_supprimer_le  DATE,
  cree_le         TIMESTAMPTZ DEFAULT NOW()
);


-- ============================================================
-- TRIGGERS
-- ============================================================
CREATE OR REPLACE FUNCTION update_mis_a_jour()
RETURNS TRIGGER AS $$
BEGIN NEW.mis_a_jour_le = NOW(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_clients_maj     BEFORE UPDATE ON clients     FOR EACH ROW EXECUTE FUNCTION update_mis_a_jour();
CREATE TRIGGER trg_partenaires_maj BEFORE UPDATE ON partenaires FOR EACH ROW EXECUTE FUNCTION update_mis_a_jour();
CREATE TRIGGER trg_offres_maj      BEFORE UPDATE ON offres      FOR EACH ROW EXECUTE FUNCTION update_mis_a_jour();
CREATE TRIGGER trg_leads_maj       BEFORE UPDATE ON leads       FOR EACH ROW EXECUTE FUNCTION update_mis_a_jour();
CREATE TRIGGER trg_conv_maj        BEFORE UPDATE ON conversations FOR EACH ROW EXECUTE FUNCTION update_mis_a_jour();

-- Trigger : bloquer la transmission d'un lead sans consentement
CREATE OR REPLACE FUNCTION verifier_consent_lead()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.transmis = TRUE THEN
    IF NOT EXISTS (
      SELECT 1 FROM clients
      WHERE id = NEW.client_id
        AND consent_partage_partenaires = TRUE
        AND consent_contact = TRUE
    ) THEN
      RAISE EXCEPTION 'RGPD: Impossible de transmettre ce lead — consentement manquant (consent_partage_partenaires ou consent_contact)';
    END IF;
    NEW.consent_verifie = TRUE;
    NEW.consent_verifie_le = NOW();
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_consent_lead
  BEFORE UPDATE OF transmis ON leads
  FOR EACH ROW EXECUTE FUNCTION verifier_consent_lead();


-- ============================================================
-- VUES
-- ============================================================

-- Dashboard admin
CREATE VIEW v_dashboard AS
SELECT
  (SELECT COUNT(*) FROM clients WHERE statut != 'supprime')                    AS total_clients,
  (SELECT COUNT(*) FROM clients WHERE cree_le > NOW() - INTERVAL '30 days')   AS nouveaux_30j,
  (SELECT COUNT(*) FROM contrats WHERE statut = 'complete')                    AS analyses_total,
  (SELECT COUNT(*) FROM leads WHERE statut = 'souscrit')                       AS souscriptions,
  (SELECT COALESCE(SUM(montant_ttc),0) FROM commissions WHERE statut = 'regle') AS ca_total,
  (SELECT COALESCE(AVG(economie_estimee_mensuelle),0) FROM contrats WHERE statut = 'complete') AS economie_moy;

-- Vue conformité RGPD : données à supprimer
CREATE VIEW v_rgpd_a_supprimer AS
SELECT 'client' AS type, id, email AS ref, supprimer_si_inactif_le AS date_suppression
FROM clients
WHERE statut = 'prospect' AND supprimer_si_inactif_le <= CURRENT_DATE AND anonymise = FALSE
UNION ALL
SELECT 'contrat' AS type, id, nom_fichier_original AS ref, a_supprimer_le
FROM contrats
WHERE a_supprimer_le IS NOT NULL AND a_supprimer_le <= CURRENT_DATE AND donnees_purgees = FALSE;

-- Vue leads pour dashboard commercial
CREATE VIEW v_leads_detail AS
SELECT
  l.id, l.cree_le, l.statut, l.type_lead, l.commission_due,
  c.email, c.prenom, c.nom, c.telephone,
  ct.type_contrat, ct.cotisation_mensuelle, ct.economie_estimee_mensuelle,
  p.nom AS partenaire
FROM leads l
LEFT JOIN clients c    ON c.id = l.client_id
LEFT JOIN contrats ct  ON ct.id = l.contrat_id
LEFT JOIN partenaires p ON p.id = l.partenaire_id;


-- ============================================================
-- DONNÉES INITIALES
-- ============================================================
INSERT INTO partenaires (nom, slug, statut) VALUES
  ('April Partenaires', 'april',   'prospect'),
  ('Néoliane',          'neoliane','prospect'),
  ('Santiane',          'santiane','prospect'),
  ('Luko',              'luko',    'prospect'),
  ('Direct Assurance',  'direct',  'prospect');


-- ============================================================
-- CHECKLIST CONFORMITÉ CNIL — À FAIRE EN DEHORS DE LA DB
-- ============================================================
-- ✅ 1. Nommer un DPO (si traitement à grande échelle données santé)
-- ✅ 2. Rédiger et publier la Politique de Confidentialité sur le site
-- ✅ 3. Ajouter les mentions légales obligatoires (art. 13 RGPD) à chaque collecte
-- ✅ 4. Banière cookies conforme (ePrivacy + CNIL délibération 2020-091)
-- ✅ 5. Chiffrer les PDF stockés (AES-256 minimum)
-- ✅ 6. Héberger en Europe (Vercel EU / Supabase EU / AWS eu-west-3 Paris)
-- ✅ 7. Mettre en place une procédure de réponse aux droits (48h max recommandé)
-- ✅ 8. Souscrire Yousign pour signatures eIDAS niveau avancé
-- ✅ 9. Purger les PDF après analyse (minimisation art. 5 RGPD)
-- ✅ 10. Tâche cron mensuelle pour supprimer les données expirées (v_rgpd_a_supprimer)
-- ✅ 11. Convention DDA signée avec chaque partenaire AVANT toute transmission lead
-- ✅ 12. Conserver les conseils IA 5 ans (table recommandations — DDA art. L521-1)

-- ============================================================
-- FIN DU SCHÉMA CONFORME CNIL / RGPD / DDA
-- ============================================================
