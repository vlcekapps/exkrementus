# Exkrementus

Zvukova hra v NVGT, ve ktere sbirate exkrementy na mrizce 20x20. Hra je navrzena primarne pro poslech a prostorovou orientaci podle zvuku.

## Obsah repozitare

- `exkrementus.nvgt` - hlavni zdrojovy soubor hry
- `data/audio/` - vsechny zvuky (menu, hra, reputace, konce)
- `build-all.ps1` - automaticky build pro vice platforem
- `builds/` - vystupni balicky (`windows`, `linux`, `mac`, `android`)

## Pozadavky

- Nainstalovane NVGT CLI (`nvgt`) dostupne v `PATH`
- PowerShell (pro spusteni build skriptu)

## Spusteni

### 1) Pouziti hotoveho buildu

Vezmete balicek z `builds/` pro vasi platformu a spustte ho.

### 2) Spusteni ze zdroje

```powershell
nvgt exkrementus.nvgt
```

## Build vsech platforem

Skript postupne sestavi: `windows`, `linux`, `mac`, `android`.

```powershell
.\build-all.ps1
```

Pokud PowerShell blokuje spousteni skriptu (`ExecutionPolicy`), pouzijte:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\build-all.ps1
```

Vystupy vzniknou v `builds/`:

- `exkrementus-windows.zip`
- `exkrementus-linux.zip`
- `exkrementus-mac.zip`
- `exkrementus-android.apk`

## Release checklist

1. Spustit build vsech platforem:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\build-all.ps1
```

2. Overit, ze v `builds/` jsou nove 4 soubory (`windows`, `linux`, `mac`, `android`).
3. Android smoke test:
- nainstalovat novy `builds/exkrementus-android.apk`,
- projit menu gesta (`1f swipe up/down`, `1f double tap`, `3f double tap`),
- spustit novou hru a overit gesta (`1f single tap`, `1f swipe left/right/up/down`, `2f swipe up/down`, `3f single tap`, `3f double tap`),
- pockat aspon 30 s behem hry (spawn/expirace) a overit, ze app nespadne.
4. Pred testem vycistit logy:

```powershell
adb logcat -c
```

5. Pri testu bezet se zaznamem logu:

```powershell
adb logcat -b all -v threadtime > exkrementus_crash_log.txt
```

6. Pokud dojde k padu, ukoncit log (`Ctrl+C`) a ulozit `exkrementus_crash_log.txt` k analyze.

## Jak hra funguje

- Mapa ma velikost `20 x 20`.
- Zacinate na pozici `(0, 0)`.
- Reputace zacina na `100`.
- Exkrement po spawnuti zustava `25 sekund`.
- Sebrani exkrementu: `+10 reputace` (max `100`).
- Sebrani `small`: `+10 vydelku`.
- Sebrani `bigger`: `+15 vydelku`.
- Sebrani `big`: `+20 vydelku`.
- Prosvihnuti exkrementu: `-10 reputace`.
- Hra konci pri reputaci `0`.
- Hra konci, kdyz neni volne misto pro dalsi spawn (mapa je plna).
- Beh muzete kdykoliv rucne ukoncit (`Esc` / dotykove gesto).

Na konci behu se do schranky zkopiruje shrnuti:
- sebrane kusy,
- minule kusy,
- delka hry v minutach,
- celkovy vydelek.

## Tempo spawnovani

Interval se zrychluje podle odehraneho casu:

- start hry: kazdych 20 s
- kazdou odehranou minutu se interval zkrati o 1 s
- minimalni interval je 1 s

## Kompletni ovladani

### Menu - klavesnice

- `Sipka nahoru` - predchozi polozka
- `Sipka dolu` - dalsi polozka
- `Enter` / `Numpad Enter` - potvrdit polozku
- `Esc` - ukoncit hru (prehraje se zaverecne podekovani)

### Menu - Android dotykova gesta

- `1 prst, swipe nahoru` - predchozi polozka
- `1 prst, swipe dolu` - dalsi polozka
- `1 prst, double tap` - potvrdit polozku
- `3 prsty, double tap` - ukoncit hru

### Hra - klavesnice

- `Sipka vlevo` - krok vlevo
- `Sipka vpravo` - krok vpravo
- `Sipka nahoru` - krok nahoru
- `Sipka dolu` - krok dolu
- `R` - oznamit reputaci (po desitkach)
- `E` - prehrat souhrn: sebrano / minul jsi
- `M` - prehrat vydelek (`money` + castka)
- `T` - prehrat odehrane minuty (`minutes` + cislo)
- `K` - prehrat pocet aktivnich exkrementu na mape
- `P` - pauza / pokracovat
- `Esc` - ukoncit aktualni beh a vratit se do menu

### Hra - Android dotykova gesta

- `1 prst, swipe vlevo` - krok vlevo
- `1 prst, swipe vpravo` - krok vpravo
- `1 prst, swipe nahoru` - krok nahoru
- `1 prst, swipe dolu` - krok dolu
- `1 prst, single tap` - pocet aktivnich exkrementu na mape (`K`)
- `2 prsty, swipe nahoru` - reputace (`R`)
- `2 prsty, swipe dolu` - souhrn (`E`)
- `2 prsty, swipe vlevo` - vydelek (`M`)
- `2 prsty, swipe vpravo` - odehrane minuty (`T`)
- `3 prsty, single tap` - pauza / pokracovat (`P`)
- `3 prsty, double tap` - ukoncit beh (`Esc`)

Poznamka: `2 prsty, swipe vlevo/vpravo/nahoru/dolu` a `3 prsty, double tap` jsou rozsirena herni gesta. Pokud je platforma neumi zaregistrovat, hra zustane ovladatelna zakladnimi gesty pro pohyb a pauzu.

## Zvukova orientace

- Kazdy exkrement ma smycku ve 3D prostoru.
- Poloha vuci hraci se promita do panoramy a hlasitosti.
- Vyska tonu pomaha s orientaci v ose `Y`.
- Krok hrace prehraje zvuk kroku.
- Menu polozky i stavy (pauza, pokracovani, konec) maji vlastni hlasove/zvukove stopy.

## Poznamky k chovani

- Funkce nacitani `missed` nacita primo `data/audio/missed.mp3`.
- Behem pauzy se zastavi smycky i odpocet; po pokracovani se interni casovace posunou, takze exkrementy behem pauzy neexpiruji.
- Oznameni poctu pouziva soubory `data/audio/counting/<cislo>.mp3`; pokud cislo neni dostupne, pouzije fallback `cannotcount.mp3`.
- Pocet aktivnich exkrementu na mape (`K` / `1f single tap`) prehraje primo `data/audio/counting/<cislo>.mp3`.
- Android build pouziva `timestamp`-based casovani (`get_now_ms()`) misto `TIME_SYSTEM_RUNNING_MILLISECONDS`, protoze puvodni varianta na Androidu padala v runtime (`system_running_milliseconds()` -> `FORTIFY: fgets: null FILE*`).

## Rychla orientace v menu

- `Nova hra` - spusti novy beh
- `Prehrat vysky exkrementu` - prehraje ukazku: 5x maly, 1 s pauza, 5x vetsi, 1 s pauza, 5x nejvetsi
- `Napoveda` - prehraje napovedu
- `Konec` - okamzite ukonci aplikaci
