# Saldo — project guide

Kirigami app (QML + C++20/Qt6, CMake+ECM) and Plasma 6 widget that show personal finances from
**Open Finance Brasil** through the **Meu Pluggy personal-use API**: bank balances, credit card
limits, bills, investments and transactions. Brazilian banks only. Desktop (KDE Plasma) first; the
app (not the widget) also targets Android.

- Repo: [https://github.com/hernique33comiitei/saldo](https://github.com/hernique33comiitei/saldo) (push over SSH, personal account only)
- App-id: `io.github.hernique33comiitei.Saldo` · binary / icon / gettext-domain: `saldo`
- Plasma widget id: `io.github.hernique33comiitei.saldo` · QML modules: `org.saldo` (app), `org.saldo.core` (shared core)

## Conventions (must follow)

- **Code, comments, CLAUDE.md, the release skill and commit messages are English only.** The UI
  is localized via KI18n: source strings in English, Portuguese **only** in `po/pt_BR.po`
  (compiled to `saldo.mo` by CMake). The exception is what faces users on GitHub: `README.md`,
  the repository description and the README screenshots are in **Brazilian Portuguese**, because
  the app only works with Brazilian banks (Open Finance Brasil), so that is its audience.
  Changelogs (spec, debian, metainfo, release notes) stay English.
  - App QML (`src/app/`) uses `i18n()`. QML that also runs inside plasmashell (`src/core/qml/`,
    `plasmoid/`) uses `i18nd("saldo", …)`, because plasmashell has another default domain.
  - C++ in `src/core/` builds with `TRANSLATION_DOMAIN="saldo"` for the same reason.
  - The app language can be overridden in Settings (`Config.language`: "", "en", "pt_BR").
    `main.cpp` applies it with `KLocalizedString::setLanguages` before the first `i18n()` (it
    spots `--demo` first, so the demo reads its own config), and `useFrameworkCatalogs()`
    (`frameworkcatalogs.cpp`) swaps the Qt catalogs KDE Frameworks and Qt load for the *system*
    language (Kirigami's “Search…”/“Open drawer”, the style's menus) for the app's, including
    those of libraries QML loads later. Dialog buttons get our own `i18n` texts
    (`standardButton(…).text` in `onAboutToShow`): Qt's come from the platform in the system
    language. The widget always follows the system language: `setLanguages` inside plasmashell
    would change every applet.
- Git pushes go over SSH with the personal key. Author: Henrique Oliveira
  <henriik.dev@gmail.com> (already set in this repo's `git config`).
- **No Claude attribution** in commits or PRs (no `Co-Authored-By`, no "Generated with…").
- **The app installs nothing.** Its only external tool is `secret-tool` (libsecret), a warn-only
  check (`Credentials.keyringAvailable` → banner). Runtime QML modules are declared in packaging;
  `install.sh` installs the dev dependencies.
- **Secrets only in the keyring**: Client ID + Secret via `secret-tool` on desktop, QtKeychain
  (Android Keystore) on Android. The Pluggy API key lives in memory only. Never write any of
  them to files, settings or logs.
- **No daemon, no D-Bus.** Pluggy data changes once a day, so the app and the widget each run
  the core in-process and poll on a timer; a lock file serializes syncs and a stamp file tells
  the other process to reload. Only add a daemon if a feature truly needs persistent background
  work.
- **Paths always through `Paths::`** (explicit files shared by the app and plasmashell). Never
  `AppDataLocation`/`AppConfigLocation` on desktop: inside the widget they would point at
  plasmashell's directories.
- **Optional SQL filters:** a null `QString` binds as SQL `NULL`, and `NULL = ''` is never true,
  so `WHERE (? = '' OR col = ?)` returns nothing when the filter is unset (the raw data page came
  out empty that way). Write `COALESCE(?, '') = ''`.
- **Numbers, dates and names:** numbers (money in any currency, `Money.percent`,
  `Money.number`; never `toLocaleString(Qt.locale())` in QML) and numeric dates are always
  Brazilian (`dd/MM/yyyy`, like the money), and month/day names and Pluggy's category names
  follow the app's language (`MoneyFormat::uiLocale()`, from `KLocalizedString::languages()`).
  Never `QLocale::system()`: a phone set to English (US) showed `11/30/26`, "November de 2026"
  and English categories with the app in Portuguese.
- **Money sign:** negative = money going out, everywhere. Only `PluggyParser::normalizedAmount`
  knows that Pluggy reports card movements with the opposite sign; never flip amounts elsewhere.
- **Internal movements** (money moving between the user's own accounts) are neither income nor
  expense. `Database::detectInternalTransfers()` sets `transactions.internal` after every sync:
  Pluggy's "Same person transfer"/"Credit card payment" categories, PIX/TED to the user's own
  CPF/CNPJ (`counterparty_document` ∈ accounts' `tax_number`), equal out/in pairs between
  connected bank accounts within 3 days (transfer categories on both sides, so coincidences
  like a taxi and its reimbursement stay counted), and bank → card bill payments within
  −2…+7 days (the card side often says "Shopping"). Manual overrides (`transaction_overrides`,
  set from the transaction dialog) win. Every aggregate uses `Database::countedSql()`,
  `incomeSql()` and `expenseSql()` (aliases `t`/`a`): income only from bank accounts, money into
  a card that isn't a payment is a refund and lowers expenses. Verified against real data: without
  these rules income and expenses came out inflated by the internal movements.
- **Card bill ≠ limit used.** A card account's `balance` is the whole debt (future installments
  included) and its `creditData` close/due dates are those of the **last closed** bill. The open
  bill is not a `/bills` object yet: it is the card transactions with no `billId` (all PENDING,
  installments keep the original purchase date). `computeCardBill()` (`cardbills.cpp`) is the only
  place that knows this: open bill, last closed bill, what is still to pay on it while not due
  (money into the card since it closed), and "Next bill(s)" = open + closed-not-due, summed by
  `FinanceSummary.nextBills`. An overdue bill with no payment found is flagged, never added to
  "Next bills" (Pluggy may not list the payment). Verified against real data: the open bills
  summed to about half of the limit used.
- **Balance history comes from daily snapshots** (`balance_snapshots`, written by every sync).
  Never rebuild it from transactions: some banks move money (automatic savings) without
  transactions and the rebuilt history went below zero. `transaction_overrides` and
  `balance_snapshots` are user data: kept when the cache schema changes or is cleared.
- **Charts and model totals:** `RowListModel` emits `summaryChanged` (the NOTIFY of every total
  such as `maxValue`) *before* swapping rows. KQuickCharts keeps the range it had when data
  arrived, so the old order drew every bar at full height. Charts set an explicit round range
  from `chartscale.js` (value axis labels and grid lines must match the bars/line); that is safe
  only because of that signal order. Axis labels use `Money.axisLabel(value, step)` (unit and
  decimals follow the step). KQuickCharts' `AxisLabels` spreads labels edge to edge, so month
  labels under bars are a `Row` of equal-width centered labels instead. X labels always sit
  centered under their data, never glued to the corners, while the data still spans the whole
  width: in the balance chart the first/last days sit half a date label (plus `largeSpacing`)
  from the edges and the line continues flat from there to the edges. The continuation's line is
  antialiased (same sub-pixel height as `LineChart`), its fill is not, and x positions are whole
  pixels; otherwise a step or a darker column shows at the junction.
- **Color theme** (Settings → Appearance → Theme, `Config.theme`: "", "light", "dark";
  `src/app/colorscheme.cpp`, every platform, the app only; `--theme` overrides it for one run):
  Light/Dark activate Breeze Light/Dark with `KColorSchemeManager` (the KColorScheme library
  carries both schemes, so no Plasma files are needed), and Kirigami's theme follows the active
  scheme, icons included. "" (System) is: on Plasma (`XDG_CURRENT_DESKTOP` has KDE), Plasma's own
  scheme, untouched and followed live by KDE's platform theme, so `KColorSchemeManager` is not
  even created then (when created outside KDE's platform theme it picks a Breeze scheme by
  itself); elsewhere (GNOME, Android) Breeze Light or Dark from `QStyleHints::colorScheme`.
  Off Plasma the choice also goes to `QStyleHints::setColorScheme` (Android's bar icons, window
  decorations), but Light/Dark never depend on it: not every platform theme honors the request.
  The widget follows Plasma. Check with `--demo --theme …` and `XDG_CURRENT_DESKTOP=KDE` (with a
  `kdeglobals`) or `GNOME` (without), and on the phone with `tools/phone-test.sh matrix`.
- **Overview month:** the select at the top of the overview (the month chips on phones) drives
  everything there that depends on a month: `CategorySpendModel.month` and `CashflowModel.endMonth`
  (the chart's last pair of bars and the "in the month" totals). Stat cards, limit and balance
  history are not per month. Both keep the picked month when a sync rebuilds the list.
- **Cache schema changes:** bump `SchemaVersion` *and* list the new column in `SentinelColumns`
  (`database.cpp`). `ensureSchema()` runs under `BEGIN IMMEDIATE` and rebuilds the cache when the
  version differs or a sentinel column is missing; a DB with a newer version is never touched.
  Why: on the 2026-11-22 upgrade an old plasmashell recreated v1 tables while the app stamped
  version 2, every transaction insert failed, and the app showed zero income/expenses. Failed
  cache writes now surface as sync errors. After installing a schema change, restart plasmashell
  (`./install.sh --restart-plasma`).
- **One Meu Pluggy item per bank.** The authorization page ("Selecione a conta") shares a single
  bank, so each bank is its own item (max 5), and Pluggy names every one "MeuPluggy". Always show
  a connection through `Config::displayItemName()` (user-given name → connector name → "Meu Pluggy ·
  <id start>"), never the raw `connector_name`.
- **Pluggy dashboard labels** (Portuguese UI) are quoted verbatim inside English strings, e.g.
  `“Itens Conectados”`, with an `i18nc` context telling translators to keep them as is.
  Keep the setup guide (`SetupPage.qml`) in sync with the dashboard if Pluggy renames things.
- **UI vocabulary**: Kirigami pages/actions/FormLayout, colors from `Kirigami.Theme`, sizes from
  `Kirigami.Units`, Breeze icon names (prefer `-symbolic` in lists; no bundled images besides
  the app icon). Widget-only controls come from `org.kde.plasma.components`. The one exception
  to theme colors is the phone overview's `BalanceHero`: the app icon's green (`UI.Tokens.brandStart`/
  `brandEnd`), darkened so its white text keeps a 4.5:1 contrast (the icon's own `#1b9e6b` gave 3.4:1).
- **Cards:** use `UI.Card`/`StatCard` (see Design system; `UI.Card` is borderless and tonal on phones). `Kirigami.AbstractCard` stretches its `contentItem` to
  the whole card minus padding (the header is not subtracted), so a layout used directly as
  `contentItem` spreads its nested layouts and pushes the last rows past the card's edge.
  `UI.Card` keeps its column at its own height inside a wrapper `Item`; do the same for any
  other `AbstractCard`. Detail and settings pages use cards with "label … value" rows, not a
  centered `FormLayout` next to full-width content. Settings: two columns of `UI.Card`s on
  wide windows (one on narrow ones), a `SettingRow` per option (name + description left,
  control right), field labels above the fields.
- **Spacing:** page margins (Kirigami's default `Page` padding), card padding and gaps between
  cards are all `Kirigami.Units.gridUnit`; rows inside a card `largeSpacing`; a label and its
  value `smallSpacing`. `AbstractCard`'s own default padding (`largeSpacing`) is too tight, so
  `UI.Card`/`StatCard` set `gridUnit`. A card's header height comes from its title only
  (header buttons overhang it), so titles of cards side by side line up.
- **Narrow windows** (the window minimum is 20 grid units, ~360 px; Android is narrow too): in Qt
  layouts an item with `Layout.fillWidth: false` (buttons, amounts, a donut) keeps its implicit
  width, so a row of them that does not fit pushes the card, and everything in it, past the
  window's edge. Rows like that go side by side only when they fit and stack otherwise, decided
  from the card's/page's width (never from the content's own implicit width, which would feed
  back), or use a `Flow`; labels take `fillWidth` and wrap or elide; long IDs use
  `Text.WrapAnywhere`; no fixed `Layout.minimumWidth` on fields. Check every page at 365 px.
- **Phones** (`Kirigami.Settings.isMobile`: Android; the desktop never changes with these): the
  five sections are tabs at the bottom (`UI.TabBar` in `Main.qml`, labels of about 8
  characters, `@title:tab` contexts: "Resumo", "Extrato", "Investir"), and the drawer keeps only
  the setup guide, Settings and About. The tab bar is the window's footer on phones only: on the
  desktop there is no footer at all, because Kirigami shortens the sidebar drawer by the footer's
  height even when the footer is hidden (it ended 120 px above the bottom). Page actions stay in the header
  (`pageStack.globalToolBar.style: ToolBar`; Kirigami's mobile default stacks a toolbar of
  their own on the tabs), icon-only there (`displayHint: IconOnly`). The five main pages are `RefreshablePage` (pull-to-refresh runs
  `SyncManager.sync()`). No keyboard shortcuts on phones (`shortcut: Kirigami.Settings.isMobile
  ? "" : …`): the header's overflow menu drew "Ctrl+H" over the item's text. Check phones with `QT_QUICK_CONTROLS_MOBILE=1
  QT_QUICK_CONTROLS_STYLE=org.kde.breeze QT_QPA_PLATFORMTHEME=none` at 360 px, then on the phone (adb).
  - **Phone look** (current Android apps): one surface color everywhere, Kirigami's View colors
    (every page sets them on phones, and the header, `UI.TabBar` and the drawer use them too:
    list pages took View and the others Window, two greys side by side). The header is flat (no
    separator, a bit taller) and pages use `UI.PageTitle` (large, bold) as their `titleDelegate`.
    `UI.TabBar` replaces `Kirigami.NavigationTabBar` (a framed button for the current tab) with
    a pill behind the icon, and pads itself by `SafeArea` like Kirigami's own bars. The drawer is
    wider and rounded, with `PhoneDrawerContent` (app, last update, what is connected, then
    `UI.DrawerItem` pills) instead of Kirigami's action list. Cards are `UI.Card` (borderless, tonal
    on phones), icons in rows and tiles sit in a `UI.IconBadge`, filters are `UI.Chip`s, list
    sections use `UI.SectionHeader`, and the setup guide's steps (`SetupStep`, a template `T.Control` so the
    desktop keeps the bare rail) become cards, the open one tinted. The overview is its own page (`PhoneOverviewPage`, picked in
    `showPage()`); the list pages (transactions, accounts, cards, investments) stay one page with
    phone delegates/headers inside, since some are also pushed (an account's transactions).
  - **The desktop must stay pixel-identical**: phone-only values go in `Component.onCompleted`
    under `isMobile` (paddings, the drawer's width and background, the header's colors), never as
    `phone ? x : undefined` bindings — `undefined` resets to Qt's base value, not the KDE style's
    (rows and headers grew on the desktop that way). Compare desktop screenshots of every page
    before and after (`magick compare -metric AE` must print 0).
- **About page** is ours (`pages/AboutPage.qml`), not `Kirigami.AboutPage`: that one always draws
  initials avatars for authors and opens the license in a sheet glued to the top. Ours has no
  avatars and no "Libraries in use" card, and shows the license in a centered `Kirigami.Dialog`
  (`maximumWidth` set, or the unwrapped text stretches it to the window).
- Card rows (list, widget) show only the card and its limit; bills live on the detail page and
  in the overview's "Next bills".

## Design system (`org.saldo.ui`)

The UI is built from our own design system, organized like a web `@company/ui` package:
`src/app/ui/` is the static QML module `org.saldo.ui` (linked into the app, `Q_IMPORT_QML_PLUGIN`
in `main.cpp`), imported as `import org.saldo.ui as UI`.

- **Tokens** (`UI.Tokens`, singleton): every radius, tint amount, type scale step, size and the
  brand greens, by role (`radiusCard`, `tintSurface`, `fontMoneyLarge`, `chipHeight`…), plus
  `UI.Tokens.tint(background, color, amount)`. Spacing stays `Kirigami.Units`, colors come from
  `Kirigami.Theme` tinted by token amounts. No literal tints, radii or hex colors outside the module.
- **`UI.Platform.isPhone`**: the one place that decides phone vs. desktop.
- **Components** are adaptive: one component per control, the KDE control untouched on the desktop
  (its code is what the pages used before, so the desktop stays pixel-identical) and the design
  system's look on phones, applied in `Component.onCompleted` (never `? : undefined` bindings).
  Layout: `Card`, `SummaryHeader`, `SectionHeader`, `PageTitle`, `IconBadge`, `Chip`, `TabBar`,
  `DrawerItem`. Controls: `Button` (`variant`: Secondary/Primary/Flat), `IconButton`, `TextField`
  (`error`), `PasswordField`, `SearchField`, `TextArea`, `Select` (options in a bottom sheet on
  phones), `NumberField`, `Switch`, `BusyIndicator`. Feedback: `Banner`, `EmptyState`. Overlays:
  `Sheet` and `ConfirmSheet` (Kirigami's dialogs; bottom sheets on phones through `SheetStyle`:
  margins cleared, since Breeze's gridUnit margin made Qt shrink a sheet at the bottom edge and
  cut its content; the footer, outside a dialog's padding, takes the gesture bar's room; drag
  down on a strip over the top to close, using the distance kept while dragging, since the handler
  resets its translation before reporting the release; the dialog's own footer buttons get the
  `Button` pill look through `PillBackground`/`PillContent`, text only: accept Primary, reject
  Flat). `Select` keeps its control's delegate (replacing it reset the current index) and sets its
  sheet's close policy after installing it (the ComboBox gives a new popup "close on a press
  outside its parent", and the parent is the whole window). Sheets (and `Select`'s) sit on `UI.Platform.keyboardTop(window)`: on
  top of the on-screen keyboard while it shows, so a field in a sheet stays visible (Qt reports
  the keyboard in physical pixels on Android, scaled by the ratio of its width to the window's),
  and the gesture bar's room is dropped then (the keyboard covers it). `Banner` keeps its icon centered on
  wrapped text (Kirigami pins it to the top). Phone-only parts are created on an item
  (a Popup is no item: visual objects created on one warn they are not in the scene). App compositions that know the data (`BalanceHero`, `PhoneDrawerContent`,
  `PhoneCardRow`, `SetupStep`) stay in `src/app/components/` and are built from `UI.*`.
- **Catalog** (the Storybook): `pages/GalleryPage.qml`, `saldo --demo --page gallery` (phone:
  `tools/phone-test.sh run --demo --page gallery`). Every component, in its states; a new
  component goes there first. Its texts are samples, not translated.
- **Rule:** pages and app components use `UI.*`, never the controls the design system wraps
  (`QQC2.Button/TextField/ComboBox/Switch/SpinBox…`, `Kirigami.Dialog/InlineMessage/
  PlaceholderMessage/AbstractCard/…`) nor literal looks. `tools/check-ui.sh` lists what still
  bypasses it (ctest `check-ui`; report-only until every page is migrated, then `--strict`).
- **Checking a change:** desktop screenshots of every page (light/dark, wide/narrow) against the
  previous commit must be identical (`magick compare -metric AE` = 0); phone screenshots of the
  touched pages and of the gallery, in the desktop's phone mode first, then on the phone (adb).

## Commits

- **Format:** `<type>: <summary>` — type lowercase, summary in the imperative mood
  ("add", "fix", "drop", not "added"/"fixes"), English, concise (aim ≤ 72 chars),
  no trailing period.
- **Types used here:** `feat` (user-facing feature), `fix` (bug fix), `ui`
  (QML/layout/visual), `widget` (Plasma widget), `docs`, `i18n` (translations), `test`,
  `ci` (workflows), `packaging` (spec / debian / metainfo / desktop / android), `refactor`,
  `chore` (cleanup, deps, misc).
- **Body (optional):** after a blank line, explain the *why* for anything non-obvious.
  Wrap at ~72 cols.
- **Never** add Claude attribution (`Co-Authored-By`, "Generated with…") — see above.
- One logical change per commit; don't mix unrelated areas.

Examples:

```
feat: show the minimum payment on the card detail page
widget: hide the balance label inside the system tray
i18n: translate the new sync error messages
```

## Build / run / test

- Build + install to `~/.local`: `./install.sh` (installs the missing deps of the spec with `dnf`,
  builds, installs, and writes `~/.config/plasma-workspace/env/saldo.sh` so plasmashell finds the
  QML plugin). `./install.sh --restart-plasma` also reloads the panel; `--deps-only` only installs
  the deps (a new developer's setup). `./uninstall.sh [--purge]` reverts it.
- **Dependencies live in the packaging files only:** `packaging/fedora/saldo.spec`
  (`BuildRequires`, `Requires`) and `debian/control` (`Build-Depends`, `Depends`). CI installs from
  them (`dnf builddep`, `mk-build-deps`), `install.sh` reads the spec, the README points to `dnf
  builddep` / `apt build-dep .`, and CMake's `feature_summary` names whatever is missing. A new
  dependency goes into both files (and `find_package` in CMake), nowhere else. On Android, Craft
  builds what the blueprint (`craft/saldo/saldo.py`) lists.
- Dev build + tests:
  `cmake -B build -G Ninja -DBUILD_TESTING=ON && cmake --build build && QT_QPA_PLATFORM=offscreen ctest --test-dir build --output-on-failure`
- Demo data (no account needed): `build/bin/saldo --demo [--page overview|accounts|cards|transactions|investments|settings|setup|about]`.
  The demo uses its own files (`demo.sqlite`, `saldo-demorc`) and never touches the keyring.
- Smoke test: `QT_FORCE_STDERR_LOGGING=1 QT_QPA_PLATFORM=offscreen timeout 5 build/bin/saldo --demo`
  must print no QML warnings. The only expected line is Kirigami's own
  "Created graphical object was not placed in the graphics scene" (from `PageRow.qml`).
- Qt logs go to journald when stderr is not a terminal; set `QT_FORCE_STDERR_LOGGING=1`.
- Screenshots: `SALDO_SCREENSHOT=out.png SALDO_SCREENSHOT_SIZE=1100x820 QT_QUICK_BACKEND=rhi QT_QPA_PLATFORM=offscreen build/bin/saldo --demo --page cards`.
  Without `QT_QUICK_BACKEND=rhi` the offscreen software renderer draws no KQuickCharts charts.
  AppStream/README screenshots live in `data/screenshots/`: Brazilian Portuguese (`LANGUAGE=pt_BR
  LC_ALL=pt_BR.UTF-8`, run from a `cmake --install` prefix listed in `XDG_DATA_DIRS` so `saldo.mo`
  is found), the dark Breeze colors (a scratch `XDG_CONFIG_HOME` holding only a copy of
  `kdeglobals` + `plasmarc`) and a fresh demo cache. The widget shot is `FullRepresentation.qml`
  loaded in a plain `Window` whose id is `root` (with `expanded`, `showInvestments`,
  `needsAttention`), grabbed with `QQuickWindow::grabWindow()`.
- Widget without touching the session: `cmake --install` into a temp prefix, then run
  `plasmawindowed io.github.hernique33comiitei.saldo` with `QML_IMPORT_PATH=<prefix>/lib64/qml`,
  `XDG_DATA_DIRS=<prefix>/share:/usr/share`, `SALDO_DEMO=1`, offscreen; write the log to a file
  and grep it (load errors appear as `kf.plasma.quick: error when loading applet`).
- **Phone tests (adb): the standard check for anything that runs on Android.** The desktop's
  mobile mode (`QT_QUICK_CONTROLS_MOBILE=1`, see Phones) is only a first look: Android-only
  behavior (Qt's Android theme fonts, the system bars, libintl-lite's plurals) shows on the device
  alone, and 0.0.7/0.0.8 shipped font bugs no desktop check could see.
  - One-time setup: `sudo dnf install android-tools`; on the phone, Developer options → USB
    debugging (Xiaomi/MIUI also needs "Install via USB", which asks for a Mi account, and
    "USB debugging (Security settings)"; MIUI also asks on the screen to confirm each install);
    connect it, accept the prompt; `adb devices` lists it as `device`.
  - Build the test app: `tools/build-apk.sh --docker --dev` →
    `dist/saldo-<ver>-arm64-v8a-dev.apk`, "Saldo (dev)", id
    `io.github.hernique33comiitei.saldo.dev` (`SALDO_APK_DEV=1` in `android/build.gradle`). It
    installs next to the real app and never touches it or its data, and it is already signed
    with a dev key kept in the Craft cache (no password, the next dev build updates it). Anyone
    can test this way; the release key only signs releases (GitHub Actions). It is debuggable:
    Qt only passes an adb start's `applicationArguments` (`--demo`, `--page`, `--theme`) to
    debuggable apps (a release build silently ignores them), and `adb shell run-as` reaches its
    files (`lang` writes the demo config; `qt-reserved-files/android-style/` holds the theme
    copies).
  - `tools/phone-test.sh install` → `smoke` (demo run, no QML warnings in the app's log) →
    `matrix` (overview and transactions with demo data, in Portuguese, for phone light/dark × app
    system/light/dark, in `dist/phone-shots/`): look at every shot; the six of a page differ in
    colors only, never in text sizes or layout. `smoke` only flags warnings from Qt and the app
    (logcat tags `default`, `qml`, `saldo`, `kf.*`, `qt.*`), minus Kirigami's expected PageRow line. For anything else: `run --demo --page <p>
    [--theme system|light|dark]`, then `shot <png>` (scroll with `adb shell input swipe`);
    `night yes|no|auto` sets the phone's dark mode; `lang pt_BR|en|system` the demo runs'
    language; `log` prints the app's messages. `--theme` (Android only) applies to that run and
    leaves Settings alone.
  - The phone must be unlocked (a PIN lock cannot be passed): the script wakes it, stops with a
    message when it is locked (instead of black screenshots), and `matrix` keeps the screen on
    while it runs (`svc power stayon usb`), restoring the setting and the dark mode afterwards.
  - Shots use `--demo` (made-up numbers): the real data never goes into files.
- Translations: `po/Messages.sh` regenerates `po/saldo.pot` and merges into `po/pt_BR.po`;
  translate the new entries and check with `msgfmt --check --statistics -o /dev/null po/pt_BR.po`.

## Layout

- `src/core/` — shared library `saldocore` + QML module `org.saldo.core` (plugin
  `libsaldocoreplugin.so`), used by the app and the widget. Exposed with `QML_ELEMENT` /
  `QML_SINGLETON`:
  `PluggyClient` (HTTP, auth, paging, retries), `PluggyParser` (JSON → records, sign convention),
  `Database` (SQLite cache, per-thread connections, change stamp), `SyncManager` (sync flow,
  timer, lock), `Credentials` + `SecretStore` (keyring), `Config` (QSettings, file-watched),
  `FinanceSummary` + `CardTotals` + `computeCardBill` (`cardbills.cpp`) (headline numbers, card
  bills), `Money` (formatting), `Categories`, `Paths` (every file location), `Launcher`
  (widget → app), `DemoData`, `logging` (category `saldo`), `models/` (`QAbstractListModel`s on
  `RowListModel`).
  `src/core/qml/` — components shared with the widget (`MoneyLabel`, `LimitBar`, charts, rows) and
  `chartscale.js` (round value axes).
- `src/app/` — Kirigami app: `main.cpp`, `Main.qml`, `pages/`, `components/`, QML module `org.saldo`;
  `src/app/ui/` — the design system, QML module `org.saldo.ui` (see Design system).
  `SetupPage` is the step-by-step Meu Pluggy guide; it opens by itself on first run (no
  credentials/items) and from the drawer, Settings and the widget (`Launcher.openApp("setup")`).
  Step progress that can't be inferred lives in `Config.setupStep`.
- `plasmoid/` — Plasma widget package (QML only; imports `org.saldo.core`).
- `tests/` — `coretest` (parser, cache, totals) and `pluggyclienttest` (client vs. a fake Pluggy).
- `data/` — `.desktop` template, AppStream metainfo, `icons/`, `screenshots/`.
- `packaging/fedora/` — `.spec`. `debian/` — deb packaging. `po/` — translations.
- `android/` — APK manifest, `build.gradle` and adaptive icon (used by `ecm_add_android_apk`).
  `craft/saldo/` + `.craft.ini` — KDE Craft blueprint and overrides for the Android build.
- `tools/bump-version.sh` — version sync (see Releases). `tools/phone-test.sh` — tests on the
  phone over adb (see Build / run / test).

## Meu Pluggy facts the code relies on

- `POST /auth {clientId, clientSecret}` → `apiKey`, valid 2 h (renewed at 110 min, and once on 401).
  HTTP 429 → wait `Retry-After`. All calls send `X-API-KEY`.
- Item listing is not available for Meu Pluggy (`GET /v2/items` → 403): the user pastes item IDs
  (max 5). Authorizations last one year (`consentExpiresAt`, warned 30 days ahead); renewing may
  change the item ID.
- Pluggy refreshes Meu Pluggy items daily and they cannot be forced (`PATCH /items` does not
  apply), so "Refresh" only re-reads Pluggy. Unchanged `lastUpdatedAt` → the item is skipped.
- Endpoints: `GET /items/{id}`, `GET /accounts?itemId` (paged, 500/page),
  `GET /v2/transactions?accountId&dateFrom` (cursor `next`; the page-based `/transactions`
  retires on 2026-12-31), `GET /bills?accountId`, `GET /investments?itemId`, `GET /categories`.
  Bills and investments are optional: errors there are logged, not shown.
- Incremental sync re-fetches the last 7 days of each account and replaces that window
  (`Database::replaceTransactions`), dropping pending movements that vanished upstream.
- **Confirmed with real data:** amounts are in reais (not cents); bank movements come signed
  (DEBIT negative), card purchases come positive (hence `normalizedAmount`); a card account's
  `balance` is the whole debt. *Settings → Raw Data…* shows the raw account JSON for checking.

## Releases (GitHub Actions → GitHub Releases)

Distribution is RPM (Fedora) + DEB (Ubuntu/Debian) + APK (Android, arm64-v8a), built by
`.github/workflows/release.yml`. Every release must carry all three: the build jobs only upload
artifacts, and a final `publish` job (the only one with write permission) creates the release
once all three built, with the top `debian/changelog` entry as its text.

- **The trigger is a tag `v*`, not a commit.** Pushing to `main` — even bumping the version — never
  builds a release. A release happens only when a `vX.Y.Z` tag is pushed.
- The version only names the package — it does **not** trigger anything, but it **must match the tag**:
  the workflow's first job (`check`) fails when the tag, CMake, spec, `debian/changelog` and the
  metainfo `<release>` disagree.
- A tag name can't be reused for a new release; cut a new number.

### Version: single source of truth

`CMakeLists.txt` `project(saldo VERSION x.y.z)` is the one place the version is defined. The app
and the core derive it at build time (`SALDO_VERSION`), the widget's `metadata.json` is configured
from it, and the APK gets `versionName` from ECM's `ecm-version.gradle` (`versionCode` is a
timestamp, so it always grows). The packaging/metadata files (RPM spec, `debian/changelog`,
AppStream metainfo, `.po` header) are read by external tools that can't import the CMake value, so **`tools/bump-version.sh` propagates it to all of them** — never edit the version in
those files by hand. Run it with no argument to re-sync them to the current CMake version.

What the script does, from the `X.Y.Z` argument (or the current CMake version when none is given):

1. **CMakeLists.txt** — rewrites the number in `project(saldo VERSION ...)`.
2. **RPM spec** — updates `Version:` and prepends a `%changelog` entry.
3. **AppStream metainfo** — prepends a `<release version="X.Y.Z" date="…">`.
4. **debian/changelog** — prepends a `saldo (X.Y.Z-1) …` block.
5. **po/pt_BR.po** — updates the `Project-Id-Version` header.

Releases **always** ship a curated, user-facing changelog — not the raw commit list. Pass a notes
file (one line per entry) as the 2nd argument: `tools/bump-version.sh X.Y.Z <notes-file>`; the same
lines land in all three changelogs. Without it the script drafts the list from commit subjects
since the last tag — only a starting point to curate from. Steps 2–4 are idempotent.

### Cut a new version

Just ask — **"suba a versão X.Y.Z"** / **"release X.Y.Z"** (or `/release`) — and the **`release`
skill** (`.claude/skills/release/`) runs the whole flow. By hand:

1. Write a curated changelog to a notes file, then `tools/bump-version.sh X.Y.Z <notes-file>`.
2. Review (`git diff -- debian/changelog`), then `git commit -am "chore: release X.Y.Z"`.
3. `git tag vX.Y.Z && git push origin main vX.Y.Z` → CI builds RPM + DEB + APK and attaches them.

### Packaging gotchas

- Fedora `kf6-kirigami-devel` → Debian/Ubuntu **`libkirigami-dev`** (not `libkf6kirigami-dev`;
  `kirigami2-dev` is KF5). i18n/coreaddons follow `libkf6*-dev`.
- The QML plugin is built as `libsaldocoreplugin.so` on purpose: `KDECMakeSettings` empties the
  module prefix, but the QML engine only loads `lib<name>.so` from `qmldir`.
- The plugin gets an `$ORIGIN` RPATH to `libsaldocore` only for non-system prefixes (`~/.local`);
  distro packages need none (keeps rpmbuild's check-rpaths quiet).
- QML is compiled with `QT_QMLCACHEGEN_ARGUMENTS --only-bytecode` (core and app). qmlcachegen's
  C++ (AOT) output calls Qt private API, which made the RPM require
  `libQt6Qml.so.6(Qt_6.x_PRIVATE_API)` — every Fedora Qt minor update would then block
  `dnf upgrade`. Check with `rpm -qp --requires <rpm> | grep PRIVATE_API` (must print nothing).
- Local RPM check without a tag: tar the tree as `saldo-<ver>/` into `SOURCES/` and run
  `rpmbuild -bb --nodeps --define "_topdir <dir>" packaging/fedora/saldo.spec` (runs the tests
  in `%check`).
- `~/.local` installs need `QML_IMPORT_PATH` for plasmashell (handled by `install.sh`); RPM/DEB
  install into the system QML dir and need nothing. `install.sh` takes the QML dir from
  `build-user/install_manifest.txt`: `KDE_INSTALL_QMLDIR` is **empty** in `CMakeCache.txt` (ECM
  computes the default in a normal variable). Reading the cache once set the path to
  `~/.local/` and the widget failed with `module "org.saldo.core" is not installed`.
- The `.desktop` `Exec=` is the absolute binary path for non-`/usr` prefixes (`~/.local/bin` is
  not always in the Plasma session's PATH).
- The RPM builds in a pinned `fedora:44` container (build deps from the spec via `dnf builddep`):
  an RPM only installs on the Fedora it was built on (or newer), and `fedora:latest` had already
  moved past the Fedora the maintainer runs. Move the pin to the next Fedora before 44 reaches end
  of life (~mid 2027). The deb builds in an `ubuntu:26.04` container (build deps from
  `debian/control` via `mk-build-deps`; the runner's own Ubuntu lacks Qt 6.8/KF6). Never pin a
  release that is already end of life (its mirrors vanish).
- The deb's runtime package names (`qt6-svg-plugins`, `qml6-module-org-kde-quickcharts`,
  `libqt6sql6-sqlite`) were not verified locally; the first release run confirms them.
- The RPM job only attaches the main `.rpm` + `.src.rpm`; `-debuginfo`/`-debugsource` are filtered out.

### Android APK

- Built like KDE's own CI: KDE Craft inside `invent-registry.kde.org/sysadmin/ci-images/android-qt611`,
  with Qt/KF6 prebuilt from KDE's Craft cache. `tools/build-apk.sh --docker` does it locally
  (cache in `~/.cache/saldo-craft`) and in the `apk` release job; output in `dist/`.
- Craft finds the app through `android.app.lib_name` (literally `saldo`) in
  `android/AndroidManifest.xml`; the blueprint is copied into `craftmaster/blueprints/saldo/`.
- Validated locally on 2026-11-21: Qt/KF6 come from the cache (`files.kde.org/craft/Qt6/26.10/android/clang/arm64`);
  only Saldo compiles (~35 s), packaging ~1 min; the APK is ~37 MB.
- Gotchas met on the way: the blueprint must declare `svnTargets`/`defaultTarget` itself
  (`setDefaultValues()` needs the `version.ini` that only exists inside craft-blueprints-kde);
  `QT_NO_GLOBAL_APK_TARGET_PART_OF_ALL ON` keeps `qt_add_executable`'s own APK step out of the
  build (it failed with "Cannot find application binary"); the container runs as uid 1001, so the
  script sets git `safe.directory` and `dist/` files end up owned by uid 1001 on the host.
- **System bars:** the window has `Qt.ExpandedClientAreaHint` on Android, so it is drawn behind
  the status and navigation bars (transparent) and Kirigami pads its header and tabs by the safe
  areas; Qt sets the bars' icons from the app's color scheme (see Color theme). The splash
  background is `@color/saldo_splash_background`, dark in `values-night`.
- **Same fonts in light and dark:** Qt's copy of the Android theme (`extract_android_style` =
  `minimal`) gives the text its Android sizes; without it Qt falls back to much larger fonts
  (`none` made everything, tabs included, too big). Qt keeps one copy per mode in
  `ANDROID_STYLE_PATH` (`style.json`, `darkUiMode/style.json`) and only extracts the phone's mode,
  before `main()`. With the app set to the other mode in Settings, Qt found no copy: the controls
  grew while Kirigami's text (tabs), read at startup, did not. `main.cpp` copies the existing one
  to the missing mode before `QGuiApplication` (sizes do not depend on the mode; colors come from
  Breeze).
- **Plurals:** Craft builds KI18n on Android with libintl-lite, which has no plural forms
  (`ngettext` looks up the singular or the plural msgid by `n == 1` and never finds a `.mo`
  plural entry), so every `i18np` came out in English ("5 accounts"). On Android
  `SaldoTranslations.cmake` compiles the `.po` through `cmake/split_plurals.py`, which turns each
  plural entry into two plain ones (singular → `msgstr[0]`, plural msgid → `msgstr[1]`).
  Checked against libintl-lite itself (commit `ba15146`, the one Craft pins).
- **Splash screen:** the manifest keeps Qt's splash (`android/res/drawable/splash.xml`, the app icon
  on the pages' background) up with `splash_screen_sticky`; `main.cpp` hides it after a frame drawn
  once `Main.qml`'s `pageReady` is true (5 s fallback). Without it the phone showed an empty header
  for a moment: Qt shows the window before the first page is laid out.
- `libsaldocore` has no SOVERSION on Android (APKs only take unversioned `.so`). The app links
  `Qt6::Svg` (icons) and `OpenSSL::SSL` (Qt loads OpenSSL at runtime for HTTPS) on Android.
- **Signing:** KDE signs on its own server, we can't. `tools/sign-apk.sh` runs zipalign +
  apksigner with the release keystore from the secrets `ANDROID_KEYSTORE_BASE64` +
  `ANDROID_KEYSTORE_PASSWORD` (optional `ANDROID_KEY_ALIAS`, default `saldo`;
  `ANDROID_KEY_PASSWORD`, default = store password). Create the keystore once with
  `tools/create-android-keystore.sh` (kept in `~/.local/share/saldo-signing/`, never in git).
  Without the secrets the job still ships an APK, signed with a throwaway key and named
  `*-debug-key.apk`; it installs, but can't update a previous install in place.

### Supported platforms (README "Onde roda")

The README tables come from installing the release packages in clean containers (`dnf install` /
`apt install` of the `.rpm`/`.deb`, then `saldo --version`) and from the APK's `minSdkVersion`
(`aapt2 dump badging`: 28 = Android 9). Re-run that check and update the tables whenever a build
image changes (the Fedora pin, the Ubuntu container, Qt/KF versions). Checked with v0.0.3: Fedora
44/45, Ubuntu 26.04/26.10 and Debian testing install; Fedora 43, Ubuntu 24.04 and Debian 13 do not.

### Install for users

- Fedora: `sudo dnf install <release-url>/saldo-<ver>-1.fc<NN>.x86_64.rpm`
- Ubuntu/Debian: download the `.deb`, then `sudo apt install ./saldo_<ver>-1_amd64.deb`
- Android: download `saldo-<ver>-arm64-v8a.apk` on the phone and open it (allow installing
  from that app/browser when asked).
