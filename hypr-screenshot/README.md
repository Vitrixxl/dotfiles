# Capture Hyprland — Rust natif

Sélecteur inspiré de Caelestia, écrit en Rust, avec Wayland layer-shell et
rendu OpenGL ES. Aucun GTK, Qt, Python, Node ou processus permanent.

## Utilisation

- **Super + Shift + S** : sélection sur écran figé, copie seule.
- **Print** : sélection sur écran en mouvement, copiée et enregistrée dans `~/Pictures/screenshots`.
- **Clic** sur une fenêtre : capturer la fenêtre survolée.
- **Glisser** : sélectionner une zone. Relâcher copie automatiquement le PNG.
- **Échap / clic droit** : annuler sans modifier le presse-papiers.
- **Entrée** : copier la sélection courante.
- **Ctrl + Print** : écran entier, enregistré et copié.
- **Alt + Print** : fenêtre active, enregistrée et copiée.

La sélection avec **Super + Shift + S** ne crée pas de fichier permanent.
L'option `--save` ajoute l'enregistrement à la copie. Les captures enregistrées
vont dans `~/Pictures/screenshots`. Les fichiers temporaires sont privés et nettoyés.
Le PNG conserve les pixels natifs, y compris avec l'échelle 125 %.
La bordure des fenêtres et les coins suivent les paramètres Hyprland ; les
couleurs reprennent les valeurs par défaut de Caelestia.

## Rendu et performances

L'image figée est transférée une seule fois au GPU. Un shader dessine le fond,
la teinte et le cadre ; aucune peinture de bitmap au processeur pendant le
déplacement. Les callbacks Wayland synchronisent le rendu à l'écran. Quand le
sélecteur est immobile, il cesse de redessiner. Les requêtes de mise à jour des
fenêtres en mode direct sont exécutées sur un fil séparé.

Mesure sur cet écran 2560 × 1600 à 240 Hz, échelle 125 %, GPU Intel ARL :
ancienne version GTK3 environ 20 images/s ; version Rust environ 233 images/s,
intervalle médian 4,17 ms, p95 4,42 ms sur le test de quatre secondes.
Il s'agit de la cadence de rendu de l'animation mesurée, pas d'une garantie
de 240 images/s pour toute charge système ou tout écran.

## Fichiers et dépendances

- Exécutable : `hypr-screenshot-native` dans ce dossier.
- Sources : `native/src/main.rs`, `native/src/gpu.rs`.
- Versions Rust figées : `native/Cargo.lock`.
- Commandes externes : `grim`, `wl-copy`, `hyprctl`, `gdbus` et `pgrep`.
- Bibliothèques graphiques système : Wayland et EGL, aucune bibliothèque GTK/Qt.
- Les crates Smithay servent aux protocoles Wayland et aux événements d'entrée,
  sans système de widgets.

L'ancienne version GTK et sa bibliothèque privée sont archivées sous
`backups/gtk3/` et ne sont plus chargées par le lanceur.

## Construire et tester

```sh
cd ~/.local/share/hypr-screenshot/native
~/.cargo/bin/cargo build --release --locked
~/.cargo/bin/cargo test --release --locked
install -m755 target/release/hypr-screenshot-native ../hypr-screenshot-native
```

Test d'animation, avec fermeture automatique (prend brièvement le focus) :

```sh
~/.local/bin/hypr-screenshot --benchmark --cancel-after 4
```

Les vérifications incluent l'échelle fractionnaire, le clipping aux bords,
l'ordre des fenêtres, le parcours appui/glisser/relâchement dans les modes figé
et direct, un PNG réel dans le presse-papiers et sa conservation après annulation.

Code du sélecteur sous GPL-3.0-only ; voir `LICENSE`. Les dépendances Rust
conservent leurs licences respectives.
