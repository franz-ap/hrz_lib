# HRZ Lib Plugin für Redmine

Dieses Redmine-Plugin stellt Hilfs-Methoden/-Funktionen für andere Plugins und ein REST API bereit.

[![en](https://img.shields.io/badge/lang-en-grey.svg)](https://github.com/franz-ap/hrz_lib/blob/main/README.md)
[![de](https://img.shields.io/badge/lang-de-green.svg)](https://github.com/franz-ap/hrz_lib/blob/main/README.de.md)


## Überblick

Das HRZ Lib Plugin bietet zwei Hauptfunktionsbereiche:

1. **Ruby Helper-Module** - Wiederverwendbare Funktionen für andere Plugins
2. **REST API** - HTTP-basierte Schnittstelle für Custom Fields Management

---

# Teil 1: Ruby Helper-Module

## Verwendung in anderen Plugins

### Plugin-Abhängigkeit definieren

Um die HRZ Lib Helper-Module in einem anderen Plugin zu verwenden, füge folgendes in die `init.rb` deines Plugins ein:

```ruby
Redmine::Plugin.register :mein_plugin do
  name 'Mein Plugin'
  author 'Dein Name'
  description 'Beschreibung'
  version '1.0.0'
  
  # Abhängigkeit zu hrz_lib definieren
  requires_redmine_plugin :hrz_lib, version_or_higher: '0.4.0'
end

# Helper-Module laden
require 'hrz_lib/issue_helper'
require 'hrz_lib/custom_field_helper'
```

### Verwendung der Helper-Methoden

Nach dem Laden der Module können die Methoden direkt verwendet werden:

```ruby
# In einem Controller, Model oder Helper deines Plugins
class MeinController < ApplicationController
  def meine_aktion
    # Issue erstellen
    issue_id = HrzLib::IssueHelper.mk_issue(
      'mein-projekt',
      'Neues Issue',
      'Beschreibung'
    )
    
    # Custom Field erstellen
    field_id = HrzLib::CustomFieldHelper.create_custom_field(
      'Mein Feld',
      'string',
      'issue'
    )
  end
end
```

---

## IssueHelper Modul

Das `HrzLib::IssueHelper` Modul stellt Methoden zur Verwaltung von Redmine Issues bereit.

### Issue-Erstellung

#### `mk_issue(project_id, subject, description, assignee_id = nil, watcher_ids = [], options = {})`

Erstellt ein neues Issue mit den angegebenen Parametern.

**Parameter:**
- `project_id` - Projekt-ID oder -Identifier
- `subject` - Titel des Issues
- `description` - Beschreibungstext
- `assignee_id` - Benutzer-ID des Zugewiesenen (optional)
- `watcher_ids` - Array von Benutzer-IDs für Beobachter (optional)
- `options` - Hash mit zusätzlichen Optionen:
  - `:tracker_id` - Tracker-ID
  - `:status_id` - Status-ID
  - `:priority_id` - Prioritäts-ID
  - `:category_id` - Kategorie-ID
  - `:fixed_version_id` - Zielversion-ID
  - `:start_date` - Startdatum
  - `:due_date` - Fälligkeitsdatum
  - `:estimated_hours` - Geschätzte Stunden
  - `:done_ratio` - Fortschritt in Prozent (0-100)
  - `:parent_issue_id` - Eltern-Issue-ID für Unteraufgaben
  - `:custom_fields` - Hash mit Custom Field Werten `{field_id => value}`

**Rückgabe:** Issue-ID oder `nil` bei Fehler

**Beispiele:**

```ruby
# Einfaches Issue
issue_id = HrzLib::IssueHelper.mk_issue(
  'mein-projekt',
  'Bug beheben',
  'Die Anwendung stürzt ab wenn...'
)

# Mit Zuweisung und Beobachtern
issue_id = HrzLib::IssueHelper.mk_issue(
  'mein-projekt',
  'Feature implementieren',
  'Beschreibung',
  5,  # Zugewiesen an User ID 5
  [3, 7, 12]  # Beobachter User IDs
)

# Mit erweiterten Optionen
issue_id = HrzLib::IssueHelper.mk_issue(
  'mein-projekt',
  'Sprint-Aufgabe',
  'Beschreibung',
  nil,
  [],
  tracker_id: 2,
  priority_id: 4,
  due_date: '2025-12-31',
  estimated_hours: 8,
  custom_fields: {1 => 'Wert1', 2 => 'Wert2'}
)
```

### Dateianhänge

#### `attach_file(issue_id, file_path, options = {})`

Hängt eine Datei an ein bestehendes Issue an.

**Parameter:**
- `issue_id` - ID des Issues
- `file_path` - Vollständiger Pfad zur Datei
- `options` - Hash mit Optionen:
  - `:filename` - Eigener Dateiname (standard: Original-Dateiname)
  - `:description` - Beschreibung des Anhangs
  - `:author_id` - Benutzer-ID des Autors (standard: aktueller Benutzer)
  - `:content_type` - MIME-Typ (standard: auto-erkennung)

**Rückgabe:** Attachment-ID oder `nil` bei Fehler

**Beispiele:**

```ruby
# Einfacher Anhang
attachment_id = HrzLib::IssueHelper.attach_file(
  42,
  '/tmp/screenshot.png'
)

# Mit Optionen
attachment_id = HrzLib::IssueHelper.attach_file(
  42,
  '/tmp/report.pdf',
  filename: 'Monatsbericht.pdf',
  description: 'Finanzbericht November'
)
```

### Issue-Beziehungen

#### `create_relation(issue_from_id, issue_to_id, relation_type = 'relates', options = {})`

Erstellt eine Beziehung zwischen zwei Issues.

**Parameter:**
- `issue_from_id` - ID des Quell-Issues
- `issue_to_id` - ID des Ziel-Issues
- `relation_type` - Art der Beziehung:
  - `'relates'` - In Beziehung stehend
  - `'duplicates'` - Dupliziert
  - `'duplicated'` - Wird dupliziert von
  - `'blocks'` - Blockiert
  - `'blocked'` - Wird blockiert von
  - `'precedes'` - Vorgänger von
  - `'follows'` - Nachfolger von
  - `'copied_to'` - Kopiert nach
  - `'copied_from'` - Kopiert von
- `options` - Hash mit Optionen:
  - `:delay` - Verzögerung in Tagen (nur für 'precedes'/'follows')

**Rückgabe:** Relation-ID oder `nil` bei Fehler

**Beispiele:**

```ruby
# Einfache Beziehung
relation_id = HrzLib::IssueHelper.create_relation(42, 43, 'relates')

# Blockierung
relation_id = HrzLib::IssueHelper.create_relation(42, 43, 'blocks')

# Vorgänger mit Verzögerung
relation_id = HrzLib::IssueHelper.create_relation(
  42, 43, 'precedes',
  delay: 5
)
```

### Issue-Aktualisierung

#### `update_issue(issue_id, attributes = {}, options = {})`

Aktualisiert ein bestehendes Issue.

**Parameter:**
- `issue_id` - ID des Issues
- `attributes` - Hash mit zu aktualisierenden Attributen (siehe `mk_issue`)
- `options` - Hash mit Optionen:
  - `:notes` - Kommentar zur Änderung
  - `:private_notes` - Ob Kommentar privat ist (standard: false)
  - `:author_id` - Benutzer-ID des Autors

**Rückgabe:** `true` bei Erfolg, `false` bei Fehler

**Beispiele:**

```ruby
# Titel und Zugewiesenen ändern
success = HrzLib::IssueHelper.update_issue(
  42,
  subject: 'Neuer Titel',
  assigned_to_id: 5
)

# Mit Kommentar
success = HrzLib::IssueHelper.update_issue(
  42,
  {status_id: 3, done_ratio: 100},
  notes: 'Aufgabe abgeschlossen'
)

# Custom Fields aktualisieren
success = HrzLib::IssueHelper.update_issue(
  42,
  custom_fields: {1 => 'Neuer Wert', 2 => 'Anderer Wert'}
)
```

### Kommentare

#### `add_comment(issue_id, comment, options = {})`

Fügt einen Kommentar zu einem Issue hinzu.

**Parameter:**
- `issue_id` - ID des Issues
- `comment` - Kommentartext
- `options` - Hash mit Optionen:
  - `:private` - Ob Kommentar privat ist (standard: false)
  - `:author_id` - Benutzer-ID des Autors
  - `:attribute_changes` - Hash mit Attributänderungen `{field => value}`

**Rückgabe:** Journal-ID oder `nil` bei Fehler

**Beispiele:**

```ruby
# Einfacher Kommentar
journal_id = HrzLib::IssueHelper.add_comment(
  42,
  'Fortschrittsmeldung'
)

# Privater Kommentar
journal_id = HrzLib::IssueHelper.add_comment(
  42,
  'Interne Notiz',
  private: true
)

# Mit Attributänderungen
journal_id = HrzLib::IssueHelper.add_comment(
  42,
  'Status auf "In Bearbeitung" gesetzt',
  attribute_changes: {status_id: 2}
)
```

### Beobachter (Watchers)

#### `add_watcher(issue_id, user_id)`
Fügt einen Beobachter hinzu. Rückgabe: `true`/`false`

#### `add_watchers(issue_id, user_ids)`
Fügt mehrere Beobachter hinzu. Rückgabe: `{success: count, failed: [ids]}`

#### `remove_watcher(issue_id, user_id)`
Entfernt einen Beobachter. Rückgabe: `true`/`false`

#### `remove_watchers(issue_id, user_ids)`
Entfernt mehrere Beobachter. Rückgabe: `{success: count, failed: [ids]}`

#### `get_watchers(issue_id)`
Liste aller Beobachter. Rückgabe: Array von `{id, login, name}` oder `nil`

#### `is_watching?(issue_id, user_id)`
Prüft ob Benutzer beobachtet. Rückgabe: `true`/`false`/`nil`

#### `set_watchers(issue_id, user_ids)`
Ersetzt alle Beobachter. Rückgabe: `true`/`false`

**Beispiele:**

```ruby
# Einzelnen Beobachter hinzufügen
HrzLib::IssueHelper.add_watcher(42, 5)

# Mehrere Beobachter hinzufügen
result = HrzLib::IssueHelper.add_watchers(42, [3, 5, 7, 9])
puts "Erfolgreich: #{result[:success]}, Fehlgeschlagen: #{result[:failed]}"

# Beobachter entfernen
HrzLib::IssueHelper.remove_watcher(42, 5)

# Alle Beobachter abrufen
watchers = HrzLib::IssueHelper.get_watchers(42)
watchers.each { |w| puts "#{w[:name]} (#{w[:login]})" }

# Prüfen ob Benutzer beobachtet
if HrzLib::IssueHelper.is_watching?(42, 5)
  puts "Benutzer beobachtet das Issue"
end

# Beobachter-Liste komplett ersetzen
HrzLib::IssueHelper.set_watchers(42, [5, 6, 7])
```

### Verwandte Issues und Unteraufgaben suchen

#### `find_related_with_subject(issue_id, search_text)`
Findet ID eines verwandten Issues mit dem Suchtext im Titel. Rückgabe: Issue-ID oder `nil`

#### `has_related_with_subject?(issue_id, search_text)`
Prüft ob verwandtes Issue mit Suchtext existiert. Rückgabe: `true`/`false`/`nil`

#### `find_subtask_with_subject(issue_id, search_text)`
Findet ID einer Unteraufgabe mit dem Suchtext im Titel. Rückgabe: Issue-ID oder `nil`

#### `has_subtask_with_subject?(issue_id, search_text)`
Prüft ob Unteraufgabe mit Suchtext existiert. Rückgabe: `true`/`false`/`nil`

**Beispiele:**

```ruby
# Verwandtes Issue finden
related_id = HrzLib::IssueHelper.find_related_with_subject(42, 'deployment')
if related_id
  puts "Gefunden: Issue ##{related_id}"
end

# Prüfen ob verwandtes Issue existiert
if HrzLib::IssueHelper.has_related_with_subject?(42, 'critical')
  puts "Kritisches verwandtes Issue gefunden"
end

# Unteraufgabe finden
subtask_id = HrzLib::IssueHelper.find_subtask_with_subject(42, 'testing')

# Prüfen ob Unteraufgabe existiert
if HrzLib::IssueHelper.has_subtask_with_subject?(42, 'review')
  puts "Review-Unteraufgabe existiert"
end
```

### Zeiterfassung

#### `create_time_entry(issue_id, hours, options = {})`

Erstellt einen Zeiteintrag für ein Issue.

**Parameter:**
- `issue_id` - ID des Issues
- `hours` - Anzahl der Stunden
- `options` - Hash mit Optionen:
  - `:activity_id` - Aktivitäts-ID (erforderlich bei mehreren Aktivitäten)
  - `:comments` - Kommentar/Beschreibung
  - `:spent_on` - Datum (standard: heute)
  - `:user_id` - Benutzer-ID (standard: aktueller Benutzer)
  - `:custom_fields` - Custom Field Werte

**Rückgabe:** TimeEntry-ID oder `nil` bei Fehler

#### `update_time_entry(time_entry_id, attributes = {})`
Aktualisiert einen Zeiteintrag. Rückgabe: `true`/`false`

#### `delete_time_entry(time_entry_id)`
Löscht einen Zeiteintrag. Rückgabe: `true`/`false`

#### `get_time_entries(issue_id, options = {})`
Liste aller Zeiteinträge für ein Issue. Rückgabe: Array oder `nil`

#### `get_total_hours(issue_id, options = {})`
Gesamtstunden für ein Issue. Rückgabe: Float oder `nil`

#### `get_time_entry_activities()`
Liste verfügbarer Aktivitäten. Rückgabe: Array oder `nil`

#### `get_user_daily_hours(user_id, date = Date.today, options = {})`
Tagesstunden eines Benutzers. Rückgabe: Hash mit Details oder `nil`

#### `get_user_hours_range(user_id, from_date, to_date = nil, options = {})`
Stunden eines Benutzers in einem Zeitraum. Rückgabe: Hash oder `nil`

**Beispiele:**

```ruby
# Zeiteintrag erstellen
time_entry_id = HrzLib::IssueHelper.create_time_entry(
  42,
  2.5,
  activity_id: 9,
  comments: 'Entwicklungsarbeit'
)

# Mit spezifischem Datum
time_entry_id = HrzLib::IssueHelper.create_time_entry(
  42,
  4.0,
  activity_id: 9,
  spent_on: '2025-12-10',
  user_id: 5
)

# Zeiteintrag aktualisieren
HrzLib::IssueHelper.update_time_entry(123, hours: 3.5, comments: 'Aktualisiert')

# Zeiteintrag löschen
HrzLib::IssueHelper.delete_time_entry(123)

# Alle Zeiteinträge abrufen
entries = HrzLib::IssueHelper.get_time_entries(42)
entries.each { |e| puts "#{e[:spent_on]}: #{e[:hours]}h - #{e[:comments]}" }

# Gesamtstunden
total = HrzLib::IssueHelper.get_total_hours(42)
puts "Gesamt: #{total} Stunden"

# Tagesstunden eines Benutzers
result = HrzLib::IssueHelper.get_user_daily_hours(5)
puts "Heute: #{result[:total_hours]}h in #{result[:entries_count]} Einträgen"

# Stunden in Zeitraum
result = HrzLib::IssueHelper.get_user_hours_range(
  5,
  Date.today.beginning_of_week,
  Date.today.end_of_week
)
puts "Diese Woche: #{result[:total_hours]}h"

# Mit Gruppierung nach Datum
result = HrzLib::IssueHelper.get_user_hours_range(
  5,
  '2025-12-01',
  '2025-12-31',
  group_by_date: true
)
result[:by_date].each do |date, data|
  puts "#{date}: #{data[:hours]}h"
end
```

---

## CustomFieldHelper Modul

Das `HrzLib::CustomFieldHelper` Modul stellt Methoden zur Verwaltung von Custom Fields bereit.

### Custom Field erstellen

#### `create_custom_field(name, field_format, customized_type, options = {})`

Erstellt ein neues Custom Field.

**Parameter:**
- `name` - Name des Custom Fields
- `field_format` - Feldtyp:
  - `'string'` - Einzeiliger Text
  - `'text'` - Mehrzeiliger Text
  - `'int'` - Ganzzahl
  - `'float'` - Dezimalzahl
  - `'date'` - Datum
  - `'bool'` - Ja/Nein (Checkbox)
  - `'list'` - Auswahlliste
  - `'user'` - Benutzer-Auswahl
  - `'version'` - Versions-Auswahl
  - `'link'` - URL/Link
  - `'attachment'` - Dateianhang
- `customized_type` - Anwendungsbereich:
  - `'issue'` - Ticket/Issue
  - `'project'` - Projekt
  - `'user'` - Benutzer
  - `'time_entry'` - Zeiterfassung
  - `'version'` - Version
  - `'document'` - Dokument
  - `'group'` - Gruppe
- `options` - Hash mit Optionen:
  - `:description` - Beschreibung
  - `:is_required` - Pflichtfeld (standard: false)
  - `:is_for_all` - Für alle Projekte (standard: true)
  - `:visible` - Sichtbar (standard: true)
  - `:searchable` - Durchsuchbar (standard: false)
  - `:multiple` - Mehrfachauswahl bei Listen (standard: false)
  - `:default_value` - Standardwert
  - `:regexp` - Validierungs-Regex
  - `:min_length` - Minimale Länge
  - `:max_length` - Maximale Länge
  - `:possible_values` - Array mit möglichen Werten (für Listen)
  - `:project_ids` - Array mit Projekt-IDs
  - `:tracker_ids` - Array mit Tracker-IDs (für Issue Custom Fields)
  - `:role_ids` - Array mit Rollen-IDs
  - `:formula` - Ruby-Formel für berechnete Felder
  - `:is_computed` - Ob Feld berechnet ist (standard: false)

**Rückgabe:** CustomField-ID oder `nil` bei Fehler

**Beispiele:**

```ruby
# Einfaches Textfeld
field_id = HrzLib::CustomFieldHelper.create_custom_field(
  'Kundenname',
  'string',
  'issue',
  is_required: true,
  max_length: 100
)

# Auswahlliste
field_id = HrzLib::CustomFieldHelper.create_custom_field(
  'Prioritätsstufe',
  'list',
  'issue',
  possible_values: ['Niedrig', 'Mittel', 'Hoch', 'Kritisch'],
  default_value: 'Mittel'
)

# Mehrfach-Auswahlliste
field_id = HrzLib::CustomFieldHelper.create_custom_field(
  'Tags',
  'list',
  'issue',
  multiple: true,
  possible_values: ['Bug', 'Feature', 'Enhancement', 'Doku']
)

# Datumsfeld
field_id = HrzLib::CustomFieldHelper.create_custom_field(
  'Deadline',
  'date',
  'issue',
  is_required: true,
  description: 'Finaler Abgabetermin'
)

# Numerisches Feld mit Validierung
field_id = HrzLib::CustomFieldHelper.create_custom_field(
  'Geschätzte Kosten',
  'float',
  'issue',
  description: 'Geschätzte Kosten in EUR'
)

# Nur für bestimmte Projekte
field_id = HrzLib::CustomFieldHelper.create_custom_field(
  'Interne Referenz',
  'string',
  'issue',
  is_for_all: false,
  project_ids: [1, 3, 5]
)

# Nur für bestimmte Tracker
field_id = HrzLib::CustomFieldHelper.create_custom_field(
  'Bug-Kategorie',
  'list',
  'issue',
  tracker_ids: [1],
  possible_values: ['UI', 'Backend', 'Datenbank', 'API']
)
```

### Berechnete Custom Fields (Computed Fields)

Erfordert das [Computed Custom Field Plugin](https://github.com/annikoff/redmine_plugin_computed_custom_field).

#### `create_computed_field(name, field_format, customized_type, formula, options = {})`

Erstellt ein berechnetes Custom Field.

**Parameter:**
- `name`, `field_format`, `customized_type` - Wie bei `create_custom_field`
- `formula` - Ruby-Formel für die Berechnung
  - Andere Custom Fields: `cfs[field_id]`
  - Issue-Attribute: `self.attribute`
  - Ruby-Code: Beliebiger gültiger Ruby-Code
- `options` - Wie bei `create_custom_field`

**Rückgabe:** CustomField-ID oder `nil` bei Fehler

**Beispiele:**

```ruby
# Einfache Multiplikation
field_id = HrzLib::CustomFieldHelper.create_computed_field(
  'Gesamtkosten',
  'float',
  'issue',
  'cfs[1].to_f * cfs[2].to_f',
  description: 'Menge (CF 1) * Stückpreis (CF 2)'
)

# Mit Bedingungen
field_id = HrzLib::CustomFieldHelper.create_computed_field(
  'Rabattierter Preis',
  'float',
  'issue',
  'if cfs[5].to_i > 100; cfs[5].to_f * 0.9; else; cfs[5].to_f; end',
  description: '10% Rabatt bei Menge > 100'
)

# Mit Mehrwertsteuer
field_id = HrzLib::CustomFieldHelper.create_computed_field(
  'Gesamt mit MwSt.',
  'float',
  'issue',
  '(cfs[1].to_f * cfs[2].to_f * 1.19).round(2)',
  description: 'Gesamtkosten * 1.19 (19% MwSt.)'
)

# Issue-Attribute verwenden
field_id = HrzLib::CustomFieldHelper.create_computed_field(
  'Doppelte geschätzte Stunden',
  'float',
  'issue',
  '(self.estimated_hours || 0) * 2'
)

# Datums-Berechnungen
field_id = HrzLib::CustomFieldHelper.create_computed_field(
  'Tage seit Erstellung',
  'int',
  'issue',
  '(Date.today - self.created_on.to_date).to_i if self.created_on'
)

# String-Konkatenation
field_id = HrzLib::CustomFieldHelper.create_computed_field(
  'Vollständige Referenz',
  'string',
  'issue',
  '"#{self.project.identifier}-#{self.id}"'
)

# Mit safe navigation operator
field_id = HrzLib::CustomFieldHelper.create_computed_field(
  'Sichere Berechnung',
  'float',
  'issue',
  '(cfs[1].to_f * cfs[2].to_f).round(2) if cfs[1] && cfs[2]'
)
```

### Weitere Custom Field Methoden

#### `update_custom_field(custom_field_id, attributes = {})`
Aktualisiert ein Custom Field. Rückgabe: `true`/`false`

#### `delete_custom_field(custom_field_id)`
Löscht ein Custom Field. Rückgabe: `true`/`false`

#### `get_custom_field(custom_field_id)`
Ruft Details eines Custom Fields ab. Rückgabe: Hash oder `nil`

#### `list_custom_fields(customized_type = nil)`
Liste aller Custom Fields. Rückgabe: Array

#### `validate_formula(formula, customized_type = 'issue')`
Validiert eine Formel ohne Feld zu erstellen. Rückgabe: `{valid: bool, error: string}`

#### `get_formula_fields(customized_type)`
Liste verfügbarer Felder für Formeln. Rückgabe: `{custom_fields: [...], attributes: [...]}`

**Beispiele:**

```ruby
# Custom Field aktualisieren
HrzLib::CustomFieldHelper.update_custom_field(
  field_id,
  description: 'Aktualisierte Beschreibung',
  is_required: true
)

# Formel aktualisieren (Computed Field)
HrzLib::CustomFieldHelper.update_custom_field(
  field_id,
  formula: 'cfs[1].to_f * cfs[2].to_f * 1.19'
)

# Custom Field abrufen
field = HrzLib::CustomFieldHelper.get_custom_field(field_id)
puts field[:name]
puts "Formel: #{field[:formula]}" if field[:formula]

# Alle Custom Fields auflisten
fields = HrzLib::CustomFieldHelper.list_custom_fields('issue')
fields.each { |f| puts "#{f[:name]} (#{f[:field_format]})" }

# Custom Field löschen
HrzLib::CustomFieldHelper.delete_custom_field(field_id)

# Formel validieren
result = HrzLib::CustomFieldHelper.validate_formula('cfs[1] * cfs[2]', 'issue')
if result[:valid]
  puts "Formel ist gültig"
else
  puts "Fehler: #{result[:error]}"
end

# Verfügbare Felder für Formeln abrufen
fields = HrzLib::CustomFieldHelper.get_formula_fields('issue')
puts "Custom Fields:"
fields[:custom_fields].each { |cf| puts "  #{cf[:usage]} - #{cf[:name]}" }
puts "Attribute:"
fields[:attributes].each { |attr| puts "  #{attr[:usage]}" }
```

---

# Teil 2: Custom Fields REST API

Diese Dokumentation beschreibt die REST API für die Verwaltung von Custom Fields in Redmine.

## Authentifizierung

Alle API-Aufrufe erfordern Authentifizierung. Verwende entweder:
- HTTP Basic Auth
- API-Key im Header: `X-Redmine-API-Key: your_api_key`
- API-Key als Parameter: `?key=your_api_key`

**Hinweis:** Nur Administratoren können Custom Fields erstellen, ändern oder löschen.

## Endpunkte

### Liste aller Custom Fields

```
GET /hrz_custom_fields.json
GET /hrz_custom_fields.xml
```

**Optional: Filter nach Typ**
```
GET /hrz_custom_fields.json?customized_type=issue
```

**Beispiel-Antwort (JSON):**
```json
{
  "custom_fields": [
    {
      "id": 1,
      "name": "Customer Name",
      "field_format": "string",
      "customized_type": "issue",
      "is_required": true,
      "visible": true
    },
    {
      "id": 2,
      "name": "Priority Level",
      "field_format": "list",
      "customized_type": "issue",
      "is_required": false,
      "visible": true
    }
  ]
}
```

**cURL Beispiel:**
```bash
curl -X GET \
  -H "X-Redmine-API-Key: your_api_key" \
  -H "Content-Type: application/json" \
  https://your-redmine.com/hrz_custom_fields.json
```

---

### Computed Custom Fields (Berechnete Felder)

**Voraussetzung:** Das [Computed Custom Field Plugin](https://github.com/annikoff/redmine_plugin_computed_custom_field) muss installiert sein.

Computed Custom Fields ermöglichen die automatische Berechnung von Werten basierend auf anderen Feldern oder Issue-Attributen.

#### Formel-Syntax

In Formeln können Sie verwenden:
- `cfs[cf_id]` - Wert eines anderen Custom Fields (z.B. `cfs[1]`)
- `self.attribute` - Issue-Attribute (z.B. `self.estimated_hours`)
- Ruby-Code - Beliebiger Ruby-Code für Berechnungen

#### Beispiel 1: Einfache Multiplikation
```json
{
  "custom_field": {
    "name": "Total Cost",
    "field_format": "float",
    "customized_type": "issue",
    "is_computed": true,
    "formula": "cfs[1].to_f * cfs[2].to_f",
    "description": "Quantity (CF 1) * Unit Price (CF 2)"
  }
}
```

**cURL:**
```bash
curl -X POST \
  -H "X-Redmine-API-Key: your_api_key" \
  -H "Content-Type: application/json" \
  -d '{
    "custom_field": {
      "name": "Total Cost",
      "field_format": "float",
      "customized_type": "issue",
      "is_computed": true,
      "formula": "cfs[1].to_f * cfs[2].to_f"
    }
  }' \
  https://your-redmine.com/hrz_custom_fields.json
```

#### Beispiel 2: Mit Bedingungen (if/else)
```json
{
  "custom_field": {
    "name": "Discounted Price",
    "field_format": "float",
    "customized_type": "issue",
    "is_computed": true,
    "formula": "if cfs[5].to_i > 100; cfs[5].to_f * 0.9; else; cfs[5].to_f; end",
    "description": "10% discount for quantities over 100"
  }
}
```

---

### Formel validieren

```
POST /hrz_custom_fields/validate_formula.json
POST /hrz_custom_fields/validate_formula.xml
```

Validiert eine Formel ohne ein Custom Field zu erstellen.

**Parameter:**
- `formula`: Die zu validierende Formel
- `customized_type`: Typ für Kontext (optional, default: 'issue')

**Beispiel:**
```json
{
  "formula": "cfs[1] * cfs[2]",
  "customized_type": "issue"
}
```

**cURL:**
```bash
curl -X POST \
  -H "X-Redmine-API-Key: your_api_key" \
  -H "Content-Type: application/json" \
  -d '{
    "formula": "cfs[1] * cfs[2]",
    "customized_type": "issue"
  }' \
  https://your-redmine.com/hrz_custom_fields/validate_formula.json
```

**Antwort bei gültiger Formel:**
```json
{
  "valid": true,
  "error": null
}
```

**Antwort bei ungültiger Formel:**
```json
{
  "valid": false,
  "error": "Formula contains syntax error"
}
```

---

### Verfügbare Felder für Formeln abrufen

```
GET /hrz_custom_fields/formula_fields.json?customized_type=issue
GET /hrz_custom_fields/formula_fields.xml?customized_type=issue
```

Gibt alle verfügbaren Custom Fields und Attribute zurück, die in Formeln verwendet werden können.

**cURL:**
```bash
curl -X GET \
  -H "X-Redmine-API-Key: your_api_key" \
  https://your-redmine.com/hrz_custom_fields/formula_fields.json?customized_type=issue
```

**Antwort:**
```json
{
  "custom_fields": [
    {
      "id": 1,
      "name": "Quantity",
      "field_format": "int",
      "usage": "cfs[1]"
    },
    {
      "id": 2,
      "name": "Unit Price",
      "field_format": "float",
      "usage": "cfs[2]"
    }
  ],
  "attributes": [
    {"name": "id", "usage": "self.id"},
    {"name": "subject", "usage": "self.subject"},
    {"name": "estimated_hours", "usage": "self.estimated_hours"},
    {"name": "created_on", "usage": "self.created_on"}
  ]
}
```

---

### Details eines Custom Fields

```
GET /hrz_custom_fields/:id.json
GET /hrz_custom_fields/:id.xml
```

**Beispiel-Antwort (JSON):**
```json
{
  "custom_field": {
    "id": 1,
    "name": "Customer Name",
    "description": "Name of the customer",
    "field_format": "string",
    "customized_type": "issue",
    "is_required": true,
    "is_for_all": true,
    "visible": true,
    "searchable": true,
    "multiple": false,
    "default_value": null,
    "possible_values": null,
    "regexp": null,
    "min_length": null,
    "max_length": 255
  }
}
```

**cURL Beispiel:**
```bash
curl -X GET \
  -H "X-Redmine-API-Key: your_api_key" \
  -H "Content-Type: application/json" \
  https://your-redmine.com/hrz_custom_fields/1.json
```

---

### Custom Field erstellen

```
POST /hrz_custom_fields.json
POST /hrz_custom_fields.xml
```

**Erforderliche Parameter:**
- `name`: Name des Custom Fields
- `field_format`: Format-Typ (siehe unten)
- `customized_type`: Typ (siehe unten)

**Optionale Parameter:**
- `description`: Beschreibung
- `is_required`: Pflichtfeld (true/false)
- `is_for_all`: Für alle Projekte (true/false)
- `visible`: Sichtbar (true/false)
- `searchable`: Durchsuchbar (true/false)
- `multiple`: Mehrfachauswahl (true/false, nur für Listen)
- `default_value`: Standardwert
- `regexp`: Validierungs-Regex
- `min_length`: Minimale Länge
- `max_length`: Maximale Länge
- `possible_values`: Array mit möglichen Werten (für Listen)
- `project_ids`: Array mit Projekt-IDs
- `tracker_ids`: Array mit Tracker-IDs (für Issue Custom Fields)
- `role_ids`: Array mit Rollen-IDs

#### Gültige Field Formats:
- `string`: Einzeiliger Text
- `text`: Mehrzeiliger Text
- `int`: Ganzzahl
- `float`: Dezimalzahl
- `date`: Datum
- `bool`: Ja/Nein (Checkbox)
- `list`: Auswahlliste
- `user`: Benutzer-Auswahl
- `version`: Versions-Auswahl
- `link`: URL/Link
- `attachment`: Dateianhang

#### Gültige Customized Types:
- `issue`: Ticket/Issue
- `project`: Projekt
- `user`: Benutzer
- `time_entry`: Zeiterfassung
- `version`: Version
- `document`: Dokument
- `group`: Gruppe

**Beispiel 1: Einfaches Textfeld**
```json
{
  "custom_field": {
    "name": "Customer Name",
    "field_format": "string",
    "customized_type": "issue",
    "is_required": true,
    "description": "Name of the customer",
    "max_length": 100
  }
}
```

**cURL:**
```bash
curl -X POST \
  -H "X-Redmine-API-Key: your_api_key" \
  -H "Content-Type: application/json" \
  -d '{
    "custom_field": {
      "name": "Customer Name",
      "field_format": "string",
      "customized_type": "issue",
      "is_required": true,
      "max_length": 100
    }
  }' \
  https://your-redmine.com/hrz_custom_fields.json
```

**Beispiel 2: Auswahlliste**
```json
{
  "custom_field": {
    "name": "Priority Level",
    "field_format": "list",
    "customized_type": "issue",
    "possible_values": ["Low", "Medium", "High", "Critical"],
    "default_value": "Medium",
    "is_required": false
  }
}
```

---

### Custom Field aktualisieren

```
PUT /hrz_custom_fields/:id.json
PUT /hrz_custom_fields/:id.xml
PATCH /hrz_custom_fields/:id.json
PATCH /hrz_custom_fields/:id.xml
```

**Beispiel:**
```json
{
  "custom_field": {
    "description": "Updated description",
    "is_required": true
  }
}
```

**cURL:**
```bash
curl -X PUT \
  -H "X-Redmine-API-Key: your_api_key" \
  -H "Content-Type: application/json" \
  -d '{
    "custom_field": {
      "description": "Updated description",
      "is_required": true
    }
  }' \
  https://your-redmine.com/hrz_custom_fields/1.json
```

---

### Custom Field löschen

```
DELETE /hrz_custom_fields/:id.json
DELETE /hrz_custom_fields/:id.xml
```

**cURL:**
```bash
curl -X DELETE \
  -H "X-Redmine-API-Key: your_api_key" \
  https://your-redmine.com/hrz_custom_fields/1.json
```

**Erfolgreiche Antwort:** HTTP 204 No Content

---

## Fehlerbehandlung

### HTTP Status Codes

- **200 OK**: Erfolgreiche GET/PUT Anfrage
- **201 Created**: Custom Field erfolgreich erstellt
- **204 No Content**: Custom Field erfolgreich gelöscht
- **401 Unauthorized**: Fehlende oder ungültige Authentifizierung
- **403 Forbidden**: Keine Administrator-Rechte
- **404 Not Found**: Custom Field nicht gefunden
- **422 Unprocessable Entity**: Validierungsfehler

### Fehler-Antworten

```json
{
  "error": "Missing required parameters: name, field_format, customized_type"
}
```

```json
{
  "error": "Failed to create custom field"
}
```

---

## Tipps und Best Practices

1. **Eindeutige Namen**: Verwende eindeutige, beschreibende Namen für Custom Fields
2. **Beschreibungen**: Füge immer hilfreiche Beschreibungen hinzu
3. **Validierung**: Nutze `regexp`, `min_length`, `max_length` für Datenqualität
4. **Projekt-Zuordnung**: Überlege, ob das Feld wirklich für alle Projekte sein muss
5. **Tracker-Zuordnung**: Beschränke Issue Custom Fields auf relevante Tracker
6. **Standardwerte**: Setze sinnvolle Standardwerte für bessere UX
7. **Testing**: Teste Custom Fields erst in einem Test-Projekt

### Computed Custom Fields Best Practices

8. **Formel-Validierung**: Nutze `/validate_formula` vor dem Erstellen
9. **Null-Checks**: Prüfe immer auf `nil` in Formeln: `if cfs[1] && cfs[2]`
10. **Type-Casting**: Verwende `.to_f`, `.to_i`, `.to_s` für sichere Konvertierung
11. **Safe Navigation**: Nutze `.try()` für optionale Werte
12. **Rounding**: Runde Gleitkommazahlen: `.round(2)`
13. **Re-save**: Nach Formel-Updates müssen Objekte neu gespeichert werden
14. **Verfügbare Felder**: Nutze `/formula_fields` um zu sehen, welche Felder verfügbar sind
15. **Dokumentation**: Dokumentiere komplexe Formeln in der Beschreibung

---

## Bekannte Einschränkungen

- Custom Fields können nicht in eine andere Klasse konvertiert werden (z.B. IssueCustomField zu ProjectCustomField)
- Das Ändern des `field_format` nach der Erstellung ist nicht empfohlen
- Beim Löschen eines Custom Fields gehen alle zugehörigen Werte verloren
- **Computed Custom Fields**: Erfordern das installierte Computed Custom Field Plugin
- **Computed Custom Fields**: Werden beim Speichern des Objekts berechnet, nicht bei der Anzeige
- **Computed Custom Fields**: Nach Änderung der Formel müssen Objekte neu gespeichert werden
- **Computed Custom Fields**: Komplexe Formeln können die Performance beeinträchtigen

## Plugin-Kompatibilität

Dieses Plugin wurde getestet mit:
- Redmine 6.1.x
- Computed Custom Field Plugin 1.0.7+

Noch nicht getestet mit:
- Computed Custom Field NextGen

Für die Verwendung von Computed Custom Fields installieren Sie:
```bash
cd plugins
git clone https://github.com/annikoff/redmine_plugin_computed_custom_field.git computed_custom_field
cd ..
bundle exec rake redmine:plugins:migrate
```
