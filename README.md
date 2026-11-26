# rustdesk-server-tailnet

[Français](#français) · [English](#english)

## Français

Correctif du serveur RustDesk en édition libre ([rustdesk-server](https://github.com/rustdesk/rustdesk-server),
version 1.1.16) : **seuls les appareils de réseaux choisis, par exemple un tailnet Tailscale,
peuvent demander une session**. Les appareils à dépanner, eux, s'enregistrent et répondent d'où
qu'ils soient.

### Pourquoi

Dans l'édition libre, la seule barrière est la clé publique du serveur. Or elle n'a rien de
secret : chaque client la porte, et un client préconfiguré mis en téléchargement la rend lisible
par tous. N'importe qui peut alors :
- demander une session à un appareil enregistré sur le serveur. Un escroc peut ainsi faire lancer
  le client à quelqu'un, au téléphone, puis s'y connecter par le serveur du dépanneur ;
- se servir du relais pour ses propres sessions.

J'utilise ce correctif pour mon propre serveur de dépannage : seul le réseau de l'administrateur
peut lancer une session.

### Ce que fait le correctif

Variable d'environnement `INITIATOR_NETWORKS` : liste de réseaux CIDR séparés par des virgules,
lue par hbbs et par hbbr.

- **hbbs** refuse une demande de connexion (`PunchHoleRequest`) venue d'ailleurs. Le client
  affiche le motif, en français dans le correctif : « Ce serveur n'accepte que les sessions
  demandées depuis le réseau de son administrateur ». La clé reste vérifiée **avant** le réseau :
  une mauvaise clé est toujours refusée par `LICENSE_MISMATCH`.
- **hbbs** refuse de même une demande de relais (`RequestRelay`) venue d'ailleurs, avec un motif
  (`refuse_reason`). En 1.1.16, ce chemin ne vérifie pas la clé.
- **hbbr** refuse de relier deux connexions si **aucune** des deux ne vient de ces réseaux.
- L'adresse jugée est toujours l'**adresse TCP réelle**, jamais celle d'un en-tête `X-Real-IP` ou
  `X-Forwarded-For` (WebSocket).
- Variable absente ou vide : comportement d'origine, sans restriction. Une entrée illisible arrête
  le programme (code 1), pour qu'une faute de frappe ne laisse pas le serveur ouvert sans le dire.
- Au démarrage, chaque programme journalise les réseaux lus : `initiator networks: [...]`.

Environ 100 lignes, dans `src/common.rs`, `src/rendezvous_server.rs` et `src/relay_server.rs`.

### Construire et lancer

```bash
docker build --network host -t rustdesk-server-tailnet:1.1.16 .
```

Le `Dockerfile` reprend la construction de l'image classique officielle : binaires statiques musl,
Rust 1.90, image `FROM scratch`. Les sources sont figées par commit (étiquette 1.1.16 et
sous-module `hbb_common`). `compose.example.yaml` donne un exemple de lancement, en réseau de
l'hôte : le serveur doit voir la vraie adresse des clients.

### Essayé

Sur un serveur en service, le 25/11/2026, avec `INITIATOR_NETWORKS=100.64.0.0/10,fd7a:115c:a1e0::/48`,
en IPv4 et en IPv6 :
- **depuis Internet** :
  - mauvaise clé refusée (`LICENSE_MISMATCH`) ;
  - bonne clé refusée avec le motif, et demande de relais à hbbs refusée ;
  - deux demandes de relais de même identifiant coupées au moment de les relier ;
- **depuis le tailnet** : bonne clé acceptée, et relais relié, des octets passant de l'un à
  l'autre ;
- **en local**, relais avec un bout autorisé et un bout extérieur : relié, dans les deux ordres
  d'arrivée ;
- **avec de vrais clients** (RustDesk 1.5.3 sous Windows 10 et macOS 11, hors du tailnet), le 26/11/2026 :
  - une session demandée depuis le tailnet s'ouvre, par le relais ;
  - une session demandée par ce client est refusée, et il affiche le motif.

### Limites

- **Version.** Basé sur la **1.1.16**, dernière version publiée. Les corrections parues depuis sur
  la branche principale n'y sont pas.
- **Réseau des appareils qui dépannent.** Ils doivent joindre le serveur par un réseau autorisé :
  avec Tailscale, le plus simple est d'utiliser le serveur comme nœud de sortie, ou de viser son
  adresse dans le tailnet.
- **Plage `100.64.0.0/10`.** C'est aussi celle du CGNAT. Tailscale rejette ces adresses quand elles
  arrivent par une autre interface que `tailscale0` (règle `ts-input`).
- **Ports WebSocket.** Les ports 21118 et 21119 font confiance à `X-Real-IP` pour leurs journaux et
  le reste du serveur : ne les ouvrez pas au public sans mandataire.

### Licence

AGPL-3.0, comme rustdesk-server (fichier `LICENSE`). Ce dépôt est la source du correctif, telle
que l'exige l'AGPL pour un serveur modifié offert par le réseau.

## English

A patch for the open-source RustDesk server ([rustdesk-server](https://github.com/rustdesk/rustdesk-server),
release 1.1.16): **only devices in chosen networks, such as a Tailscale tailnet, can request a
session**. Devices to be supported still register and answer from anywhere.

### Why

In the open-source server, the only gate is the server's public key, which is not a secret: every
client carries it, and a preconfigured client offered for download makes it public. Anyone can then:
- request a session to any device registered on the server. A scammer could have someone run the
  client over the phone, then connect through the helper's server;
- use the relay for their own sessions.

### What it does

Environment variable `INITIATOR_NETWORKS`: comma-separated CIDR networks, read by hbbs and hbbr.

- **hbbs** rejects a connection request (`PunchHoleRequest`) from anywhere else. The client
  displays the reason, in French in the patch ("Ce serveur n'accepte que les sessions demandées
  depuis le réseau de son administrateur", i.e. "This server only accepts sessions requested from
  its administrator's network"; constant `REFUS_RESEAU`). The key is still checked **first**: a
  wrong key is still answered with `LICENSE_MISMATCH`.
- **hbbs** likewise rejects a relay request (`RequestRelay`) from elsewhere, with a
  `refuse_reason`. In 1.1.16 this path does not check the key at all.
- **hbbr** refuses to pair two connections when **neither** comes from these networks.
- The address checked is always the **real TCP peer address**, never one taken from an
  `X-Real-IP` or `X-Forwarded-For` header (WebSocket).
- Unset or empty variable: original behaviour, no restriction. An unparsable entry stops the
  program (exit code 1), so that a typo cannot silently leave the server open.
- At startup, each program logs the networks it read: `initiator networks: [...]`.

### Build and run

```bash
docker build --network host -t rustdesk-server-tailnet:1.1.16 .
```

The `Dockerfile` mirrors the official classic image: static musl binaries, Rust 1.90, `FROM scratch`,
sources pinned by commit (tag 1.1.16 and the `hbb_common` submodule). See `compose.example.yaml`
(host network: the server must see each client's real address).

### Tested

On a production server, on 2026-11-25, with `INITIATOR_NETWORKS=100.64.0.0/10,fd7a:115c:a1e0::/48`,
over IPv4 and IPv6:
- **from the Internet**:
  - wrong key rejected (`LICENSE_MISMATCH`);
  - right key rejected with the reason, and relay request to hbbs rejected;
  - two relay requests with the same id cut when paired;
- **from the tailnet**: right key accepted, and relay paired with bytes flowing;
- **locally**, relay with one allowed and one outside end: paired, in both arrival orders;
- **with real clients** (RustDesk 1.5.3 on Windows 10 and macOS 11, outside the tailnet), on 2026-11-26:
  - a session requested from the tailnet opens, through the relay;
  - a session requested by that client is refused, and it displays the reason.

### Limits

- **Version.** Based on release **1.1.16**, the latest one. Fixes merged on the main branch since
  then are not included.
- **Helpers' network.** Devices that start sessions must reach the server from an allowed network.
  With Tailscale, use the server as an exit node or target its tailnet address.
- **`100.64.0.0/10`.** This is also the CGNAT range. Tailscale drops these source addresses on
  interfaces other than `tailscale0` (`ts-input` rule).
- **WebSocket ports.** Ports 21118 and 21119 trust `X-Real-IP` for logging and the rest of the
  server: do not expose them without a proxy.

### License

AGPL-3.0, like rustdesk-server (see `LICENSE`). This repository is the source of the patch, as the
AGPL requires for a modified server offered over a network.
