# Архитектура Foody

```
foodyios/
├── Foody.xcodeproj/          проект Xcode 16 (synchronized group Foody/ + локальный пакет FoodyCore)
├── project.yml               спецификация XcodeGen — запасной способ пересобрать проект
├── Foody/                    iOS-приложение (SwiftUI + SwiftData, iOS 17+, только iPhone, портрет)
│   ├── FoodyApp.swift        точка входа, ModelContainer, окружение AppSettings
│   ├── Models/               @Model-классы SwiftData: Product, Recipe, SavedMeal, DiaryEntry, TargetPlan (+ RecipeItem)
│   ├── Services/             AppSettings (UserDefaults+Keychain), LabelScanService, DiaryService, DataExport, ImageProcessing
│   └── Views/                экраны: Diary, Library (продукты/приёмы/рецепты), Scan, Stats, Targets, Settings, Components
├── FoodyCore/                Swift-пакет без UI (Foundation only) — компилируется и тестируется на Linux/macOS
│   ├── NutritionFacts        все поля декларации ЕС, арифметика (масштабирование, сложение), производные значения
│   ├── Micronutrient         витамины/минералы Регламента 1169/2011 с NRV
│   ├── RecipeMath            сумма ингредиентов → на 100 г готового блюда → на порцию
│   ├── Targets               DailyTargets, калькулятор Миффлина — Сан Жеора
│   ├── Statistics            StatsEngine: дни периода, цели по дате, итоги/средние, перебор-недобор, разбивка по приёмам
│   └── LabelParsing          инструкция + JSON-схема, клиенты OpenAI (Responses API) и Anthropic (Messages API), каталог моделей
├── tools/label-bench/        бенчмарк моделей: датасет, синтетические этикетки, прогон, скоринг
├── .github/workflows/        ios.yml (сборка + тесты + IPA), label-bench.yml (бенчмарк на раннере с интернетом)
└── docs/                     этот документ, анализ аналогов, анализ моделей, установка
```

## Данные

Все данные — в локальной базе SwiftData (`Foody.store` в контейнере приложения, CloudKit выключен).

- **Product** — значения на 100 г/мл. Полная `NutritionFacts` хранится JSON-ом (`factsData`), а ккал/Б/Ж/У
  продублированы отдельными колонками для быстрых списков. Источник: `manual` или `photo` (+ миниатюра этикетки).
- **DiaryEntry** — запись дневника: день (начало суток), приём пищи, количество и **снимок** значений продукта на
  100 г. Поэтому правка или удаление продукта не меняет историю. Итоги записи денормализованы (kcal/protein/fat/carbs).
- **SavedMeal** — сохранённый приём пищи: список `RecipeItem` (продукт + количество + снимок значений). При
  добавлении в дневник разворачивается в отдельные записи с общим `groupID`.
- **Recipe** — ингредиенты (`RecipeItem`), вес готового блюда, стандартная порция; кэш значений на 100 г.
- **TargetPlan** — дневные цели с датой начала действия. Статистика для каждого дня берёт план, действовавший в
  тот день (`StatsEngine.targets(for:in:)`).

Связей SwiftData между таблицами намеренно нет (только UUID-ссылки и снимки) — это проще, надёжнее и делает
экспорт/импорт тривиальным (`DataExport`: один JSON со всеми таблицами; импорт добавляет отсутствующие записи по id).

## Распознавание этикетки

1. `CameraPicker` (UIImagePickerController) или `PhotosPicker` → `UIImage`.
2. `ImageProcessing.prepareForUpload` — поворот по EXIF, уменьшение до 1600 px, JPEG 0,88.
3. `LabelParserFactory.make(config)` → `OpenAILabelParser` или `AnthropicLabelParser` (FoodyCore).
   Оба отправляют одну и ту же инструкцию `LabelParseSpec.instruction` и требуют ответ по схеме
   `LabelParseSpec.schemaJSON` (structured outputs). Ответ декодируется в `LabelParseResult` → `NutritionFacts`.
4. `ProductDraft` заполняет `ProductFormView`; сверху показывается подсказка модели (уверенность, пересчёт из
   порции, заметки). Пользователь проверяет и сохраняет.

Тексты инструкции/схемы генерируются из `tools/label-bench/prompt.txt` и `schema.json`, чтобы бенчмарк и
приложение всегда использовали одно и то же.

## Статистика

`StatsView` для выбранного периода берёт записи диапазона (`DiaryService.entries`) и все планы целей, превращает
записи в `EntrySummary` и вызывает `StatsEngine.compute`. Результат `PeriodStats` содержит итоги по дням, сумму и
средние за учтённые дни (дни с записями), сумму целей за эти дни, дельты/бейджи перебора и недобора (допуск ±5 %),
разбивку по приёмам пищи. Логика полностью в FoodyCore и покрыта тестами (`StatisticsTests`).

## Сборка и проверка

- `swift test --package-path FoodyCore` — тесты ядра (Linux или macOS).
- `xcodebuild -project Foody.xcodeproj -scheme Foody -destination 'generic/platform=iOS Simulator' build` — сборка.
- Workflow `ios.yml` делает то же на macOS-раннере и выкладывает неподписанный IPA артефактом.

## Как расширять

- Новый поставщик модели: реализовать `LabelParsing` в FoodyCore и добавить кейс в `LLMProvider`/`LabelParserFactory`.
- Новое поле декларации: добавить в `NutritionFacts` (+ `scaled`, `+`, `rounded`), в схему/инструкцию бенчмарка и в
  `LabelParseResult`, затем строку в `ProductFormView`/`ProductDetailView`.
- Штрихкоды: `Product.barcode` уже есть; достаточно добавить сканер (AVFoundation/VisionKit) и запрос к Open Food Facts.
