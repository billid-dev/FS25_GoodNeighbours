<p align="center">
  <img src="docs/logo.png" width="200" alt="Good Neighbours logo">
</p>

<h1 align="center">Good Neighbours – Dobrzy Sąsiedzi</h1>

<p align="center">
  A roleplay mod for <b>Farming Simulator 25</b>: seven neighbours with day plans, conversations, a phone,
  contracts and their own machines – in single player and on dedicated servers.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Farming%20Simulator-25-4c9a2a" alt="Farming Simulator 25">
  <img src="https://img.shields.io/badge/multiplayer-supported-2b7bb9" alt="multiplayer supported">
  <a href="https://github.com/billid-dev/FS25_GoodNeighbours/releases/latest"><img src="https://img.shields.io/badge/version-1.0.0.0-e08a1e" alt="version 1.0.0.0"></a>
  <img src="https://img.shields.io/badge/status-stable-2e8b57" alt="stable">
  <a href="https://discord.gg/gxwC8vUUch"><img src="https://img.shields.io/badge/discord-join-5865F2?logo=discord&logoColor=white" alt="discord join"></a>
</p>

<p align="center">
  <b><a href="#-polski">Polski</a></b> · <b><a href="#-english">English</a></b> · <a href="CHANGELOG.md">Changelog</a>
</p>

<p align="center">
  <img src="docs/neighbours.png" alt="The seven neighbours">
</p>

---

## 🇵🇱 Polski

**Dobrzy Sąsiedzi** ożywiają wieś za miedzą. Na twojej mapie mieszka siedmioro sąsiadów – czterech rolników, którzy uprawiają pola NPC, burmistrz, handlarka zbożem i dealer maszyn. Każdy ma swój dom, plan dnia, samochód, maszyny i własny charakter.

### Najważniejsze funkcje

**Rozmowy**
- Podejdź do sąsiada i naciśnij **Shift+N** – „Rozpocznij rozmowę”.
- Ponad **280 rozmów** (wiele z 3–5 odpowiedziami) po polsku, angielsku i niemiecku, z wyborem odpowiedzi, zależnych od miejsca, zajęcia, pory roku i poziomu znajomości.
- Każda odpowiedź się liczy: wynik rozmowy to od -80 do +80 pkt relacji (raz dziennie u każdego sąsiada) – warto czytać, co się wybiera.

**Telefon (Shift+N)**
- Wiadomości, kontakty z planem dnia, telefony z prawdziwymi kontraktami na polach sąsiadów.
- Liczba telefonów dziennie w ustawieniach (zmiana działa od razu).
- Nieodebrany telefon → druga próba po ok. 30 min → SMS „Widzę, że jesteś zajęty, zajmę się tym sam”.
- Tryb samolotowy dla całej farmy, oznaczanie wiadomości jako przeczytane, gdy jeden gracz odbierze – u pozostałych przestaje dzwonić.

**Kontrakty sąsiadów**
- Zapłata za hektar według cennika sąsiadów (rodzaj pracy, uprawa, poziom trudności) + premia za relację.
- Relacja z burmistrzem daje tańszą ziemię (do 10%), z Frankiem tańsze naprawy (do 20%), z Moniką lepsze ceny za plony (do 5%); na początku znajomości mała kara.
- Wykonujesz własnymi maszynami albo **maszyną sąsiada** – odbiór, pola i zwrot zaznaczone na mapie; kontrakt zalicza się po odstawieniu maszyny na miejsce.
- Nasiona, nawóz, herbicyd i wapno czekają przy silosie sąsiada; jego bramy otwierasz w czasie kontraktu.

**Sąsiedzi pracują sami**
- Własne ciągniki, maszyny i kombajny (stałe floty, jak u prawdziwych rolników), praca pomocnikiem SI z gry tylko na swoich polach, do 22:00.
- Maszyny pełne podczas pracy, składane po pracy i odstawiane na swoje miejsca.
- Każde wolne pole NPC należy do któregoś rolnika; pole kupione przez gracza od niego odchodzi.

**Świat**
- Plany dnia: praca, sklep, stacja, warsztat, skup, kościół, spacer, odpoczynek, odwiedziny na twoim podwórku.
- Stroje sąsiadów, portrety, ikony na mapie, kierowca w ciągniku wygląda jak sąsiad.
- Silos na podwórku każdego rolnika.

**Konfiguracja mapy**
- Sam ustawia się na każdej mapie (domy, miejsca maszyn, silosy, miejsca odwiedzin); presety dla trzech map podstawowych.
- Własna kategoria w menu budowania: rozmiary miejsc (**Shift+Q**), usuwanie wszystkich danego rodzaju (**Shift+Del**), natychmiastowe rozstawienie maszyn na postawionych miejscach (**Shift+G**, admin), edytor maszyn każdego sąsiada ze sklepu (**Shift+M**, admin), podgląd maszyny przy stawianiu miejsca, panel „jest / potrzeba”, znacznik **„Moja farma”**.
- Ustawienia admina w **ESC → Ustawienia → Dobrzy Sąsiedzi**.

### Instalacja
1. Pobierz `FS25_GoodNeighbours.zip` z [Releases](../../releases).
2. Wrzuć plik zip (nie rozpakowuj) do folderu modów:
   - PC: `Dokumenty/My Games/FarmingSimulator2025/mods`
   - Serwer dedykowany: panel serwera → Mods → upload.
3. Włącz moda przy tworzeniu/wczytywaniu gry.

### Zgłaszanie błędów
Otwórz [Issue](../../issues) i dołącz fragment `log.txt` (linie z `[GoodNeighbours]`) oraz opis/zrzut ekranu.

---

## 🇬🇧 English

**Good Neighbours** brings the village next door to life. Seven neighbours live on your map – four farmers who work the NPC fields, the mayor, the grain trader and the machinery dealer – each with a home, a day plan, a car, machines and a character of their own.

### Features
- **Conversations** (Shift+N near a neighbour): 280+ conversations in EN/DE/PL, many with 3–5 answers; every answer counts, up to ±80 relationship points per talk (once a day per neighbour).
- **Perks**: the mayor gives cheaper farmland (up to 10%), Frank cheaper repairs (up to 20%), Monika better sell prices (up to 5%); a small penalty while you are strangers.
- **Phone** (Shift+N): messages, contacts with day plans, calls with real contracts on the neighbours' fields, calls per day in the settings, a retry after a missed call, airplane mode, mark messages as read.
- **Contracts**: pay per hectare from the neighbours' price list plus a relationship bonus; use your own machines or borrow the neighbour's (pick-up, fields and return on the map), supplies at his silo, his gates open during the contract.
- **Neighbours work themselves** with their own fixed fleets, only on their own fields, until 22:00; machines are folded and parked on their places after work.
- **Living world**: day plans, visits to your yard, outfits, portraits, map icons, a silo on every farmer's yard.
- **Works on any map**: automatic set-up plus presets for the three base maps; own construction category with place sizes (Shift+Q), remove all (Shift+Del), machines to the set places at once (Shift+G, admin), fleet editor with shop machines for every neighbour (Shift+M, admin), machine preview while placing and a "My farm" place.
- **Made for dedicated servers**: relationships, calls and messages per farm; admin settings in ESC → Settings.

### Installation
Download `FS25_GoodNeighbours.zip` from [Releases](../../releases) and put the zip (not unpacked) into `Documents/My Games/FarmingSimulator2025/mods` or upload it on your server.

### Bugs
Please open an [Issue](../../issues) with the `[GoodNeighbours]` lines of your `log.txt`.

---

## Repository layout

| Folder | Content |
|---|---|
| `scripts/` | Lua scripts (server, client, phone, conversations, work, construction tools …) |
| `data/` | neighbours, fleets, outfits, conversations, map presets |
| `gui/` | phone and conversation dialogs, icons |
| `placeables/` | construction menu tools |
| `images/`, `sounds/`, `l10n/`, `help/` | portraits, wallpapers, sounds, translations, help pages |
| `docs/` | images for this page |

To build the mod: zip the **contents** of the repository (without `docs/`, `README.md`, `CHANGELOG.md`, `LICENSE`, `.git*`) as `FS25_GoodNeighbours.zip`.

## License
© 2026 billiD – all rights reserved. See [LICENSE](LICENSE).
