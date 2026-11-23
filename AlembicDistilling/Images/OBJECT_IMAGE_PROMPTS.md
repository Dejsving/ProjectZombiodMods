# Описания объектов для генерации изображений

Документ содержит визуальные требования и промпты для будущих иконок/спрайтов мода. Все промпты рассчитаны на последующее уменьшение большого исходного изображения до игрового размера.

## Общие требования к генерации

Для каждого объекта получить исходник минимум `1024x1024`, затем уменьшить вручную или через нейросеть до нужного размера.

Стиль:

- Project Zomboid, изометрическая игра про выживание;
- реалистичный самодельный предмет без фантастики;
- слегка загрязнённый, поношенный металл;
- умеренная детализация, которую видно после уменьшения;
- вид в 3/4 под небольшим углом сверху;
- простой прозрачный фон;
- никаких надписей, букв, цифр, логотипов и водяных знаков;
- один объект в кадре без персонажей и дополнительных предметов;
- для небольших иконок все силуэты должны оставаться различимыми после уменьшения.

Базовый промпт:

```text
isometric game item, handcrafted post-apocalyptic distilling equipment, realistic worn materials, muted colors, aged steel and copper, practical improvised construction, strong readable silhouette, three-quarter top view, centered, isolated on transparent background, no text, no letters, no logo, no watermark
```

Общий негативный промпт:

```text
text, typography, logo, watermark, border, frame, environment, human, zombie, modern polished factory equipment, neon, magical glow, cartoon, excessive ornamentation, tiny unreadable details, multiple objects, perspective distortion
```

## 1. Переносной аламбик

Назначение визуала: компактный набор из обычного кухонного чайника и простых деталей, превращённый в переносной перегонный аппарат.

Состав:

- обычный металлический чайник с ручкой;
- на горлышке или носике закреплена металлическая труба;
- резиновый шланг;
- воронка для загрузки;
- небольшая банка, бутылка или другой сосуд-приёмник;
- корпус допускает использование с печью или костром;
- никаких несъёмных электрических элементов.

Силуэт должен быть узнаваем именно как чайник, а добавленные детали должны читаться как кустарно прикреплённый перегонный аппарат.

Промпт:

```text
isometric game inventory item, improvised portable alembic made from an ordinary worn metal kettle, kettle handle remains visible, short metal pipe attached to the lid, rubber hose, small funnel, compact receiving jar beside the kettle, duct-tape and screw-clamp improvised fittings, small tabletop appliance for campfire cooking, realistic scratched galvanized metal with slight soot, copper-colored small fittings, post-apocalyptic handcrafted equipment, strong readable silhouette, no gauges, no electricity, three-quarter top view, isolated on transparent background
```

Что проверить после уменьшения:

- чайник остаётся главным элементом;
- воронка и труба видны;
- предмет не похож на обычный самовар или кофеварку;
- сосуд-приёмник визуально отделяется от бойлера.

## 2. Самодельный стальной перегонный куб

Назначение визуала: заготовка для переносного или ставящегося на очаг компактного куба объёмом до 1.5 л.

Состав:

- небольшая сваренная стальная ёмкость;
- плотно закрывающаяся крышка;
- выходная трубка;
- простая ножка или кольцо для установки на источник тепла;
- грубые сварочные швы;
- минимальные заводские детали.

На текущем этапе внешний вид можно считать временным. Он должен оставаться проще медного аламбика и не выглядеть как промышленный агрегат.

Промпт:

```text
isometric game item, small improvised steel distillation pot, 1.5 liter capacity, welded cylindrical steel boiler with flat lid, rough welding seams, one bent metal outlet pipe, rubber gasket, simple metal supports, blackened by fire, rugged handmade post-apocalyptic workshop construction, compact enough to place on a stove or campfire, no electric parts, three-quarter top view, isolated on transparent background
```

Временное ограничение дизайна: окончательные детали корпуса, материалы сборки и цвет определятся позже вместе с рецептом.

## 3. Стационарный перегонный куб на металлическом ведре

Назначение визуала: стационарная установка на 10 л с воздушным охлаждением.

Состав:

- металлическое ведро как основной корпус;
- четыре маленьких медных листа;
- две металлические трубы;
- медная или биметаллическая верхняя крышка;
- видимая топка под корпусом;
- воздушные рёбра или открытый змеевик;
- без отдельного ведра с охлаждающей водой;
- установка должна заметно нагревать окружающее пространство, поэтому визуально она связана с печью.

Промпт:

```text
isometric game workstation, stationary 10 liter air-cooled distillation still built from a galvanized metal bucket, lid reinforced with four visible small copper plates, two metal pipes, air-cooling coil with exposed metal fins, short welded stove firebox underneath, fuel door, soot and heat discoloration, rough bolts and weld seams, post-apocalyptic survival workshop equipment, compact industrial improvised still, no water tank, no pump, no electricity, three-quarter top view, isolated on transparent background
```

Особенности силуэта: ведро должно быть больше переносного куба, а топка и воздушный змеевик — две наиболее заметные части.

## 4. Большой бочковой перегонный куб

Назначение визуала: крупный стационарный аппарат поздней стадии на базе металлической бочки.

Состав:

- цельная стальная бочка;
- четыре больших медных листа;
- четыре металлические трубы;
- массивная верхняя крышка или колонна;
- топка в нижней части;
- боковое ведро или бак с водой;
- видимый шланг между аппаратом и ведром охлаждения;
- пароотвод и выход дистиллята;
- более масштабная и сложная конструкция, чем куб на ведре.

Промпт:

```text
isometric game workstation, large late-game stationary distillation still built from a full-size grey steel drum, reinforced by four large copper sheets and four metal pipes, tall vapor column, welded furnace base with fuel door, separate water cooling bucket connected by rubber hose, open water-cooled condenser, collection outlet and receiving pipe, heavy rivets and rough weld seams, soot, patina, heat discoloration, post-apocalyptic industrial salvage build, believable gravity-fed cooling, no pump, no electricity, three-quarter top view, isolated on transparent background
```

Особенности силуэта:

- высота и массивность;
- видимая бочка как основной корпус;
- отдельное ведро охлаждения;
- водяной шланг или трубы не должны сливаться с пароотводом.

## Рекомендуемые результаты генерации

Для каждого объекта лучше получить:

1. основной вид 3/4;
2. вариант с небольшим поворотом для спрайта;
3. крупный исходник для постера;
4. уменьшенную тестовую версию `128x128` для проверки читаемости.

Иконку следует оценивать не по исходнику, а по уменьшенной версии: после масштабирования должны различаться корпус, труба, система охлаждения и топка.
