# BATOSINE - SOC Live Monitor

**BATOSINE** est un outil de surveillance de processus en temps réel (SOC Dashboard) conçu pour Linux. Il permet de visualiser graphiquement la consommation des ressources et d'intervenir instantanément sur les processus critiques.

## 🚀 Fonctionnalités

- **Monitoring en temps réel** : Mise à jour automatique toutes les 4 secondes.
- **Code couleur dynamique** : 
  - 🟢 **OK** : Consommation normale.
  - 🟠 **ALERTE** : Consommation modérée (>40%).
  - 🔴 **DANGER** : Consommation critique (>80%).
- **Actions rapides** : Boutons intégrés pour **Stopper** (PAUSE), **Relancer** (RESUME) ou **Tuer** (KILL) un processus.
- **Filtre intelligent** : Masque automatiquement les processus système (Kernel) et les outils de monitoring pour ne montrer que les applications utilisateur.
- **Interface stylisée** : Utilisation de balises Pango pour un rendu visuel clair et professionnel.

## 🛠️ Prérequis

L'outil nécessite l'installation de `yad` pour l'interface graphique :

```bash
sudo apt update
sudo apt install yad
