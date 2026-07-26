# Datenschutz- und Betriebsprozesse

Stand: 2026-07-26

- Produktkontakt: `info@ssd-manager.minutmate.com`
- Produktsupport: `support@ssd-manager.minutmate.com`
- MinutMate-Datenschutzkontakt: `datenschutz@minutmate.com`

Dieses Dokument beschreibt den vorgesehenen Betriebsstandard. Es ersetzt keine
Prüfung durch die verantwortliche Schule, ihren Datenschutzbeauftragten oder
eine Rechtsberatung nach dem jeweils geltenden Landesrecht.

## Rollen

- Die freigeschaltete Schule beziehungsweise die nach Landesrecht zuständige
  Stelle bestimmt Zweck, Rechtsgrundlage, Nutzerkreis und Aufbewahrung und ist
  Verantwortlicher.
- Der SSD-Manager-Betreiber verarbeitet Schuldaten ausschließlich auf
  dokumentierte Weisung als Auftragsverarbeiter.
- Railway, Firebase/Google und Apple werden mit ihrer konkreten Leistung,
  Region, Vertragsgrundlage und etwaigen Drittlandgarantien im
  Unterauftragnehmerverzeichnis geführt.
- Eigene Interessenten-, Vertrags- und Supportkontakte des Betreibers sind von
  den im Auftrag verarbeiteten Schuldaten getrennt zu behandeln.

## Schul-Onboarding

1. Anfrage nur über die veröffentlichte Betreiberadresse annehmen.
2. Schule, dienstliche Domain, anfragende Person und deren Berechtigung über
   einen unabhängigen offiziellen Kontaktweg verifizieren.
3. Verantwortlichen, Datenschutzkontakt, technischen Admin und Schulträger
   erfassen.
4. Nutzungsvereinbarung, AV-Vertrag, TOM, Unterauftragnehmerliste,
   Löschkonzept und zulässige Inhalte bereitstellen und Freigabe dokumentieren.
5. Rechtsgrundlage, Rollen, historische Sichtbarkeit, Versandberechtigungen und
   erforderliche DSFA der Schule dokumentieren.
6. Isolierte Schule anlegen und Schulgrenzen technisch prüfen.
7. Erstes Lehrerkonto über getrennte Kanäle übergeben; Initialpasswort muss
   beim ersten Login geändert werden.
8. Freigabe mit Datum und verantwortlicher Person protokollieren. Keine offene
   Registrierung und keine automatische Freischaltung.

## Betroffenenrechte

Anfragen laufen an die Schule. Der Betreiber stellt dafür einen dokumentierten
Supportkanal bereit und unterstützt die Schule mit folgenden Abläufen:

- Auskunft: Identität und Berechtigung durch die Schule prüfen, dann innerhalb
  der gesetzlichen Frist eine strukturierte Kopie von Stammdaten,
  Dienstzuweisungen, eigenen Nachrichten, Dateimetadaten, Geräteinformationen
  und relevanten Auditdaten erzeugen. Daten anderer Personen werden geschützt.
- Berichtigung: Stammdaten nach bestätigter Weisung berichtigen und die Aktion
  auditieren; historische Tatsachen werden nicht still überschrieben.
- Einschränkung: Account sofort deaktivieren, Sitzungen/Push widerrufen und
  weitere nicht notwendige Verarbeitung bis zur Entscheidung sperren.
- Löschung: Lehreraufsicht oder Sani-Leitung setzt nach Schulprüfung die
  30-Tage-Vormerkung. Innerhalb der Frist kann die Schule eine irrtümliche
  Vormerkung korrigieren; danach greift die endgültige Anonymisierung.
- Widerspruch und Datenübertragbarkeit: an den Verantwortlichen weiterleiten;
  Anwendbarkeit und Umfang hängen von Rechtsgrundlage und öffentlicher Aufgabe
  ab. Technisch wird ein gängiges maschinenlesbares Exportformat bereitgestellt.
- Abschluss: Eingang, Identitätsprüfung, Entscheidung, Ausführung und Antwort
  werden ohne unnötige Inhaltskopien nachvollziehbar dokumentiert.

## Endgültige Accountverarbeitung

Nach Ablauf der 30 Tage wird transaktionssicher:

1. der Account gesperrt und jede Sitzung sowie jeder Push-Token entfernt;
2. Name, E-Mail, Benutzername, Passwort-Hash, Eintrittsdatum und direkte
   Geräte-/Accountkennzeichen entfernt oder irreversibel ersetzt;
3. aktive zukünftige Dienste beendet, während historische Zuordnungen ohne
   Personenname erhalten bleiben;
4. der Absender aller erhaltenen Nachrichtentexte als `Gelöschter Nutzer`
   dargestellt;
5. der Inhalt aller hochgeladenen Dateien gelöscht und versendete Dateien auf
   einen Metadaten-Tombstone reduziert;
6. personenbezogene Notification- und Audit-Metadaten entfernt, soweit sie
   nicht für eine laufende Sicherheitsprüfung benötigt werden;
7. der Abschluss im minimalen Löschregister ohne Name, E-Mail oder
   Nachrichteninhalt festgehalten.

Erhalten bleiben nur nicht mehr direkt personenbezogene Dienst- und
Gesprächsstrukturen sowie minimale technische Nachweise. Freitext kann trotz
entferntem Absender weitere personenbezogene Angaben enthalten; deshalb gelten
Inhaltsregeln, Moderation und die jährliche Erforderlichkeitsprüfung weiterhin.

## Aufbewahrung und Backups

- Nachrichtentexte: Laufzeit der aktiven Schulumgebung, mindestens jährliche
  dokumentierte Erforderlichkeitsprüfung; Löschung bei Vertragsende.
- Anhänge: bis zur Löschung des Uploaders oder Vertragsende.
- Unbeanspruchte Uploads: ein Tag.
- Geräte/Sitzungen/Push: nur solange aktiv beziehungsweise bis Widerruf.
- Loginversuche: 90 Tage.
- technische Notification-Logs: 90 Tage.
- Audit-Logs: 12 Monate, außer ein offener Sicherheitsfall erfordert eine
  dokumentierte befristete Sicherung.
- verschlüsselte Backups: täglich, rollierend höchstens 30 Tage; Zugriff nur
  für Wiederherstellung, Wiederherstellungstest mindestens halbjährlich.
- Bei Restore werden Löschregister und seit Sicherungszeitpunkt vollzogene
  Löschungen vor Produktivfreigabe erneut angewendet.

## Sicherheitsbetrieb

- Produktionszugriffe nach Minimalprinzip und mit Mehrfaktor-Authentifizierung;
  administrative Berechtigungen mindestens vierteljährlich prüfen.
- Verfügbarkeit, Healthcheck, Fehlerquote, Backup-Erfolg, Speicherwachstum und
  Cron-Ausführung überwachen; Secrets oder personenbezogene Payloads nicht in
  zentrale Logs schreiben.
- Kritische Updates zeitnah, Abhängigkeiten regelmäßig und Berechtigungs- sowie
  Schulgrenzentests bei sicherheitsrelevanten Änderungen prüfen.
- Sicherheitsmeldung unverzüglich intern erfassen, Ausbreitung begrenzen,
  Beweise zugriffsgeschützt sichern und den betroffenen Verantwortlichen mit
  den für dessen Bewertung und Meldepflicht nötigen Fakten informieren.
- Keine eigenständige Behörden- oder Betroffenenmeldung durch den
  Auftragsverarbeiter ohne Weisung, außer eine zwingende gesetzliche Pflicht
  verlangt sie.

## DSFA-Vorprüfung

Vor jeder Schulfreigabe erhält der Verantwortliche eine Vorprüfung mit Zweck,
Datenarten, Nutzergruppen, Empfängern, Speicherfristen, Schutzmaßnahmen und
Restrisiken. Besonders bewertet werden Minderjährige, Rollen-/Historienzugriff,
Krankmeldungen, Freitext/Anhänge, Push-Metadaten, Mandantentrennung und
Missbrauch administrativer Rechte.

SSD Manager verarbeitet keine Diagnose- oder Patientendokumentation und führt
kein Profiling oder automatisierte Entscheidungen durch. Das reduziert das
Risiko, ersetzt aber nicht die Entscheidung des Verantwortlichen, ob nach Art.
35 DSGVO und den Vorgaben der zuständigen Landesaufsicht eine vollständige DSFA
erforderlich ist. Die Entscheidung und Begründung werden vor Freigabe
dokumentiert und bei wesentlichen Änderungen erneut geprüft.

## Noch erforderliche Unterlagen

Vor realem Mehrschulbetrieb müssen die tatsächlichen Railway-, Firebase-,
Apple- und Google-Verträge sowie TOMs geprüft und in ein versionsgeführtes
Unterauftragnehmerverzeichnis übertragen werden. Vertragskopien und
unterschriebene Dokumente bleiben außerhalb des öffentlichen Repositories.
Die produktspezifische Übernahmeprüfung aus der vorhandenen
StudyConnect-Vertragsakte ist in `docs/PROVIDER_COMPLIANCE.md` dokumentiert.
