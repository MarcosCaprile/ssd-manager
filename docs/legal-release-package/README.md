# SSD Manager Datenschutz- und Vertragsunterlagen

Dieser Ordner enthält bearbeitbare Word-Prüffassungen für den öffentlichen
Vertrieb von SSD Manager an Schulen. Die Dokumente sind auf den tatsächlichen
SSD-Manager-Funktionsumfang zugeschnitten und nicht nur aus StudyConnect
umbenannt.

## Ordner

- `word/`: bearbeitbare DOCX-Dateien.
- `provider-evidence-private/`: lokale, von Git ausgeschlossene Kopien der
  vorhandenen DPA-/AVV-Nachweise für aktive SSD-Manager-Dienstleister.
- `qa/`: lokale Renderbilder für die Dokumentenprüfung; von Git ausgeschlossen.

## Rechtlicher Status

Die Dokumente sind Arbeits- und Prüffassungen. Vor der Verarbeitung echter
Schuldaten müssen die Schule beziehungsweise der Schulträger, deren
Datenschutzbeauftragter und eine qualifizierte Rechtsberatung die jeweils
relevanten Dokumente prüfen. Landesschulrecht und landesspezifische
Datenschutzvorgaben können nicht produktübergreifend abschließend vorgegeben
werden.

## Offizielle Ausgangsquellen

- DSGVO, insbesondere Art. 12–14, 28, 30, 32–36 und 44 ff.:
  https://eur-lex.europa.eu/eli/reg/2016/679/oj
- § 5 Digitale-Dienste-Gesetz:
  https://www.gesetze-im-internet.de/ddg/__5.html
- EDPB Guidelines 07/2020 zu Verantwortlichen und Auftragsverarbeitern:
  https://www.edpb.europa.eu/our-work-tools/our-documents/guidelines/guidelines-072020-concepts-controller-and-processor-gdpr_en
- DSK-Orientierungshilfe zu Online-Lernplattformen:
  https://www.bfdi.bund.de/SharedDocs/Downloads/DE/DSK/Orientierungshilfen/OH_OnlineLernplattformen.pdf

## Aktualisierung

Nach inhaltlichen Änderungen `build_legal_package.py` mit dem gebündelten
Workspace-Python ausführen und danach sämtliche DOCX-Dateien erneut rendern und
visuell prüfen. Veröffentlichte Fassungen erhalten eine eindeutige Version und
ein Freigabedatum.
