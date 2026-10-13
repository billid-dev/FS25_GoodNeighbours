# Changelog – Good Neighbours (FS25_GoodNeighbours)

🇵🇱 [Polski](#polski) · 🇬🇧 [English](#english)

---

## Polski

### 1.0.0.0 — 2026-10-13 — wydanie oficjalne (ModHub)
Pierwsze oficjalne wydanie. Nowości od 1.9.17.0:
- **Korzyści z relacji** (rosną od poziomu 3, pełne na poziomie 10): burmistrz Richard Hale – ziemia do 10% taniej, Frank Weber – naprawy i lakierowanie do 20% taniej, Monika Zielinska – plony i produkty sprzedajesz do 5% drożej
- Na poziomie 1 mała kara (ziemia i naprawy +5%, sprzedaż -3%), na poziomie 2 połowa; komunikat pokazuje, ile zaoszczędziłeś lub straciłeś, a kontakt w telefonie – obecną korzyść i następny poziom
- Odsprzedaż ziemi zwraca cenę z tą samą zniżką, więc kupno i sprzedaż nie daje zarobku
- **56 nowych, dłuższych rozmów** (po 8 na sąsiada) z 3–5 odpowiedziami; dłuższe rozmowy są wybierane częściej
- Punkty za rozmowę liczone ze wszystkich odpowiedzi: od -80 (same złe) przez 0 do +80 (same dobre)
- Poprawka: samo otwarcie rozmowy i wyjście dawało +40 pkt relacji – teraz liczy się tylko rozmowa doprowadzona do końca z co najmniej jedną odpowiedzią
- Poprawka: opcję „przyczepa przy sieczkarni” w ustawieniach znów da się przełączyć
- Poprawka: koniec z setkami błędów „EffectManager:setFillType is deprecated” w logu (strumień sieczki)
- Ikony sklepu zapisane jako DXT5 (koniec z ostrzeżeniami „BC7 has undefined channel count”)
- Tapety telefonu przemianowane, z jednej usunięte logo marki (zasady ModHub)
- Rozbudowany opis moda
- Cichy log: mod zapisuje tylko problemy; szczegółowy log po utworzeniu pliku `modSettings/FS25_GoodNeighbours/debug.txt`

### 1.9.17.0 — 2026-10-12
- Przyczepa do sieczki na serwerze dedykowanym: serwer wysyła stan rozładowanej przyczepy razem z komunikatem o rozładunku i powrocie, a gra gracza ustawia go u siebie (zwykła synchronizacja gry nie zawsze docierała i przyczepa u gracza wyglądała na pełną).

### 1.9.16.9 — 2026-10-12
- Sąsiedzi nie proponują przez telefon (ani nie robią sami) nawożenia, oprysku ani pielenia na uprawie, która jest już gotowa do zbioru – gra zostawia takie stare kontrakty na liście, a postęp liczy się tylko tam, gdzie koła zniszczą uprawę. Zbiór jest proponowany tylko na dojrzałym polu.
- Jeśli taki kontrakt nie wyjdzie, bo uprawa dojrzała, sąsiad nie odbiera punktów relacji.

### 1.9.16.8 — 2026-10-12
- Przyczepa do sieczki jest opróżniana sposobem gry (wszystkie zbiorniki naraz), potem sprawdzana; log serwera podaje poziom, pojemność i ile zostało.

### 1.9.16.7 — 2026-10-12
- Przyczepa do sieczki na serwerze dedykowanym: po rozładunku wraca pusta także u graczy (serwer wysyła stan napełnienia, a gra gracza odświeża widok przyczepy).

### 1.9.16.6 — 2026-10-12
- Kontrakty z telefonu, których gra „nie może teraz rozpocząć” (np. zaraz po północy, gdy aktualizuje pola), są ponawiane do 3 razy co kilka sekund.
- Komunikat o nierozpoczętych kontraktach podaje powód: limit kontraktów gry (z jego wartością), gra nie pozwala teraz, kontrakt nieaktualny, ktoś już go wziął, sąsiad pracuje na tej ziemi.

### 1.9.16.5 — 2026-10-12
- Test żniw (Shift+M): gdy gra nie wystawiła na ziemi sąsiada kontraktu żniw, sąsiad i tak zbiera jedno ze swoich dojrzałych pól (najpierw kukurydzę), a po pracy pole jest zebrane jak przy kontrakcie.

### 1.9.16.4 — 2026-10-12
- Edytor maszyn na serwerze dedykowanym: można wybierać maszyny z modów. Wcześniej gracz wysyłał ścieżkę moda ze swojego komputera (C:/Users/...), a serwer ma mody gdzie indziej, więc nie znajdował maszyny. Teraz ścieżki idą w formie „$moddir$NazwaModa/...”, tak jak przesyła je sama gra.
- Maszyna, która dopiero przyjechała, jest wymieniana na inną dopiero po kilku sekundach – szybkie klikanie w edytorze psuło Courseplay u graczy (błąd CpCourseManager w kółko).

### 1.9.16.3 — 2026-10-12
- Przyczepa do sieczki: przy wyborze strony za stojący łan liczy się tylko zbierana uprawa. Łąka lub inne pole obok nie są już brane za nieskoszony łan, więc przyczepa nie wjeżdża w kukurydzę przy brzegu pola.

### 1.9.16.2 — 2026-10-12
- Odstęp przyczepy do sieczki jest liczony od rozłożonego hedera (z jego pola roboczego), a nie od złożonego – ciągnik nie jedzie już pod hederem.

### 1.9.16.1 — 2026-10-12
- Rura sieczkarni jest rozkładana do pozycji roboczej i obracana do przyczepy (po aktualizacji pojazdu przez grę, żeby gra jej nie cofała); strumień sieczki jest podtrzymywany. Po pracy rura się składa.

### 1.9.16.0 — 2026-10-12
- Przyczepa do sieczki jedzie po skoszonej stronie: przyczepa obok sieczkarni, ciągnik z przodu obok hedera.
- Rura sieczkarni obraca się w stronę przyczepy i widać lecącą sieczkę.
- Gdy przyczepa odjeżdża się rozładować, sieczkarnia stoi i czeka, aż wróci.

### 1.9.15.2 — 2026-10-12
- Shift+G (natychmiastowy spawn wszystkich maszyn) znów działa w menu budowania – klawisz jest też odczytywany bezpośrednio, gdy gra nie przekaże skrótu; działa także bez narzędzia w ręce.

### 1.9.15.1 — 2026-10-12
- Przyczepa przy sieczkarni jedzie obok niej po stronie rury, z odstępem na szerokość sieczkarni i hedera – ciągnik z przyczepą nie wchodzi już w maszynę. Plandeka przyczepy otwiera się na czas zbierania sieczki i zamyka po pracy.

### 1.9.15.0 — 2026-10-12
- Edytor maszyn (Shift+M): nowy wiersz „Silos” – dla każdego rolnika można wybrać model silosu ze sklepu (także z modów). Po zmianie stary silos znika, a nowy staje na jego miejscu na silos.
- Przy stawianiu miejsca na silos widać przy kursorze podgląd wybranego silosu.

### 1.9.14.6 — 2026-10-12
- Żniwa: heder jest łączony tylko z maszyną, która ma do niego pasujące zaczepienie (wcześniej sąsiad próbował założyć heder do kukurydzy od sieczkarni na kombajn i nie wyjeżdżał).

### 1.9.14.5 — 2026-10-12
- Shift+Q (zmiana rozmiaru miejsca) i Shift+Del znów działają w menu budowania – klawisze są też odczytywane bezpośrednio, gdy gra nie przekaże skrótu.

### 1.9.14.4 — 2026-10-12
- Przycisk „Test: żniwa teraz” w edytorze maszyn (Shift+M, admin): wybrany sąsiad od razu jedzie zbierać swoje pole (najpierw kukurydza) maszynami, które ma w edytorze – także po 22:00. Na ekranie widać wynik: wyjechał / nie ma pola gotowego do zbioru / żadna maszyna nie zbierze danej uprawy.

### 1.9.14.3 — 2026-10-12
- Przy stawianiu miejsca panel pokazuje, która maszyna sąsiada tam stanie („Tu stanie: Krone BiG X 1180 (Inna 1)”).

### 1.9.14.2 — 2026-10-12
- Edytor maszyn (Shift+M) otwiera się zawsze: listy maszyn są pobierane z serwera przy otwarciu menu budowania i edytora (wcześniej po wczytaniu zapisu pokazywał „Brak maszyn – najpierw ustaw jego miejsca”, choć maszyny stały).
- Maszyny można wybierać także zanim sąsiad je wystawi – wybór zostanie użyty, gdy przyjdą.

### 1.9.14.1 — 2026-10-12
- Maszyny sąsiadów bez właściciela (gra przenosiła je do sklepu po „wyrzuceniu poza świat” i powstawały kopie bez nazwy sąsiada, do których nie dało się wsiąść) są po 2 minutach zabierane – sąsiad i tak ma swoje maszyny na miejscach.
- Przyczyna: po wczytaniu zapisu ciągnik sąsiada był przestawiany razem z podczepioną maszyną, co rozsypywało fizykę. Teraz przed przestawieniem wszystko jest odczepiane, a maszyny trafiają osobno na swoje miejsca.
- Kontrakt z telefonu nie blokuje się już na „PENDING_MISSION”: przygotowane kontrakty są kończone przed startem nowego, a ten, który wciąż czeka na maszyny, jest wpisywany do logu.

### 1.9.14.0 — 2026-10-12
- **Materiały do kontraktów według wielkości pola.** Ilość liczona z danych gry (GIANTS): nasiona = zużycie uprawy na m² × hektary, nawozy / środki = zużycie typu oprysku (litry na sekundę przy prędkości roboczej) przeliczone na hektar. Zapas: +25 % nasiona, +50 % nawozy, herbicyd i wapno (siewniki i rozsiewacze zużywają więcej przy wolniejszej jeździe, uwrocia, zakładki).
- **Dowóz w trakcie kontraktu:** co minutę sąsiad sprawdza, ile materiału zostało przy silosie i ile jeszcze potrzeba na nieskończoną część pól – gdy zostaje mniej niż ok. 1/3 potrzeby, dowozi resztę (komunikat „dowiózł więcej … na resztę pola”).

### 1.9.13.4 — 2026-10-12
- **Kontrakty z telefonu po godzinie 10:00 znów działają.** Termin 10 godzin był liczony od północy zamiast od teraz – po 10:00 gra uznawała kontrakt za przeterminowany i go usuwała („Nie udało się rozpocząć kontraktów … już zajęte albo osiągnięto limit”). Teraz termin to zawsze 10 godzin od przyjęcia.

### 1.9.13.3 — 2026-10-12
- Pracujący sąsiad nie zajmuje już ziemi wokół swojego pola, jeśli leży na niej pole proponowane właśnie przez telefon – kontrakt z telefonu da się wtedy przyjąć (wcześniej „już zajęte albo osiągnięto limit”).
- W logu jest powód, gdy kontrakt nie wystartuje (sąsiad pracuje na tej ziemi / gra już go nie oferuje / odpowiedź gry).

### 1.9.13.2 — 2026-10-12
- **Gra jednoosobowa:** sąsiedzi pracują na polach także w singlu. Gra w singlu nie tworzy drugiej farmy (farma sąsiadów 15), przez co praca była dotąd wyłączona – teraz maszyny i pola sąsiadów działają bez niej, a ich pomocnicy nic nie kosztują.

### 1.9.13.1 — 2026-10-12
- Edytor maszyn: po dodaniu innej maszyny zaznaczenie zostaje na „+ Dodaj inną maszynę” (wcześniej przeskakiwało na dodaną maszynę i kolejne „Zastosuj” ją podmieniało zamiast dodać nową).

### 1.9.13.0 — 2026-10-12
- **Wóz przy sieczkarni:** gdy sąsiad sieczkuje, jego wolny ciągnik z przyczepą na sieczkę jedzie obok sieczkarni pod rurą i odbiera sieczkę. Pełna przyczepa odjeżdża do domu, jest rozładowana i wraca pusta po ok. 45 s (w tym czasie sieczka znika jak wcześniej). Wóz jest prowadzony przez mod, poza fizyką – nie zderza się z niczym.
- Potrzebne wśród maszyn sąsiada: wolny ciągnik i przyczepa, która przyjmuje sieczkę (dodaj w edytorze maszyn jako „inną maszynę”). Bez nich sieczka po prostu znika.
- Nowe ustawienie admina „Wóz przy sieczkarni” (ESC → Ustawienia → Dobrzy Sąsiedzi), domyślnie włączone.

### 1.9.12.1 — 2026-10-12
- Sieczkarnia sąsiada pracuje bez przyczepy obok: pomocnik gry nie czeka już na wóz pod rurą, sieczka trafia do wewnętrznego bufora sieczkarni, który mod opróżnia co sekundę (jakby odbierał ją wóz). Dotyczy tylko maszyn sąsiadów – sieczkarnie graczy działają jak w grze.

### 1.9.12.0 — 2026-10-12
- **Nowy rozmiar miejsca: HEDER** (Shift+Q w narzędziu sąsiada) – heder kombajnu stoi na własnym, szerokim i krótkim miejscu. W starych zapisach heder dalej stoi na miejscu „pojazd + maszyna”, dopóki nie postawisz mu miejsca HEDER.
- **Edytor maszyn – inne maszyny:** na dole listy maszyn sąsiada „+ Dodaj inną maszynę”; wybór dowolnej maszyny ze sklepu (także z modów) z przełączaną kategorią (sieczkarnie, kombajny do ziemniaków i buraków, hedery do kukurydzy …), „Usuń” zabiera ją z powrotem. Każda dostaje swoje miejsce (rozmiar według rodzaju maszyny).
- **Żniwa według uprawy:** sąsiad sam dobiera maszynę do pola – kombajn samobieżny do ziemniaków / buraków, kombajn lub sieczkarnia z hederem dla tej uprawy (np. kukurydza), albo ciągnik z kombajnem przyczepianym. Pól, dla których nie ma maszyny, nie zaczyna. Zbiorniki wszystkich tych maszyn opróżniają się przy 60 % i do zera po pracy.

### 1.9.11.5 — 2026-10-12
- Po żniwach kombajn sąsiada opróżnia się do zera, chowa rurę i składa, a heder jest składany, odczepiany i odstawiany na swoje miejsce (miejsce „pojazd + maszyna”); kombajn staje sam na swoim miejscu.

### 1.9.11.4 — 2026-10-12
- Edytor maszyn: wszystkie ciągniki sąsiada razem na górze listy („Ciągnik 1”, „Ciągnik 2” …), potem kombajn, samochód, narzędzia i reszta; krótsze nazwy, żeby mieściła się nazwa maszyny.

### 1.9.11.3 — 2026-10-12
- Edytor maszyn naprawdę otwiera się ponownie (okno nie zgłaszało grze zamknięcia).
- Shift+M w menu budowania otwiera edytor bez wybierania narzędzia; po lewej lista sąsiadów, obok maszyny wybranego sąsiada, w głównym panelu wymiana maszyn.

### 1.9.11.2 — 2026-10-12
- Edytor maszyn otwiera się ponownie po zamknięciu (Shift+M działało tylko raz); klawisze menu budowania wracają po zamknięciu okna.

### 1.9.11.1 — 2026-10-12
- Edytor maszyn: zdjęcia maszyn ze sklepu – obecna, nowa i przy każdej maszynie na liście.

### 1.9.11.0 — 2026-10-12
- **Podgląd maszyny przy stawianiu miejsca:** narzędziem sąsiada (rozmiary vehicle / vehicle + attachment / oversize) przy kursorze stoi model maszyny, która dostanie to miejsce, w świecącej ramce (zielona – wolne, czerwona – nachodzi na inne miejsce).
- **Edytor maszyn (Shift+M, admin)** w menu budowania z narzędziem sąsiada: lista jego maszyn (ciągnik, kombajn, samochód, narzędzia, dodatkowe), obok obecna i nowa maszyna ze zdjęciem, marką, modelem, kategorią i ceną; poniżej maszyny ze sklepu z tej samej kategorii (także z modów), po 8 na stronę. „Zastosuj” – stara maszyna znika, nowa staje na jej miejscu; „Domyślna” – wraca maszyna z moda. Wybór zapisuje się w zapisie gry.
- Burmistrz, handlarka i dealer: miejsce nie jest już zajmowane przez nieistniejący ciągnik – ich pojazdy dostają właściwe miejsca.

### 1.9.10.13 — 2026-10-12
- **Shift+G (admin)** w menu budowania: wszyscy sąsiedzi od razu przyprowadzają, przestawiają lub zabierają maszyny zgodnie z postawionymi miejscami – bez czekania na zmianę czynności. Sąsiedzi w trakcie pracy dojadą po jej zakończeniu.
- Usunięty klawisz automatycznego rozstawiania miejsc (pierwsze ustawienie po wczytaniu nowej gry działa jak dotąd).

### 1.9.10.12 — 2026-10-10
- Zmienione kwoty w kontraktach – nowy cennik sąsiadów (€/ha, mnożone przez poziom trudności ekonomii: łatwy ×1,2, normalny ×1,1, trudny ×1,0):
  - orka 2600, kultywator 2100, brona 1700, siew 1900, nawożenie 1400, wapnowanie 1400, oprysk 1300, pielenie 1400, wałowanie 1000, zbieranie kamieni 2000, mulczowanie 1800
  - koszenie 2200, przetrząsanie 1100, żniwa 2700
  - zbiór: ziemniaki / buraki / warzywa / ryż 3600–3300, trzcina 4200, bawełna 3500, winogrona / oliwki 3200
  - siew / sadzenie: ziemniaki / trzcina 2600, ryż 2300, buraki / warzywa 2200

### 1.9.10.11 — 2026-10-10
- Burmistrz, handlarka zbożem i dealer: narzędzie sąsiada ma teraz tę samą listę rozmiarów miejsc co rolnicy (Shift+Q).

### 1.9.10.10 — 2026-10-10
- Mapy spoza gry podstawowej: mod sam zapamiętuje miejsca (domy, miejsca maszyn, miejsca odwiedzin, pola) przy każdym zapisie gry w `modSettings/FS25_GoodNeighbours/maps/<mapa>.xml` i używa ich w każdej nowej grze na tej mapie.
- Presety w modzie działają dla każdej mapy (`data/maps/<mapa>.xml`), nie tylko podstawowych.

### 1.9.10.9 — 2026-10-10
- Kombajny sąsiadów naprawdę opróżniają się przy 60 % (sprawdzane co sekundę) – wcześniej gra odmawiała opróżnienia, zbiornik dochodził do 100 % i kombajn stawał.
- Sąsiad nie dzwoni, gdy farma ma już maksymalną liczbę kontraktów dozwoloną przez grę, i proponuje najwyżej tyle pól, ile jeszcze się zmieści.

### 1.9.10.8 — 2026-10-10
- Ikony sąsiadów na mapie (menu mapy) można kliknąć: imię, rola, poziom relacji, co teraz robi i zdjęcie.
- Pożyczone maszyny na mapie można kliknąć – gdy utkną, „Reset maszyny” odstawia je na miejsce odbioru u sąsiada (w trakcie pracy trzeba ją odebrać ponownie, przy zwrocie liczy się jako oddana).

### 1.9.10.7 — 2026-10-10
- Sąsiedzi zaczynają pracę od razu w miejscu, w którym pojawiają się na polu – nie jadą już drogami na poprzednie pole, kombajny znów ruszają (wcześniej „not in transport mode”).
- Anulowany lub zawalony kontrakt z pożyczoną maszyną: sąsiad od razu zabiera maszynę (pustą), -50 pkt relacji i koniec – bez odstawiania.

### 1.9.10.6 — 2026-10-10
- Kontrakt zawalony lub zniknięty (np. usunięty przez grę) zawsze zwraca pożyczoną maszynę sąsiadowi i zabiera materiały; kontrakty z zapisu, których już nie ma, zamykają się minutę po wczytaniu.
- Materiały tylko raz: najpierw palety, do silosu sąsiada trafia tylko to, czego palety nie pokryły; ilość w silosie jest zapisywana w zapisie gry.
- Palety, które pojawiły się po zakończeniu kontraktów, są od razu usuwane.
- Gdy trwa już kontrakt z danym sąsiadem, nie proponuje drugiej maszyny ani drugiej dostawy materiałów.
- Odebrany telefon bez odpowiedzi nie dzwoni ponownie w tej samej sprawie.
- Usunięcie miejsca: znika tylko maszyna bez miejsca, pozostałe przestawiają się przy następnej zmianie czynności sąsiada.

### 1.9.10.5 — 2026-10-10
- Sąsiad wystawia tyle nasion / nawozu / herbicydu / wapna, ile gra zużywa na to pole (według danych gry dla uprawy i środka, na hektar), plus 25 % zapasu – zawsze starcza.

### 1.9.10.4 — 2026-10-10
- Pożyczona maszyna jest pusta – trzeba ją załadować materiałem od sąsiada (palety przy jego silosie / jego silos). Koniec z automatycznym napełnianiem maszyn na podwórku sąsiada.

### 1.9.10.3 — 2026-10-10
- Sąsiedzi pojawiają się od razu na swoim polu i tam zaczynają pracę – pomocnik nie dojeżdża już drogami do pola (dojazd przyjdzie później z obsługą AutoDrive).

### 1.9.10.2 — 2026-10-10
- O 22:00 wszyscy pomocnicy sąsiadów kończą pracę na polach, bez względu na to, co robią – także pomocnicy pozostali z zapisu gry.
- Wypożyczenie: gdy oferowana maszyna jest zajęta, sąsiad szuka innej do tej pracy; log pokazuje wybór i powód.

### 1.9.10.1 — 2026-10-10
- Kombajny sąsiadów składają rurę wysypową przed pracą i na postoju – pomocnik nie odmawia już startu („not in transport mode”).

### 1.9.10.0 — 2026-10-10
- Opcja wypożyczenia maszyny pojawia się tylko wtedy, gdy sąsiad naprawdę ma maszynę do tej pracy i stoi ona na swoim miejscu na jego podwórku.

### 1.9.9.9 — 2026-10-10
- Zaparkowane maszyny sąsiadów są zawsze puste – także kombajny z pełnym zbiornikiem ze starszych zapisów (opróżniane przy wczytaniu gry i przy każdym odstawianiu).

### 1.9.9.8 — 2026-10-10
- Pożyczona maszyna ma na mapie własną jasnozieloną ikonę (ciągnik z kluczem) przez cały kontrakt; dopóki jej nie odbierzesz, prowadzi do niej nawigacja.

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
- Po postawieniu, przesunięciu lub usunięciu miejsca maszyny sąsiad przyprowadza, przestawia lub zabiera maszyny dopiero wtedy, gdy zmienia czynność w planie dnia. Maszyny z usuniętych miejsc znikają od razu.

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
- Zapłata za kontrakty według stawki za hektar (wg pracy i uprawy × trudność ekonomiczna).

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

### 1.0.0.0 — 2026-10-13 — official release (ModHub)
First official release. New since 1.9.17.0:
- **Relationship perks** (growing from level 3, full at level 10): mayor Richard Hale – farmland up to 10% cheaper, Frank Weber – repairs and repaints up to 20% cheaper, Monika Zielinska – crops and products sell for up to 5% more
- At level 1 a small penalty (land and repairs +5%, sales -3%), at level 2 half of it; a message shows how much you saved or lost, and the phone contact shows the current perk and the next level
- Selling land back returns the price with the same discount, so buying and selling makes no money
- **56 new longer talks** (8 per neighbour) with 3 to 5 answers each; longer talks are picked more often
- Talk points come from all answers: from -80 (all bad) through 0 to +80 (all good)
- Fix: opening a talk and leaving at once gave +40 relationship points – now only a talk held to the end with at least one answer counts
- Fix: the "chopper wagon" option in the settings can be switched again
- Fix: no more hundreds of "EffectManager:setFillType is deprecated" errors in the log (chaff stream)
- Shop icons saved as DXT5 (no more "BC7 has undefined channel count" warnings)
- Phone wallpapers renamed and the brand logo removed from one of them (ModHub rules)
- Extended mod description
- Quiet log: only problems are written; detailed log with the file `modSettings/FS25_GoodNeighbours/debug.txt`

### 1.9.17.0 — 2026-10-12
- Chaff wagon on a dedicated server: the server sends the emptied trailer's fill with the unload and return messages and the player's game sets it (the game's own sync did not always arrive and the trailer looked full for the player).

### 1.9.16.9 — 2026-10-12
- Neighbours no longer offer by phone (or do themselves) fertilizing, spraying or weeding on a crop that is already ready to harvest – the game keeps such old contracts in its list and they only count where wheels crush the crop. Harvesting is offered only on a ripe field.
- If such a contract fails because the crop became ripe, the neighbour takes no relationship points.

### 1.9.16.8 — 2026-10-12
- The chaff trailer is emptied the game's own way (all fill units at once), then checked; the server log shows the fill, the capacity and what is left.

### 1.9.16.7 — 2026-10-12
- Chaff wagon on a dedicated server: after unloading it comes back empty for the players too (the server sends the fill level and the player's game refreshes the trailer).

### 1.9.16.6 — 2026-10-12
- Phone contracts the game "cannot start right now" (e.g. just after midnight while it updates the fields) are tried again up to 3 times a few seconds apart.
- The message about contracts that did not start gives the reason: the game's contract limit (with its number), not allowed right now, no longer offered, someone else took it, a neighbour works this land.

### 1.9.16.5 — 2026-10-12
- Harvest test (Shift+M): when the game offers no harvest contract on the neighbour's land, he harvests one of his own ripe fields anyway (maize first); after work the field is harvested as with a contract.

### 1.9.16.4 — 2026-10-12
- Fleet editor on a dedicated server: machines from mods can be picked. Before, the player sent the mod path of his own PC (C:/Users/...) and the server, with its mods elsewhere, did not find the machine. Paths now travel as "$moddir$ModName/...", the way the game sends them.
- A machine that just arrived is replaced only a few seconds later – quick clicks in the editor broke Courseplay on the players' PCs (CpCourseManager error in a loop).

### 1.9.16.3 — 2026-10-12
- Chaff wagon: when choosing the side, only the crop being harvested counts as standing. A meadow or another field beside it no longer looks like uncut crop, so the wagon does not drive into the maize at the field edge.

### 1.9.16.2 — 2026-10-12
- The chaff wagon's gap is measured from the unfolded header (its work areas), not the folded one – the tractor no longer drives under the header.

### 1.9.16.1 — 2026-10-12
- The forage harvester's pipe is put into working position and turned to the trailer (after the game's own vehicle update, so the game does not turn it back); the chaff stream is kept on. After work the pipe folds in.

### 1.9.16.0 — 2026-10-12
- The chaff wagon drives on the harvested side: the trailer beside the forage harvester, the tractor ahead beside the header.
- The harvester's pipe turns to the trailer and the chaff stream shows.
- While the wagon is away unloading, the forage harvester stops and waits for it.

### 1.9.15.2 — 2026-10-12
- Shift+G (spawn all machines now) works again in the construction menu – the key is also read directly when the game does not deliver the binding; it works without a tool in hand too.

### 1.9.15.1 — 2026-10-12
- The wagon beside the forage harvester drives next to it on the pipe side, with a gap for the chopper and header width – the tractor and trailer no longer end up inside the machine. The trailer's tarp opens while it takes chaff and closes after work.

### 1.9.15.0 — 2026-10-12
- Fleet editor (Shift+M): new "Silo" row – pick the silo model from the shop (mods too) for each farmer. After a change the old silo goes and the new one is built on his silo place.
- While setting a silo place, a preview of the picked silo shows at the cursor.

### 1.9.14.6 — 2026-10-12
- Harvest: a header is only paired with a machine that has a matching hitch for it (before, a neighbour tried to put a forage maize header on his combine and did not drive out).

### 1.9.14.5 — 2026-10-12
- Shift+Q (place size) and Shift+Del work again in the construction menu – the keys are also read directly when the game does not deliver the binding.

### 1.9.14.4 — 2026-10-12
- "Test: harvest now" button in the fleet editor (Shift+M, admin): the selected neighbour goes out to harvest one of his fields right away (maize first) with the machines set in the editor, also after 22:00. The result shows on screen: drove out / no field ready / no machine for that crop.

### 1.9.14.3 — 2026-10-12
- While placing, the panel shows which of the neighbour's machines will stand there ("Here stands: Krone BiG X 1180 (Other 1)").

### 1.9.14.2 — 2026-10-12
- The fleet editor (Shift+M) always opens: the machine lists are fetched from the server when the construction menu and the editor open (after loading it said "No machines yet – set his places first" although the machines stood there).
- Machines can be chosen before the neighbour has put them out – the choice is used when they come.

### 1.9.14.1 — 2026-10-12
- Neighbours' machines without an owner (the game moved them to the shop after "outside the world", leaving copies without the neighbour's name that nobody could enter) are taken away after 2 minutes – the neighbour has his machines on his places anyway.
- Cause: after loading, a neighbour's tractor was moved together with its hitched implement, which broke the physics. Now everything is uncoupled before moving and the machines go to their places separately.
- A phone contract no longer gets stuck on "PENDING_MISSION": prepared contracts are finished before a new one starts, one still waiting for its machines is named in the log.

### 1.9.14.0 — 2026-10-12
- **Contract material by field size.** The amount comes from the game's data (GIANTS): seeds = the crop's use per m² × hectares, fertilizer / sprays = the spray type's use (litres per second at working speed) converted to a hectare. Reserve: +25 % seeds, +50 % fertilizer, herbicide and lime (spreaders and sprayers use more when driving slower, headlands, overlaps).
- **Delivery during the contract:** every minute the neighbour checks how much is left at his silo and how much the unfinished part of the fields still needs – below about 1/3 he brings the rest ("brought more … for the rest of the field").

### 1.9.13.4 — 2026-10-12
- **Contracts from calls work again after 10:00.** The 10 hour deadline was counted from midnight instead of from now – after 10:00 the game saw the contract as expired and threw it away ("could not start … already taken or limit reached"). Now the deadline is always 10 hours from accepting.

### 1.9.13.3 — 2026-10-12
- A working neighbour no longer holds the land around his field when a field offered in a phone call lies on it – the contract from the call can be taken (before: "already taken or limit reached").
- The log says why a contract did not start (a neighbour works on that land / the game no longer offers it / the game's answer).

### 1.9.13.2 — 2026-10-12
- **Single player:** the neighbours work their fields in single player too. The game makes no second farm in single player (the neighbours' farm 15), so their work was switched off – now their machines and fields work without it, and their helpers cost nothing.

### 1.9.13.1 — 2026-10-12
- Fleet editor: after adding another machine the selection stays on "+ Add another machine" (it jumped to the added machine, so the next "Apply" replaced it instead of adding a new one).

### 1.9.13.0 — 2026-10-12
- **Wagon beside the forage harvester:** while a neighbour chops, his free tractor with a chaff trailer drives beside the chopper under the pipe and takes the chaff. A full trailer drives home, is unloaded and comes back empty after about 45 s (meanwhile the chaff disappears as before). The wagon is moved by the mod, outside the physics – it cannot crash into anything.
- Needed among the neighbour's machines: a free tractor and a trailer that takes chaff (add it in the fleet editor as an "other machine"). Without them the chaff simply disappears.
- New admin setting "Wagon beside the forage harvester" (ESC → Settings → Good Neighbours), on by default.

### 1.9.12.1 — 2026-10-12
- A neighbour's forage harvester works without a trailer beside it: the game's helper no longer waits for a wagon under the pipe, the chaff goes into the harvester's internal buffer, which the mod empties every second (as if a wagon took it). Only the neighbours' machines – players' forage harvesters work as in the game.

### 1.9.12.0 — 2026-10-12
- **New place size: HEADER** (Shift+Q with the neighbour tool) – the combine's header stands on its own wide, short place. In older savegames the header keeps its "vehicle + attachment" place until you set a HEADER place.
- **Fleet editor – other machines:** "+ Add another machine" at the bottom of a neighbour's list; any shop machine (mods too) with a category switch (forage harvesters, potato and beet harvesters, corn headers …), "Remove" takes it away. Each gets its own place (size by the kind of machine).
- **Harvest by crop:** the neighbour picks the machine for the field himself – a self-propelled potato / beet harvester, a combine or forage harvester with a header for that crop (e.g. maize), or a tractor with a trailed harvester. Fields without a fitting machine are not started. The tanks of all these machines are emptied at 60 % and to zero after work.

### 1.9.11.5 — 2026-10-12
- After harvesting the neighbour's combine is emptied to zero, the pipe comes in and it folds; the header is folded, uncoupled and put on its own place ("vehicle + attachment"); the combine stands on its place alone.

### 1.9.11.4 — 2026-10-12
- Fleet editor: all of a neighbour's tractors together at the top ("Tractor 1", "Tractor 2" …), then combine, car, implements and the rest; shorter labels so the machine name fits.

### 1.9.11.3 — 2026-10-12
- The fleet editor really opens again (the window did not tell the game it was closed).
- Shift+M in the construction menu opens the editor without picking a tool; the neighbours on the left, next to it the machines of the chosen one, the main panel to change them.

### 1.9.11.2 — 2026-10-12
- The fleet editor opens again after closing it (Shift+M worked only once); the construction menu keys come back after the window closes.

### 1.9.11.1 — 2026-10-12
- Fleet editor: shop pictures of the machines – the current one, the new one and every machine in the list.

### 1.9.11.0 — 2026-10-12
- **Machine preview while placing:** with a neighbour tool (sizes vehicle / vehicle + attachment / oversize) the model of the machine that will get this place stands at the cursor, in a glowing frame (green – free, red – overlaps another place).
- **Fleet editor (Shift+M, admin)** in the construction menu with a neighbour tool: his machines (tractor, combine, car, implements, extras), the current and the new machine with picture, brand, model, category and price, below the shop machines of the same category (mods too), 8 per page. "Apply" – the old machine goes, the new one stands on its place; "Back to default" – the mod's machine again. Saved in the savegame.
- Mayor, trader and dealer: no place is kept for a tractor they don't have any more – their vehicles get the right places.

### 1.9.10.13 — 2026-10-12
- **Shift+G (admin)** in the construction menu: all neighbours bring, move or take away their machines for the set places at once – no waiting for their next activity. Neighbours at work follow when they are back.
- The key for setting places automatically is gone (the first set-up after loading a new game works as before).

### 1.9.10.12 — 2026-10-10
- Changed contract amounts – the neighbours' new price list (€/ha, times the economic difficulty: easy ×1.2, normal ×1.1, hard ×1.0):
  - plowing 2600, cultivating 2100, harrowing 1700, sowing 1900, fertilizing 1400, liming 1400, spraying 1300, weeding 1400, rolling 1000, stone picking 2000, mulching 1800
  - mowing 2200, tedding 1100, harvest 2700
  - harvesting: potatoes / beets / vegetables / rice 3600–3300, sugarcane 4200, cotton 3500, grapes / olives 3200
  - sowing / planting: potatoes / sugarcane 2600, rice 2300, beets / vegetables 2200

### 1.9.10.11 — 2026-10-10
- Mayor, grain trader and dealer: the neighbour tool now has the same place sizes as the farmers (Shift+Q).

### 1.9.10.10 — 2026-10-10
- Maps from outside the base game: the mod remembers the places (homes, machine places, visit places, fields) on every save in `modSettings/FS25_GoodNeighbours/maps/<map>.xml` and uses them for every new game on that map.
- Presets inside the mod work for any map (`data/maps/<map>.xml`), not only the base maps.

### 1.9.10.9 — 2026-10-10
- The neighbours' combines are really emptied at 60 % (checked every second) – the game refused it before, tanks reached 100 % and the combines stopped.
- No call when the farm already has the most contracts the game allows; never more fields offered than still fit.

### 1.9.10.8 — 2026-10-10
- Neighbour icons in the map menu can be clicked: name, role, relationship level, what he is doing and his photo.
- Lent machines on the map can be clicked – when stuck, "Reset machine" puts them back on the pick-up place (during work pick it up again; on the way back it counts as returned).

### 1.9.10.7 — 2026-10-10
- Neighbours start working right where they appear on the field – no more driving by road to their previous field; combines start again (was "not in transport mode").
- Cancelled or failed contract with a lent machine: the neighbour takes it back at once (empty), -50 relationship points, done – no return trip.

### 1.9.10.6 — 2026-10-10
- A failed or vanished contract always returns the lent machine and takes the material back; savegame contracts that no longer exist are closed a minute after loading.
- Material only once: pallets first, the neighbour's silo only gets what the pallets did not cover; the silo amount is kept in the savegame.
- Pallets that appear after the contracts ended are removed at once.
- While a contract with a neighbour runs he offers no second machine or second delivery.
- An answered call without a reply does not ring again about the same fields.
- Removing a place: only the machine without a place disappears; the others move with the neighbour's next activity.

### 1.9.10.5 — 2026-10-10
- The neighbour puts out as much seed / fertilizer / herbicide / lime as the game uses on the field (game data of the crop and the material, per hectare), plus 25 % – always enough.

### 1.9.10.4 — 2026-10-10
- A lent machine comes empty – load it with the material from the neighbour (pallets next to his silo / his silo). No more automatic filling at the neighbour's yard.

### 1.9.10.3 — 2026-10-10
- Neighbours appear right on their field and start working there – the helper no longer drives along the roads to the field (driving there will come later with AutoDrive support).

### 1.9.10.2 — 2026-10-10
- At 22:00 every helper of the neighbours stops working the fields, whatever it does – also helpers left over from a savegame.
- Borrowing: if the offered machine is busy, the neighbour looks for another one for the job; the log shows the choice and the reason.

### 1.9.10.1 — 2026-10-10
- The neighbours' combines fold their grain pipe before work and when parked – the helper no longer refuses to start (“not in transport mode”).

### 1.9.10.0 — 2026-10-10
- Borrowing a machine is offered only when the neighbour really has one for the job and it stands on its place in his yard.

### 1.9.9.9 — 2026-10-10
- Parked machines of the neighbours are always empty – also combines with a full tank from older savegames (emptied when the game loads and whenever they are parked).

### 1.9.9.8 — 2026-10-10
- A machine lent to you has its own light green map icon (tractor with a key) during the whole contract; until you pick it up, navigation leads to it.

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
- After a machine place is set, moved or removed, the neighbour brings, moves or takes away his machines when he changes his activity. Machines of a removed place go at once.

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
- Contract pay by price per hectare (by work and crop × difficulty).

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
