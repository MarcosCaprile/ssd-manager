# Sicherheit und Datenschutz

## Sicherheit

- Passwörter werden mit Argon2id gehasht, falls verfügbar; andernfalls bcrypt.
- Refresh-Tokens werden nur als SHA-256-Hash gespeichert.
- Access-Tokens sind kurzlebig und HMAC-signiert.
- Geräte-Sitzungen sind einzeln widerrufbar.
- Login besitzt serverseitiges Rate Limiting über `login_attempts`.
- SQL-Zugriffe laufen über PDO Prepared Statements.
- Rollen und `school_id` werden serverseitig geprüft.
- Kritische Dienstplanänderungen laufen in Transaktionen.
- Ausfallzeiträume sind auf die eigene Schule begrenzt; das Backend verhindert
  Belegungen an Ausfalltagen und das Schließen bereits belegter Tage.
- Push-Benachrichtigungen werden über `notification_logs.deduplication_key` dedupliziert.
- Administrative Aktionen werden in `audit_logs` protokolliert.
- Ankündigungsanhänge werden ohne öffentliche URL gespeichert. Upload und
  Download benötigen eine gültige Sitzung derselben Schule; Typ, Dateiendung,
  Größe, Uploader und Zuordnung werden serverseitig geprüft.
- Pro Anhang gelten 8 MB und pro Nachricht vier Anhänge. Nicht zugeordnete
  Uploads werden nach einem Tag durch den Wartungsjob entfernt.
- Pro Nutzer gelten insgesamt 100 MB für Ankündigungsanhänge. Quotenprüfung und
  Upload laufen in einer Transaktion mit Nutzersperre, damit parallele Uploads
  das Limit nicht überschreiten. Listen und Löschungen sind uploader- und
  schulgebunden.
- Nutzeroberflächen zeigen keine rohen Exceptions, URLs, API-/SQL-Texte,
  Stacktraces oder beliebige Serverantworten. Technische Details bleiben in
  geschützten Serverlogs; Nutzer erhalten sichere, handlungsorientierte Texte.
- Secrets liegen in `.env` oder außerhalb des Webroots, nicht im Repository.
- Produktive API muss ausschließlich über HTTPS erreichbar sein.

## Datenschutz

Gespeicherte personenbezogene Daten:

| Daten | Zweck | Löschung |
| --- | --- | --- |
| Name, Benutzername, Schul-E-Mail | Account und Anzeige im Dienstplan | Bei Accountlöschung anonymisieren/löschen |
| Rolle, Status | Berechtigungen | Bei Accountlöschung |
| `Sanitäter seit` | Historische Profilangabe für Sanis/Leitung | Bei Accountlöschung |
| Passwort-Hash | Authentifizierung | Bei Accountlöschung |
| Dienstzuweisungen | Dienstnachweis und Statistik | Historisch aufbewahren, nach Löschung möglichst anonymisieren |
| Geräte-Sitzungen | Sicherheit, Push-Zustellung | Bei Logout, Widerruf, Deaktivierung, Löschung |
| Firebase-Token | Push-Benachrichtigungen | Bei Logout, Widerruf, ungültigem Token, Löschung |
| Audit-Logs | Nachvollziehbarkeit administrativer Aktionen | Aufbewahrung nach Schulvorgabe begrenzen |
| Login-Versuche | Brute-Force-Schutz | Regelmäßig bereinigen |
| Ankündigungstexte und -anhänge | Schulweite organisatorische Kommunikation | Nach schulischer Lösch- und Aufbewahrungsregel; verwaiste Uploads nach einem Tag |

Nicht erhoben:

- Standortdaten
- private Telefonnummern
- Kontakte
- Patientendokumentation

Ankündigungen und ihre Anhänge dürfen keine Patientendokumentation oder andere
medizinische Falldaten enthalten. Die Schule muss dafür eine Aufbewahrungs- und
Moderationsregel festlegen.

## Löschkonzept

- `mark-deletion` setzt `status = pending_deletion` und `permanent_deletion_due_at = now + 30 days`.
- Sitzungen und Push-Tokens werden sofort widerrufen.
- Die endgültige Löschung/anonymisierte historische Aufbewahrung sollte als separater Wartungsjob ergänzt werden, sobald die schulische Aufbewahrungsregel feststeht.
