# HRZ Lib Plugin - Transport Feature Implementation

## Neue Dateien

### 1. Plugin-Konfiguration
**Datei:** `init.rb` (aktualisiert)
- Fügt Settings-Konfiguration hinzu
- Registriert Admin-Menü-Eintrag "Transports"

### 2. Settings Partial
**Datei:** `app/views/settings/_hrz_lib_settings.html.erb`
- Zeigt Eingabefeld für Target-URL in einem "Transport"-Rahmen
- Enthält CSS-Styling für die Gruppierung

### 3. Transport Controller
**Datei:** `app/controllers/hrz_transports_controller.rb`
- `index`: Zeigt Vergleichsseite mit Optionen
- `execute`: Führt Transport-Operation aus
- Handhabt Fehlerbehandlung und Redirects

### 4. Transport Helper
**Datei:** `lib/hrz_lib/transport_helper.rb`
- `fetch_target_custom_fields`: Holt Custom Fields von Zielinstanz
- `fetch_target_field_details`: Holt Details eines spezifischen Feldes
- `compare_custom_fields`: Vergleicht lokale und Ziel-Felder
- `compare_field_properties`: Detaillierter Vergleich der Eigenschaften
- `execute_transport`: Führt Transport aus
- `transport_local_to_target`: Transport zur Zielinstanz
- `transport_target_to_local`: Transport von Zielinstanz
- `prepare_field_data_for_transport`: Bereitet Daten vor
- `add_documentation_note`: Fügt Notiz zu Dokumentations-Ticket hinzu

### 5. Transport View
**Datei:** `app/views/hrz_transports/index.html.erb`
- Formular mit Vergleichsoptionen
- Projekt-Auswahl (wenn Scope = 'project')
- Transport-Richtung
- Dokumentations-Ticket IDs
- Ergebnis-Tabelle mit:
  - Feldname und Typ
  - Status-Spalte (✓ für identisch, ≠ für unterschiedlich)
  - Lokale Werte
  - Transport-Pfeil (nur bei aktiviertem Transport)
  - Ziel-Werte
- Responsive CSS-Styling

### 6. Routes
**Datei:** `config/routes.rb` (aktualisiert)
- GET `/hrz_transports` → Index-Seite
- POST `/hrz_transports/execute` → Transport ausführen

### 7. Übersetzungen
**Dateien:** 
- `config/locales/de.yml` (Deutsch)
- `config/locales/en.yml` (Englisch)

Enthält alle Labels und Meldungen für:
- Settings
- Transport-Seite
- Vergleichsergebnisse
- Feldtypen und -eigenschaften
- Fehlermeldungen
- Bestätigungsdialoge

## Verzeichnisstruktur

```
plugins/hrz_lib/
├── init.rb                                      (aktualisiert)
├── app/
│   ├── controllers/
│   │   ├── hrz_custom_fields_controller.rb      (existiert bereits)
│   │   └── hrz_transports_controller.rb         (neu)
│   └── views/
│       ├── settings/
│       │   └── _hrz_lib_settings.html.erb       (neu)
│       └── hrz_transports/
│           └── index.html.erb                   (neu)
├── lib/
│   └── hrz_lib/
│       ├── issue_helper.rb                      (existiert bereits)
│       ├── custom_field_helper.rb               (existiert bereits)
│       └── transport_helper.rb                  (neu)
└── config/
    ├── routes.rb                                (aktualisiert)
    └── locales/
        ├── de.yml                               (aktualisiert)
        ├── en.yml                               (aktualisiert)
        ├── bg.yml                               (zu aktualisieren)
        ├── el.yml                               (zu aktualisieren)
        ├── hr.yml                               (zu aktualisieren)
        ├── hu.yml                               (zu aktualisieren)
        ├── pl.yml                               (zu aktualisieren)
        ├── ro.yml                               (zu aktualisieren)
        ├── ru.yml                               (zu aktualisieren)
        ├── tr.yml                               (zu aktualisieren)
        └── uk.yml                               (zu aktualisieren)
```

## Features

### 1. Plugin-Konfiguration
- Admin → Plugins → HRZ Lib → Configure
- Eingabefeld für Target-URL
- Unterstützt URLs mit und ohne abschließenden `/`

### 2. Transport-Seite
- Admin → Transports
- **Vergleichsoptionen:**
  - Alle Custom Fields vergleichen
  - Nur Custom Fields eines lokalen Projekts vergleichen
- **Transport-Richtung:**
  - Nur Vergleich (read-only)
  - Von lokal zum Ziel
  - Vom Ziel zu lokal
- **Dokumentations-Tickets:**
  - Optional: Lokale Ticket-ID
  - Optional: Ziel-Ticket-ID
  - Bei Transport wird automatisch eine Notiz hinzugefügt

### 3. Vergleichstabelle
- **Spalte 1:** Feldname und Customized Type
- **Spalte 2:** Feldtyp (string, list, int, etc.)
- **Spalte 3:** Status (✓ identisch, ≠ unterschiedlich)
- **Spalte 4:** Lokale Werte (nur bei Unterschieden)
- **Spalte 5:** Transport-Pfeil (nur bei aktiviertem Transport)
- **Spalte 6:** Ziel-Werte (nur bei Unterschieden)

### 4. Unterschiede
Werden angezeigt für:
- Name
- Feldformat
- Pflichtfeld-Status
- Mögliche Werte (bei Listen)
- Standardwert
- Formel (bei Computed Fields)
- Existenz (wenn Feld nur in einer Instanz existiert)

### 5. Transport-Ausführung
- Klick auf blauen Pfeil → Bestätigungsdialog
- Transport wird ausgeführt
- Notizen werden zu Dokumentations-Tickets hinzugefügt
- Erfolgs-/Fehlermeldung wird angezeigt
- Seite wird neu geladen mit aktuellen Daten

## API-Verwendung

Das Plugin verwendet:
- **Lokale API:** Eigenes REST-API (`/hrz_custom_fields`)
- **Ziel-API:** REST-API der Zielinstanz
- **Authentifizierung:** API-Key des aktuell angemeldeten Benutzers
- **Format:** JSON

## Sicherheit

- Nur Administratoren haben Zugriff
- Bestätigungsdialog vor Transport
- Logging aller Transport-Operationen
- Fehlerbehandlung mit aussagekräftigen Meldungen
- Dokumentation in Tickets (optional)

## Weitere Schritte

Die restlichen 9 Sprachdateien müssen noch mit den neuen Übersetzungsschlüsseln aktualisiert werden:
- bg.yml (Bulgarisch)
- el.yml (Griechisch)
- hr.yml (Kroatisch)
- hu.yml (Ungarisch)
- pl.yml (Polnisch)
- ro.yml (Rumänisch)
- ru.yml (Russisch)
- tr.yml (Türkisch)
- uk.yml (Ukrainisch)
