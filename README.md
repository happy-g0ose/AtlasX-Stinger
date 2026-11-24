# AtlasX · Stinger

Vicious Bee killer, переписанный на технологиях AtlasX. Собственный UI без Kavo, AtlasX-полёт с невидимой платформой, мульти-инжекторная совместимость, авто-клам хайва по логике Atlas, сервер-хоппинг и телепорт к шипу Impale.

## Установка
1. Вставить `loader.lua` целиком в инжектор → Execute.
2. Либо `loadstring(game:HttpGet("https://raw.githubusercontent.com/happy-g0ose/AtlasX-Stinger/main/AtlasX-Stinger.lua"))()`.

Адрес в лоадере закодирован (hex + XOR), чтобы не светиться открытым текстом. Это только сокрытие от случайного взгляда: репозиторий публичный, и любой, кто получит лоадер, сможет декодировать ссылку.

Если скрипт уже кэширован и нужно обновиться: `delfile("AtlasX-Stinger-cache.lua")` или `getgenv().ATLASX_CACHE = false` перед запуском.

## Настройки
Файл `atlasx_stinger.json` в воркспейсе инжектора, авто-сохранение при изменении контролов.

- **Tween Speed** — скорость полёта (по умолчанию 50)
- **Server Hop Mode** — Wait Spawn / Instant Hop
- **Auto Claim Hive** + **Preferred Hive Slot** — клам реальных `HiveN` слотов (как в Atlas); приоритет: выбранный слот → 6…1 → 1…6
- **Auto Kill Vicious** — охота на Vicious Bee
- **Rush Thorn** — мгновенный телепорт к `WaitingThorn` (шип Impale)
- **Field Filter**, **Notifications**

## Совместимость
- HTTP: `request` → `http_request` → `httprequest` → `syn.request` → `http.request` → `setfflag HttpEnabled` + `game:HttpGet`
- Файлы: `readfile/writefile/isfile` с in-memory фолбэком
- GUI: `gethui` → CoreGui → PlayerGui
- queue_on_teleport: syn / fluxus / global

Арт (фон и иконка мобильного тумблера) грузится с репо `happy-g0ose/AtlasX-Obsidian`.

## Credits
UI / полёт / логика клама — на базе AtlasX (Chris12089/atlasbss, форк happy_goose).
