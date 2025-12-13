# HRZ Lib Custom Fields REST API

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

#### Beispiel 3: Mit Mehrwertsteuer
```json
{
  "custom_field": {
    "name": "Total with VAT",
    "field_format": "float",
    "customized_type": "issue",
    "is_computed": true,
    "formula": "(cfs[1].to_f * cfs[2].to_f * 1.19).round(2)",
    "description": "Total Cost * 1.19 (19% VAT)"
  }
}
```

#### Beispiel 4: Issue-Attribute verwenden
```json
{
  "custom_field": {
    "name": "Double Estimated Hours",
    "field_format": "float",
    "customized_type": "issue",
    "is_computed": true,
    "formula": "(self.estimated_hours || 0) * 2"
  }
}
```

#### Beispiel 5: Datums-Berechnungen
```json
{
  "custom_field": {
    "name": "Days Since Created",
    "field_format": "int",
    "customized_type": "issue",
    "is_computed": true,
    "formula": "(Date.today - self.created_on.to_date).to_i if self.created_on"
  }
}
```

#### Beispiel 6: String-Konkatenation
```json
{
  "custom_field": {
    "name": "Full Reference",
    "field_format": "string",
    "customized_type": "issue",
    "is_computed": true,
    "formula": "\"#{self.project.identifier}-#{self.id}\""
  }
}
```

#### Beispiel 7: Link generieren
```json
{
  "custom_field": {
    "name": "Review Request Link",
    "field_format": "link",
    "customized_type": "issue",
    "is_computed": true,
    "formula": "\"/projects/#{self.project_id}/issues/new?issue[subject]=Review+[##{self.id}]&issue[tracker_id]=3\""
  }
}
```

#### Beispiel 8: Mit safe navigation operator
```json
{
  "custom_field": {
    "name": "Safe Calculation",
    "field_format": "float",
    "customized_type": "issue",
    "is_computed": true,
    "formula": "(cfs[1].to_f * cfs[2].to_f).round(2) if cfs[1] && cfs[2]"
  }
}
```

#### Beispiel 9: Aus Key/Value Liste
```json
{
  "custom_field": {
    "name": "Priority Value",
    "field_format": "int",
    "customized_type": "issue",
    "is_computed": true,
    "formula": "cfs[1].try(:id)"
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

**cURL:**
```bash
curl -X POST \
  -H "X-Redmine-API-Key: your_api_key" \
  -H "Content-Type: application/json" \
  -d '{
    "custom_field": {
      "name": "Priority Level",
      "field_format": "list",
      "customized_type": "issue",
      "possible_values": ["Low", "Medium", "High", "Critical"],
      "default_value": "Medium"
    }
  }' \
  https://your-redmine.com/hrz_custom_fields.json
```

**Beispiel 3: Mehrfach-Auswahlliste**
```json
{
  "custom_field": {
    "name": "Tags",
    "field_format": "list",
    "customized_type": "issue",
    "multiple": true,
    "possible_values": ["Bug", "Feature", "Enhancement", "Documentation", "Security"]
  }
}
```

**Beispiel 4: Datumsfeld**
```json
{
  "custom_field": {
    "name": "Deadline",
    "field_format": "date",
    "customized_type": "issue",
    "is_required": true,
    "description": "Final deadline for this task"
  }
}
```

**Beispiel 5: Numerisches Feld mit Validierung**
```json
{
  "custom_field": {
    "name": "Estimated Cost",
    "field_format": "float",
    "customized_type": "issue",
    "description": "Estimated cost in EUR"
  }
}
```

**Beispiel 6: Custom Field nur für bestimmte Projekte**
```json
{
  "custom_field": {
    "name": "Internal Reference",
    "field_format": "string",
    "customized_type": "issue",
    "is_for_all": false,
    "project_ids": [1, 3, 5]
  }
}
```

**Beispiel 7: Custom Field nur für bestimmte Tracker**
```json
{
  "custom_field": {
    "name": "Bug Category",
    "field_format": "list",
    "customized_type": "issue",
    "tracker_ids": [1],
    "possible_values": ["UI", "Backend", "Database", "API"]
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

**Beispiel: Auswahl-Optionen aktualisieren**
```bash
curl -X PUT \
  -H "X-Redmine-API-Key: your_api_key" \
  -H "Content-Type: application/json" \
  -d '{
    "custom_field": {
      "possible_values": ["Low", "Medium", "High", "Critical", "Emergency"]
    }
  }' \
  https://your-redmine.com/hrz_custom_fields/2.json
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

## Verwendung in Ruby/Rails

```ruby
# Standard Custom Field erstellen
field_id = HrzLib::CustomFieldHelper.create_custom_field(
  'Customer Name',
  'string',
  'issue',
  is_required: true,
  max_length: 100
)

# Auswahlliste erstellen
field_id = HrzLib::CustomFieldHelper.create_custom_field(
  'Priority Level',
  'list',
  'issue',
  possible_values: ['Low', 'Medium', 'High', 'Critical'],
  default_value: 'Medium'
)

# Computed Custom Field erstellen (lange Form)
field_id = HrzLib::CustomFieldHelper.create_custom_field(
  'Total Cost',
  'float',
  'issue',
  is_computed: true,
  formula: 'cfs[1].to_f * cfs[2].to_f',
  description: 'Quantity * Unit Price'
)

# Computed Custom Field erstellen (kurze Form)
field_id = HrzLib::CustomFieldHelper.create_computed_field(
  'Total Cost',
  'float',
  'issue',
  'cfs[1].to_f * cfs[2].to_f',
  description: 'Quantity * Unit Price'
)

# Formel validieren
result = HrzLib::CustomFieldHelper.validate_formula('cfs[1] * cfs[2]', 'issue')
if result[:valid]
  puts "Formel ist gültig"
else
  puts "Fehler: #{result[:error]}"
end

# Verfügbare Felder für Formeln abrufen
fields = HrzLib::CustomFieldHelper.get_formula_fields('issue')
fields[:custom_fields].each do |cf|
  puts "Custom Field: cfs[#{cf[:id]}] - #{cf[:name]}"
end
fields[:attributes].each do |attr|
  puts "Attribut: #{attr[:usage]}"
end

# Custom Field aktualisieren
HrzLib::CustomFieldHelper.update_custom_field(
  field_id,
  formula: 'cfs[1].to_f * cfs[2].to_f * 1.19',
  description: 'Updated description',
  is_required: true
)

# Custom Field abrufen
field = HrzLib::CustomFieldHelper.get_custom_field(field_id)
puts field[:name]
puts "Formula: #{field[:formula]}" if field[:formula]

# Alle Custom Fields auflisten
fields = HrzLib::CustomFieldHelper.list_custom_fields('issue')

# Custom Field löschen
HrzLib::CustomFieldHelper.delete_custom_field(field_id)
```

---

## Python Beispiele

```python
import requests
import json

base_url = "https://your-redmine.com"
api_key = "your_api_key"
headers = {
    "X-Redmine-API-Key": api_key,
    "Content-Type": "application/json"
}

# Standard Custom Field erstellen
data = {
    "custom_field": {
        "name": "Customer Name",
        "field_format": "string",
        "customized_type": "issue",
        "is_required": True,
        "max_length": 100
    }
}
response = requests.post(
    f"{base_url}/hrz_custom_fields.json",
    headers=headers,
    data=json.dumps(data)
)
field_id = response.json()["custom_field"]["id"]

# Computed Custom Field erstellen
data = {
    "custom_field": {
        "name": "Total Cost",
        "field_format": "float",
        "customized_type": "issue",
        "is_computed": True,
        "formula": "cfs[1].to_f * cfs[2].to_f",
        "description": "Quantity * Unit Price"
    }
}
response = requests.post(
    f"{base_url}/hrz_custom_fields.json",
    headers=headers,
    data=json.dumps(data)
)
computed_field_id = response.json()["custom_field"]["id"]

# Formel validieren
data = {
    "formula": "cfs[1] * cfs[2]",
    "customized_type": "issue"
}
response = requests.post(
    f"{base_url}/hrz_custom_fields/validate_formula.json",
    headers=headers,
    data=json.dumps(data)
)
validation = response.json()
if validation["valid"]:
    print("Formel ist gültig")
else:
    print(f"Fehler: {validation['error']}")

# Verfügbare Felder für Formeln abrufen
response = requests.get(
    f"{base_url}/hrz_custom_fields/formula_fields.json?customized_type=issue",
    headers=headers
)
fields = response.json()
print("Custom Fields:")
for cf in fields["custom_fields"]:
    print(f"  {cf['usage']} - {cf['name']}")
print("Attributes:")
for attr in fields["attributes"]:
    print(f"  {attr['usage']}")

# Custom Field abrufen
response = requests.get(
    f"{base_url}/hrz_custom_fields/{field_id}.json",
    headers=headers
)
field = response.json()["custom_field"]
if field.get("formula"):
    print(f"Formula: {field['formula']}")

# Custom Field aktualisieren
data = {
    "custom_field": {
        "description": "Updated description"
    }
}
requests.put(
    f"{base_url}/hrz_custom_fields/{field_id}.json",
    headers=headers,
    data=json.dumps(data)
)

# Formel aktualisieren (Computed Custom Field)
data = {
    "custom_field": {
        "formula": "cfs[1].to_f * cfs[2].to_f * 1.19"
    }
}
requests.put(
    f"{base_url}/hrz_custom_fields/{computed_field_id}.json",
    headers=headers,
    data=json.dumps(data)
)

# Custom Field löschen
requests.delete(
    f"{base_url}/hrz_custom_fields/{field_id}.json",
    headers=headers
)
```

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

### Formel-Beispiele für häufige Anwendungsfälle

**Summe berechnen:**
```ruby
cfs[1].to_f + cfs[2].to_f + cfs[3].to_f
```

**Durchschnitt:**
```ruby
(cfs[1].to_f + cfs[2].to_f + cfs[3].to_f) / 3
```

**Prozentuale Berechnung:**
```ruby
(cfs[1].to_f / cfs[2].to_f * 100).round(2) if cfs[2] && cfs[2].to_f > 0
```

**Differenz zwischen Daten:**
```ruby
(cfs[2].to_date - cfs[1].to_date).to_i if cfs[1] && cfs[2]
```

**Bedingte Formatierung:**
```ruby
cfs[1].to_i >= 100 ? "High" : "Low"
```

**Mehrere Bedingungen:**
```ruby
if cfs[1].to_i < 10
  "Low"
elsif cfs[1].to_i < 50
  "Medium"
else
  "High"
end
```

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
