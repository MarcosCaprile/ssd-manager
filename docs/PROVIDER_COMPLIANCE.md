# Anbieter- und Vertragsnachweise

Stand: 2026-07-26

## Herkunft und Ablage

Die für StudyConnect abgelegten Vertrags- und Anbieternachweise wurden als
Ausgangspunkt geprüft. Unterzeichnete Kopien, Vertrags-PDFs, Kontodaten und
native Firebase-Konfiguration bleiben außerhalb dieses öffentlichen
Repositories. Sie werden in der nicht öffentlichen Vertragsakte von MinutMate
geführt und für SSD Manager nur verwendet, wenn Vertragspartner, Konto,
Leistung und aktueller Vertragsstand tatsächlich übereinstimmen.

Die StudyConnect-Texte sind keine automatische Freigabe für SSD Manager. Vor
dem ersten Schulvertrag wird jeder Nachweis mit dem SSD-Manager-Produktionskonto
und der realen Datenverarbeitung abgeglichen.

## Aktive Anbieter von SSD Manager

### Railway Corporation

- Leistung: PHP-/Apache-API und Railway MySQL.
- Verarbeitete Daten: sämtliche Account-, Schul-, Dienstplan-, Ankündigungs-,
  Anhangs-, Sitzungs-, Push-, Audit- und Sicherheitsdaten.
- konfigurierte Region: EU West, Amsterdam, für API und MySQL.
- vorhandener Nachweis: Railway Data Processing Addendum einschließlich
  Regelungen zu internationalen Übermittlungen befindet sich in der
  nicht öffentlichen MinutMate-Vertragsakte.
- vor Freigabe erneut prüfen: Zuordnung zum verwendeten Railway-Konto,
  aktuelle DPA-Fassung, aktuelle Unterauftragnehmer, tatsächliche Regionen,
  Backup-/Restore-Region und Löschmöglichkeiten.

### Google Cloud / Firebase

- Leistung: Firebase Cloud Messaging und APNs-Anbindung; SSD Manager verwendet
  Firebase nicht als Datei- oder Datenbankspeicher.
- verarbeitete Daten: Firebase-/APNs-Gerätetoken, technische Push-Metadaten,
  Nachrichtentitel/-vorschau und Routingdaten. Keine Anhänge und keine
  Patientendokumentation.
- vorhandener Nachweis: Google Cloud Data Processing Addendum befindet sich in
  der nicht öffentlichen MinutMate-Vertragsakte.
- Standort: Die eigentliche App-Datenbank liegt nicht bei Google. FCM ist ein
  globaler Zustelldienst; eine ausschließlich europäische Verarbeitung darf
  nicht allein aus einer gewählten Firebase-Projektregion abgeleitet werden.
- vor Freigabe erneut prüfen: aktuelles Google-Vertragswerk,
  Unterauftragnehmer, Transfergrundlage, projektbezogene Kontozuordnung und
  Minimierung der Push-Inhalte.

### Apple Inc.

- Leistung: App-Store-Verteilung, APNs-Zustellung und Entwicklerkonto.
- verarbeitete Daten: Entwickler-/Storeinformationen, Geräte-/Push-Token,
  Zustell- und Diagnosedaten nach Apple-Vertragswerk.
- Rolle: je Verarbeitung gesondert bewerten; Apple ist nicht pauschal als
  Unterauftragsverarbeiter für sämtliche App-Daten darzustellen.
- vor Freigabe prüfen: aktuelles Apple Developer Agreement, App-Store-
  Datenschutzangaben, APNs-Dokumentation und Transferinformationen.

### Google Play

- Leistung: Android-App-Verteilung, Storeprüfung und Plattformdiagnose.
- verarbeitete Daten: Entwickler-/Storeinformationen und von Google erhobene
  Verteilungs-/Diagnosedaten; keine SSD-Manager-Inhaltsdaten durch den
  Storeupload selbst.
- Rolle: je Verarbeitung gesondert bewerten; nicht pauschal als
  Unterauftragsverarbeiter der Schuldaten behandeln.
- vor Freigabe prüfen: aktuelles Developer Distribution Agreement,
  Data-Safety-Erklärung und tatsächlich aktivierte Diagnosedaten.

### GitHub

- Leistung: private/öffentliche Quellcodeverwaltung und Railway-
  Deploymentintegration.
- verarbeitete Daten: Quellcode und technische Deployment-Metadaten; keine
  echten Schuldaten, Anhänge, Datenbankkopien oder Produktions-Secrets.
- Einordnung: Entwicklungsdienst, nicht Unterauftragsverarbeiter für reguläre
  Schuldaten, solange diese Abgrenzung technisch eingehalten wird.

## Nicht aus StudyConnect übernommen

ALL-INKL, Vercel, Resend und Firebase Storage werden nicht als aktive
SSD-Manager-Anbieter aufgeführt, weil SSD Manager diese Leistungen derzeit
nicht nutzt. StudyConnect-spezifische Aussagen zu Chatverschlüsselung,
Web-Cookies, E-Mail-Versand, FTPS-Backups, privaten Chats, Moderation und
Firebase-Dateispeicherung gelten ebenfalls nicht für SSD Manager.

## Änderungsprozess

1. Anbieter oder neue Leistung vor dem Einsatz erfassen.
2. Rolle, Datenarten, Zweck, Region, Aufbewahrung und Transfergrundlage prüfen.
3. AVV/DPA und aktuelle Unterauftragnehmernachweise in der Vertragsakte
   ablegen.
4. technische Konfiguration gegen die Dokumentation testen.
5. Vertragsschulen nach dem vereinbarten Änderungsverfahren informieren.
6. Datenschutzerklärung, AVV-Anlage, TOM und Storeangaben aktualisieren.

## Freigabestatus

Die vorhandenen StudyConnect-Nachweise reduzieren den Beschaffungsaufwand,
ersetzen aber nicht den kontobezogenen SSD-Manager-Abgleich. Bis dieser Abgleich
und eine externe rechtliche Prüfung abgeschlossen sind, sind AVV,
Datenschutzerklärung und Unterauftragnehmerliste SSD-Manager-Prüffassungen und
keine rechtsverbindliche Endfassung.
