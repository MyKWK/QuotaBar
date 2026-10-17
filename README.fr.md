<div align="center">

# QuotaBar

### Vos quotas IA, en un coup d’œil.

Codex / GPT · Kimi · Cursor · DeepSeek<br>
Les quotas et soldes de vos services IA, réunis dans la barre des menus du Mac.

[简体中文](README.md) · [繁體中文](README.zh-TW.md) · [English](README.en.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Español](README.es.md) · **Français** · [Deutsch](README.de.md) · [Português (Brasil)](README.pt-BR.md)

<img src="docs/images/quotabar-menubar.png" alt="Capture réelle de QuotaBar : barre des menus originale et reste du bureau flouté" width="530">

**Moins de pages de consommation. Plus de concentration.**

</div>

Vous codez, changez de modèle ou lancez une tâche : vous voulez simplement savoir ce qu’il vous reste. QuotaBar affiche des icônes et des chiffres compacts dans la barre des menus, pour consulter vos quotas sans interrompre votre travail.

![Capture réelle de QuotaBar : barre des menus originale et reste du bureau flouté](docs/images/quotabar-desktop-privacy.png)

<sub>Capture en conditions réelles. La barre supérieure conserve les pixels d’origine ; le reste est anonymisé par un flou doux, sans mosaïque. Les valeurs correspondent à l’instant de la capture ; `--` indique l’absence de données disponibles.</sub>

## Vos quotas restent à portée de regard

- **Plusieurs services à la fois :** affichez ou masquez séparément Codex / GPT, Kimi, Cursor et DeepSeek.
- **Des chiffres explicites :** Codex affiche le plus faible pourcentage restant parmi les fenêtres disponibles ; Cursor permet de choisir Cursor Models ou Other Models ; DeepSeek indique le solde disponible réel.
- **Une interface en verre native :** panneaux et réglages reposent sur AppKit, SwiftUI et les matériaux de macOS 27.
- **Un historique local :** relevés horaires dans SQLite, synthèses par jour, semaine, mois, trimestre et année, graphiques en anneau et cartes de chaleur.
- **Une application Swift extensible :** compilation avec Swift Package Manager, sans dépendance tierce à l’exécution.

## Services pris en charge et portée des chiffres

Codex / GPT utilise les données du compte Codex connecté sur le Mac, pas le quota général de messages ChatGPT. Kimi utilise un endpoint d’abonnement sans documentation publique, susceptible de changer. Cursor s’appuie sur la session locale ; DeepSeek utilise une clé API officielle. ZCode n’est pas encore implémenté. Le panneau de comptes Claude Code est conservé, mais Claude Code n’est pas un élément distinct de la nouvelle barre multiservice.

L’historique représente les variations en points de pourcentage entre relevés, et non des tokens, des montants facturés ou des heures de travail. Les soldes DeepSeek ne sont pas encore inclus dans les graphiques de consommation agrégée.

## Premiers pas

**macOS 27+ et Xcode 27.x / Swift 6.4** sont nécessaires. Le code source est actuellement disponible ; aucun installateur de cette édition n’a encore été publié sur GitHub. Au lancement, ouvrez les réglages depuis la barre des menus, choisissez les services et configurez vos propres comptes.

```bash
git clone https://github.com/MyKWK/QuotaBar.git
cd QuotaBar
swift build
swift run QuotaBar
```

## Confidentialité et identifiants

Aucun compte ni aucune clé utilisable n’est fourni. Les tokens Kimi et les clés DeepSeek enregistrées directement sont stockés dans `~/Library/Application Support/QuotaBar/credentials.json`, avec les permissions `0600` pour le fichier et `0700` pour le dossier. Il s’agit de texte en clair protégé par les permissions. Les identifiants de la gestion multicomptes héritée utilisent le Trousseau macOS. Les requêtes transmettent les identifiants nécessaires au service concerné.

[Développement](CONTRIBUTING.md) · [Sécurité](SECURITY.md) · [Provenance](docs/ORIGINS.md) · [Licence complète](LICENSE)

## Travail original et provenance du code

Le projet est né d’un outil local de quota Kimi de MyKWK, déjà utilisé en août 2026. Le 16 septembre, le développement multiservice a intégré du code d’un autre projet du même nom, QuotaBar, maintenu par Chiloh / chilohwei. Cette édition associe notre travail sur Kimi, la conception du produit et les extensions ultérieures à cette base de code. Elle est maintenue par MyKWK.

[Chiloh / chilohwei — QuotaBar](https://github.com/chilohwei/QuotaBar)

Le code externe utilisé conserve son attribution et sa licence personnalisée intégrale. Les usages personnels, éducatifs, de recherche et autres usages non commerciaux relèvent de la licence d’origine ; un usage commercial exige l’autorisation écrite préalable de l’auteur d’origine. Cette édition ne bénéficie d’aucun soutien officiel du projet d’origine ni des fournisseurs IA.

---

Si QuotaBar vous évite quelques allers-retours vers les pages de consommation, ajoutez une Star ou partagez votre expérience.
