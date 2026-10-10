# Changelog – Good Neighbours (FS25_GoodNeighbours)

🇵🇱 [Polski](#polski) · 🇬🇧 [English](#english)

---

## Polski

### 1.9.9.7 — 2026-10-10
- Pożyczoną maszynę i materiały znów odbiera się u sąsiada na podwórku (bez przywożenia na miejsce „Moja farma”).

### 1.9.9.6 — 2026-10-10
- Kontrakt przyjęty przez telefon trzeba wykonać w ciągu 10 godzin (czasu gry); po tym czasie przepada.

### 1.9.9.5 — 2026-10-10
- Sąsiad nie przejmuje na czas pracy gruntu, na którym stoją budynki gracza (dom, szopy) – budynek nie zmienia już właściciela razem z gruntem.

### 1.9.9.4 — 2026-10-10
- Gdy masz postawione miejsce „Moja farma”, sąsiad przywozi pożyczoną maszynę i materiały (nasiona, nawóz, herbicyd) na twoje podwórko i tam je potem odbiera – zamknięte bramy nie przeszkadzają.
- Naprawione: kontrakt z telefonu mógł od razu przepaść, gdy sąsiad akurat trzymał ten grunt na czas swojej pracy.

### 1.9.9.3 — 2026-10-10
- Nowa treść SMS-a po nieodebranym telefonie: „Masz pewnie już zaplanowany dzień – w takim razie wezmę się za to sam”.

### 1.9.9.2 — 2026-10-10
- Długie teksty w telefonie można przewijać (kółko myszy, strzałki, pasek z suwakiem).
- Sąsiedzi planują telefony o 8:00 i dzwonią najpóźniej do 12:00; po wykorzystaniu dziennej liczby telefonów kolejne planują następnego dnia o 8:00.

### 1.9.9.1 — 2026-10-10
- Ikony maszyn sąsiadów na mapie są chowane także wtedy, gdy gra zrobiła je wcześniej, niż dotarła informacja, czyje to maszyny.

### 1.9.9.0 — 2026-10-10
- Maszyny sąsiadów nie pokazują się na mapie także po wczytaniu zapisu (gracz dołączający do serwera dostaje stan wszystkich maszyn sąsiadów).

### 1.9.8.9 — 2026-10-10
- Zbiornik kombajnu jest opróżniany przy 60 % (każdy kombajn, także z modów), więc sąsiad nie staje z pełnym zbiornikiem.
- Po zakończonej pracy każda maszyna jest opróżniana do zera (ziarno, nasiona, nawóz, oprysk); paliwo zostaje.
- Materiały od sąsiada (nasiona, nawóz, herbicyd) są do twojej dyspozycji: palety należą na czas kontraktu do twojej farmy, a materiał trafia też do jego silosa, z którego możesz ładować (także pożyczoną maszyną).

### 1.9.8.8 — 2026-10-10
- Naprawiony błąd „table index is nil” przy sprawdzaniu bram (obiekt bez farmy).

### 1.9.8.7 — 2026-10-10
- Jak w Fields of Stories: po postawieniu, przesunięciu lub usunięciu miejsca maszyny sąsiad przyprowadza, przestawia lub zabiera maszyny dopiero wtedy, gdy zmienia czynność w planie dnia. Maszyny z usuniętych miejsc znikają od razu.

### 1.9.8.6 — 2026-10-10
- Pożyczona maszyna: bramy podwórka sąsiada otwierają się dla ciebie.
- Narzędzie usuwania zabiera tylko miejsce pod kursorem (zamiast w promieniu 30 m).
- Wiele poprawek bezpieczeństwa: błąd nie zostawi już zablokowanego pola, nie zatrzyma wczytywania i nie będzie się powtarzał co klatkę.

### 1.9.8.5 — 2026-10-10
- Naprawione: przy wczytywaniu gry błąd przerywał ładowanie – nie wczytywały się podstawowe miejsca z mapy (domy, miejsca maszyn) ani domyślne stroje.
- Przerwane wczytywanie nigdy nie nadpisze zapisanych danych sąsiadów.
- Miejsca, stroje i relacje wczytują się przed maszynami; każdy krok wczytywania jest w logu.
- Sąsiedzi mają swoje stroje z moda – usunięta opcja „Ubierz jak mnie”.
- Pożyczona maszyna: każde pole oznaczone jednym czerwonym kółkiem, zielone kółko odbioru dokładnie na maszynie.

### 1.9.8.3 — 2026-10-10
Poprawki z GIANTS TestRunnera:
- Ikona moda w formacie DXT1.
- Błędy nie są już przechwytywane i ukrywane – trafiają do logu z pełnym opisem.

### 1.9.8.2 — 2026-10-10
- Nowe logo moda.

### 1.9.8.1 — 2026-10-10
- Sąsiedzi nie czekają już w nieskończoność na złożenie maszyn (jedno oczekiwanie, właściwy kierunek składania).
- Nieodebrany telefon: sąsiad dzwoni drugi raz po ok. 30 minutach w grze, a gdy znów nie odbierzesz – SMS „Widzę, że jesteś zajęty, zajmę się tym sam” i robi pola sam.
- Ponowna próba nie liczy się jako nowy telefon z dziennego limitu.
- Wiadomości w telefonie można oznaczyć jako przeczytane (znikają).
- SMS-y i nieodebrane połączenia widzi tylko farma, której dotyczą.

### 1.9.8.0 — 2026-10-10
Poprawki z GIANTS TestRunnera:
- Ikony w sklepie 512×512 w formacie BC7.
- `descVersion` 113, poprawiony polski tytuł, changelog w opisie moda.
- Dźwięk stawiania oraz obszary czyszczenia i wyrównania dla znaczników w menu budowania.
- Ścieżki tekstur i presetów map wpisane wprost (bez fałszywych „nieużywanych plików”).
- Wszystkie zabezpieczone wywołania zapisują błędy w logu (`GN.try`) zamiast je ukrywać.

### 1.9.7.1 — 2026-10-10
- Maszyny składane po pracy i przed wyjazdem (pomocnik SI wymaga pozycji transportowej).
- Heder zostaje na kombajnie (nie wisi już w powietrzu).

### 1.9.7.0 — 2026-10-10
- Tryb samolotowy w telefonie – sąsiedzi nie dzwonią do danej farmy.
- Gdy jeden gracz farmy odbierze, telefon u pozostałych od razu przestaje dzwonić.

### 1.9.6.9 — 2026-10-10
- Tyle telefonów od sąsiadów dziennie, ile ustawiono (na farmę), rozłożonych od rana na cały dzień.
- Zmiana ustawienia działa od razu na dzisiejsze telefony.

### 1.9.6.8 — 2026-10-10
- Naprawione rozciągnięte wałki odbioru mocy przy maszynach sąsiadów (u graczy).

### 1.9.6.7 — 2026-10-10
- Miejsca maszyn zachowują kierunek, w jakim je postawiono.
- Maszyny stoją na środku swojego miejsca.
- Nachodzące na siebie miejsca podświetlane na czerwono i ostrzeżenie.

### 1.9.6.6 — 2026-10-09
- Złe odpowiedzi w rozmowie odejmują 40–80 pkt relacji, dobre dodają 40–80 (raz dziennie u sąsiada).

### 1.9.6.5 — 2026-10-09
- Punkty relacji za rozmowę raz dziennie, zależne od dopasowania odpowiedzi, z dźwiękiem i komunikatem.

### 1.9.6.4 — 2026-10-09
- Zapłata za kontrakty jak w modzie Invoices (stawka za hektar wg pracy i uprawy × trudność ekonomiczna).

### 1.9.6.3 — 2026-10-09
- Bez wynajmu maszyn z gry – pożyczenie tylko wtedy, gdy sąsiad ma własną maszynę do tej pracy.

### 1.9.6.2 — 2026-10-09
- Maszyny sąsiadów naprawdę pracują na ziemi, którą trzymają podczas pracy; uzupełniane w trakcie; kontrola pracy w logu.

### 1.9.6.1 — 2026-10-09
- Domyślne stroje wszystkich sąsiadów w `data/outfits.xml`.

### 1.9.6 — 2026-10-09
- Wynik pracy sąsiada zawsze trafia na pole; zbiornik kombajnu napełnia się i opróżnia przy 60%.
- Sąsiedzi trzymają ziemię wokół pola, startują wewnątrz pola, kończą o 22:00 albo gdy utkną.
- Maszyny pojawiają się/znikają razem ze swoimi miejscami i wracają po pracy; wiszące w powietrzu są stawiane na ziemi.
- Silos na miejscu silosu.
- Kontrakt z pożyczoną maszyną liczy się dopiero po jej odstawieniu; termin liczony od przyjęcia.
- Bramy zagrody sąsiada otwierają się w czasie jego kontraktu.
- SMS o telefonie znika po rozmowie; przy NPC „Rozpocznij rozmowę”.
- Znacznik „Moja farma” (tu odwiedzają cię sąsiedzi).
- Rozmowy w języku gry; 98 nowych rozmów; logowanie strojów do moda.

### 1.9.5 — 2026-10-09
- Każdy sąsiad ma własne, stałe maszyny (`data/fleets.xml`): dwa ciągniki, kombajn, heder, maszyny, przyczepy, obciążniki, auto; handlarka z ciężarówką; wapnowanie rozsiewaczem nawozu.

### 1.9.4 — 2026-10-09
- Zapisane stroje zachowane dokładnie (bez wymuszania włosów, koszule bez kolorów zostają).

### 1.9.3 — 2026-10-09
- Automatyczna konfiguracja działa krokami (gra nie ma korutyn dla modów).
- Presety miejsc dla map MapUS/EU/AS; pola dzielone wokół domów z presetu.

### 1.9.2 — 2026-10-09
- Presety map: każdy zapis tworzy `goodNeighbours_<mapa>.xml`, nowa gra na tej mapie startuje z `data/maps/<mapa>.xml`.

### 1.9.1 — 2026-10-09
- Każde wolne pole należy do któregoś rolnika-sąsiada; pole kupione przez gracza od niego odchodzi.

### 1.9 — 2026-10-09
- Sąsiedzi zaczynają pracę na polu (maszyna poprawnie podpięta), ukryta farma NPC z nieograniczonym budżetem.
- Ziemia z kontraktem gracza nigdy nie jest zajmowana; maszyny parkowane przy wczytaniu i po pracy.
- Materiały przy silosie do kontraktów telefonicznych, terminy kontraktów, kilka kontraktów naraz, ubrania na postaciach.

### 1.8 — 2026-10-09
- Rozmowy (136, EN/DE/PL) z wyborem odpowiedzi i punktami relacji.
- Plany dnia z autami i ciągnikami w miejscach, odwiedziny na podwórkach graczy.
- Automatyczna konfiguracja mapy (domy, miejsca maszyn wg rozmiaru, miejsca odwiedzin, Shift+G).
- Poranne telefony, strony pomocy, własne dźwięki, miejsca odpoczynku i spacerów.

### 1.7.1 — 2026-10-08
- Log, dlaczego pomocnik sąsiada się zatrzymał; takie pole nie jest ponawiane tego dnia.

### 1.7 — 2026-10-08
- Własna kategoria w menu budowania (miejsca / sąsiedzi), rozmiary miejsc (Shift+Q), usuwanie wszystkich danego rodzaju (Shift+Del).
- Ramki i ikony nad miejscami, panel „jest / potrzeba”, opcje telefonu w ustawieniach, ikony minimapy.

### 1.6 — 2026-10-08
- Sąsiedzi zbierają zboże własnym kombajnem z hederem, koszą, przetrząsają i prasują sami.

### 1.5 — 2026-10-08
- Miejsca odwiedzin i miejsca maszyn jako narzędzia budowania (z usuwaniem), sąsiedzi chodzą do miejsc z planu dnia, malowane tapety.

### 1.4 — 2026-10-08
- Etapy pożyczonej maszyny z kółkami na mapie i GPS (odbiór, pola, zwrot), podziękowanie albo kara, darmowe materiały u sąsiada, stawka za hektar.
- Ikony mapy idą za sąsiadem.

### 1.3 — 2026-10-08
- Narzędzia w menu budowania (dom / parking), własna godzina wyjazdu do pracy, kontrakty zarezerwowane na telefon, 3 telefony dziennie, sekcja ustawień w menu gry.

### 1.2 — 2026-10-08
- Plany dnia, pożyczanie maszyny sąsiada przez telefon, właściciele pól na liście NPC, właściciel maszyny w okienku info.

### 1.1 — 2026-10-08
- Sąsiedzi widoczni w domach w swoich strojach, rozmowa twarzą w twarz, własne maszyny i praca SI na niewziętych kontraktach, kierowca wygląda jak sąsiad.
- Parking dla maszyn sąsiada, katalog ubrań w logu.

### 1.0 — 2026-10-08
- Pierwsza wersja: sąsiedzi z polami, SMS-y i telefony z kontraktami, relacje z premiami, telefon (GUI), synchronizacja w multiplayer.
- Portrety siedmiu sąsiadów, ikony na mapie, tapety telefonu.

---

## English

### 1.9.9.7 — 2026-10-10
- The lent machine and the material are picked up at the neighbour's yard again (no delivery to the “My farm” place).

### 1.9.9.6 — 2026-10-10
- A contract taken in a call has to be done within 10 hours (game time); after that it fails.

### 1.9.9.5 — 2026-10-10
- A neighbour no longer holds land with a player's buildings on it (house, sheds) while he works – the building no longer changes owner with the land.

### 1.9.9.4 — 2026-10-10
- With a “My farm” place set, the neighbour brings the lent machine and the material (seeds, fertilizer, herbicide) to your farm and fetches them there afterwards – closed yard gates are no problem.
- Fixed: a contract from a call could fail at once when the neighbour was holding that land for his own work.

### 1.9.9.3 — 2026-10-10
- New text of the SMS after a missed call: “You probably have your day planned already – then I'll take care of it myself.”

### 1.9.9.2 — 2026-10-10
- Long texts in the phone scroll (mouse wheel, arrows, scroll bar).
- Neighbours plan their calls at 8:00 and call until 12:00 at the latest; when the calls of the day are used up, the next ones are planned the next day at 8:00.

### 1.9.9.1 — 2026-10-10
- The map icons of the neighbours' machines are hidden also when the game made them before it knew whose machines they are.

### 1.9.9.0 — 2026-10-10
- The neighbours' machines stay off the map also after loading a savegame (a joining player gets the state of all neighbour machines).

### 1.9.8.9 — 2026-10-10
- The combine's grain tank is emptied at 60 % (any combine, also from mods), so the neighbour does not stop with a full tank.
- After the work every machine is emptied (grain, seeds, fertilizer, spray); fuel stays.
- Material from the neighbour (seeds, fertilizer, herbicide) is yours to use: the pallets belong to your farm during the contract, and the material also goes into his silo, which you may load from (also with the borrowed machine).

### 1.9.8.8 — 2026-10-10
- Fixed “table index is nil” in the gate check (object without a farm).

### 1.9.8.7 — 2026-10-10
- Like in Fields of Stories: after a machine place is set, moved or removed, the neighbour brings, moves or takes away his machines when he changes his activity. Machines of a removed place go at once.

### 1.9.8.6 — 2026-10-10
- Borrowed machine: the gates of the neighbour's yard open for you.
- The remove tool takes only the place under the cursor (instead of within 30 m).
- Many safety fixes: an error no longer leaves a field locked, stops loading or repeats every frame.

### 1.9.8.5 — 2026-10-10
- Fixed: an error stopped loading the game data – map presets (homes, machine places) and default outfits were not loaded.
- An unfinished load never overwrites the saved neighbour data.
- Places, outfits and relations load before the machines; every load step is logged.
- The neighbours wear their own outfits from the mod – the “dress like me” option is gone.
- Borrowed machine: one red circle per field, the green pickup circle sits exactly on the machine.

### 1.9.8.3 — 2026-10-10
GIANTS TestRunner fixes:
- Mod icon in DXT1 format.
- Errors are no longer caught and hidden – they go to the log with full details.

### 1.9.8.2 — 2026-10-10
- New mod logo.

### 1.9.8.1 — 2026-10-10
- Neighbours no longer wait forever for folding (one wait, correct fold direction).
- Missed call: one retry after ~30 in-game minutes, then an "I see you are busy, I'll do it myself" SMS and the neighbour does the fields himself.
- Retries do not count as new calls; messages can be marked as read; SMS only shown to the farm they belong to.

### 1.9.8.0 — 2026-10-10
- GIANTS TestRunner fixes: 512×512 BC7 store icons, `descVersion` 113, title, changelog, placement sound + clear/level areas, explicit texture/preset file lists, protected calls log their errors (`GN.try`).

### 1.9.7.1 — 2026-10-10
- Machines folded up after work and before driving out; the header stays on the combine.

### 1.9.7.0 — 2026-10-10
- Airplane mode in the phone; other phones of the farm stop ringing as soon as one player answers.

### 1.9.6.9 — 2026-10-10
- As many neighbour calls a day as set (per farm), spread over the day; the setting applies at once.

### 1.9.6.8 — 2026-10-10
- Stretched PTO shafts of the neighbours' implements fixed on clients.

### 1.9.6.7 — 2026-10-10
- Machine places keep their direction, machines stand in the middle of their place, overlapping places shown red.

### 1.9.6.6 / 1.9.6.5 — 2026-10-09
- Conversations change the relationship by 40–80 points once a day per neighbour: good answers add, bad answers take away.

### 1.9.6.4 — 2026-10-09
- Contract pay as in the Invoices mod (price per hectare by work and crop × difficulty).

### 1.9.6.3 — 2026-10-09
- No leased machines; borrowing only when the neighbour has his own machine for the job.

### 1.9.6.2 — 2026-10-09
- Neighbours' implements really work the land they hold, kept full while working, work check in the log.

### 1.9.6.1 — 2026-10-09
- Default outfits of all neighbours in `data/outfits.xml`.

### 1.9.6 — 2026-10-09
- Field work always takes effect (grain tank fills, emptied at 60%), land around the field held, start inside the field, stop at 22:00 or when stuck.
- Machines appear/disappear with their places and drive back after work; silo building on the silo place.
- Contracts with a lent machine count only once it is brought back; deadlines from acceptance.
- Gates of the neighbour's yard open during his contracts; "My farm" place; conversations in the game language; 98 new conversations.

### 1.9.5 — 2026-10-09
- Every neighbour has his own fixed machines (`data/fleets.xml`).

### 1.9.4 — 2026-10-09
- Saved outfits kept exactly.

### 1.9.3 — 2026-10-09
- Set-up runs as steps; map presets for MapUS/EU/AS.

### 1.9.2 — 2026-10-09
- Map presets written with every save and used for new games.

### 1.9.1 — 2026-10-09
- Every free field belongs to a farming neighbour; land bought by a player leaves.

### 1.9 — 2026-10-09
- Neighbours start work on the field, hidden NPC farm, contract deadlines, materials at the silo, several contracts at once.

### 1.8 — 2026-10-09
- 136 conversations (EN/DE/PL), day plans with cars and tractors, visits to players' yards, automatic map set-up, morning calls, help pages, sounds.

### 1.7.1 — 2026-10-08
- Log why a neighbour's helper stops; such a field is not retried the same day.

### 1.7 — 2026-10-08
- Own construction category, place sizes (Shift+Q), remove all of a kind (Shift+Del), place boxes and icons, set/needed panel.

### 1.6 — 2026-10-08
- Neighbours harvest with their own combine, mow, ted and bale.

### 1.5 — 2026-10-08
- Visit and machine places as construction tools, neighbours go to places from their day plan.

### 1.4 — 2026-10-08
- Lent machine stages with map circles and GPS, return place, free supplies, pay per hectare; map icons follow the neighbour.

### 1.3 — 2026-10-08
- Construction tools, own work start time, contracts kept for the call, 3 calls per day, settings section.

### 1.2 — 2026-10-08
- Day plans, lending the neighbour's machine, field owners in the NPC list, machine owner in the info box.

### 1.1 — 2026-10-08
- Neighbours visible at home in their outfits, face-to-face talk, own machines and AI field work, driver looks like the neighbour.

### 1.0 — 2026-10-08
- First release: neighbours with fields, SMS and calls with contracts, relationships with bonuses, phone GUI, multiplayer sync, portraits, map icons, wallpapers.
