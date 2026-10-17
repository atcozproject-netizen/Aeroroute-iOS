# Aeroroute – iPhone-test utan TestFlight

**Viktig skillnad:** En Godot Web-export är samma GDScript/2D-spelmotor som nativeprojektet, men körs i Safari via WebAssembly. Den är inte en färdig iOS-app och kan prestera sämre än den slutliga nativeversionen.

## Verifiering (2026-10-17)

- Godot 4.5.1 Linux ARM64 körde native-källprojektet med `--headless --editor --quit` och med `--headless --quit-after 35`.
- Godot 4.5.1 exporterade projektet som **Web → `build/index.html`** med officiella `web_nothreads_release.zip`-mallen.
- Exportfiler: `index.html`, `index.js`, `index.wasm` (~38 MB), `index.pck` (~433 KB), PNG och ljud-worklets.
- Exporten utfördes i en temporär, extern molnmiljö. Den är inte automatiskt uppladdad eller publicerad av detta lokala ZIP-projekt.
- Faktisk iPhone/Safari-speltestning återstår. En publicerad HTTPS-adress kräver vald hosting och åtkomstinställning.

## Exportera på vanlig dator eller Linux-byggtjänst

1. Installera Godot 4.5.1 och officiella exportmallar (4.5.1.stable), med `web_nothreads_release.zip`.
2. Öppna mappen med `project.godot`, välj Project → Export → Web.
3. Exportera till `build/index.html`.
4. Servera hela **build/** över HTTPS med Content-Type `application/wasm` för `.wasm`, `application/javascript` för `.js`, och `application/octet-stream` för `.pck`.
5. Öppna på iPhone Safari, testa ruttdragning, flygplansanimationer, Safe Area, återuppta spel och ekonomin.

Godot 4.3+ stöder single-threaded webexport som fungerar bättre på iOS än äldre multitrådade exportmallar. Safari kan ändå ha WebGL-problem.

## Automatiserat byggkommando

`python3 tools/build_web.py` laddar ner Godot 4.5.1 för Linux, hämtar enbart Web-exportmallen med HTTP range i stället för hela 1,35 GB stora templatearkivet, och bygger `build/`. Internet krävs och nedladdningar cachelagras lokalt.

Kör aldrig `index.html` separat som `file://`; `.wasm` och `.pck` måste ligga på en riktig webbserver.
