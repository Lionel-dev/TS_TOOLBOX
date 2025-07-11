# 🧰 Boîte à outils Support IT

## 🎯 Objectif

Cette boîte à outils regroupe des scripts et utilitaires PowerShell conçus pour :
- Diagnostiquer rapidement des problèmes sur serveurs et postes.
- Réaliser des audits ou des correctifs sans dépendances externes.
- Gagner du temps et sécuriser les interventions.
- Être facilement transportable, exécutable localement, et utilisable sans connexion Internet.

Elle est pensée pour être utilisée par les équipes support, infogérance ou projet, directement depuis un partage réseau ou un dépôt GitHub.

---
## 📦 Arborescence du dépôt

```text
.
├── Config/                 # Fichiers de configuration
│   ├── config_interface.yaml
│   └── config_menu.yaml
├── Logs/                   # Sorties et journaux d’exécution
├── Options/                # Modules et scripts optionnels
│   ├── Clear-DiskSpace.ps1  # Nettoyage de l’espace disque
│   └── Compress-Images.ps1  # Compression d’images
├── main.ps1                # Script principal d’exécution
└── README.md               # Documentation du dépôt

---

## 📦 Contenu actuel

### 🔍 Audit & Diagnostics
- **`Compress-Images.ps1`**
  - Compresse les fichiers JPG et PNG d'un dossier en ajustant la qualité.
  - Permet de filtrer les images selon une date limite optionnelle.

### 🛠️ Actions
*(à compléter avec tes autres outils, par exemple)*
- Vérification des symlinks Outlook.
- Export des utilisateurs et groupes locaux/AD.
 - Nettoyage d’espace disque.
- Contrôle des comptes RDP autorisés.

---

## 🚀 Utilisation

1️⃣ Cloner le dépôt ou accéder au dossier partagé.  
2️⃣ Exécuter les scripts souhaités depuis une console PowerShell :

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\nom_du_script.ps1 -paramètres
```

Tous les scripts fonctionnent en local et affichent un bilan clair à la fin.

# 📝 Conventions
Tous les scripts demandent des paramètres explicites (-InputFolder, etc.).

Aucun ne modifie sans votre confirmation (sauf ceux explicitement prévus).

Une version « démo » est incluse pour certains scripts afin de rassurer les clients sans toucher aux données en production.

# 🔧 Prérequis
Windows Server ou Windows 10/11

PowerShell ≥ 5.1

Droits administrateur recommandés pour certains scripts

Pas besoin d’installation d’outils tiers

# 👥 Destinataires
## 👨‍💻 Équipe support / infogérance
## 📦 Livré pour une utilisation interne et démonstrations clients.

# 📄 Licence
MIT Licence — vous pouvez utiliser, modifier et améliorer les scripts.
Pensez à valider en interne avant de distribuer à des tiers.


