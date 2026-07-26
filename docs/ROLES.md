# Rollen- und Berechtigungsmatrix

| Funktion | Schulsanitäter | Sani-Leitung | Lehreraufsicht | Sekretariat |
| --- | --- | --- | --- | --- |
| Dienstplan ansehen | Ja | Ja | Ja | Ja |
| Vergangenheit ansehen | Angezeigte Dienste | Vollständig | Vollständig | Vollständig |
| Sich selbst eintragen/austragen/krankmelden | Ja | Ja | Nein | Nein |
| Andere Sanis eintragen/entfernen | Nein | Ja | Ja | Nein |
| Diensttage anlegen/bearbeiten/zurücksetzen | Nein | Ja | Ja | Nein |
| Ferien/Ausfalltage eintragen/aufheben | Nein | Ja | Ja | Nein |
| Ankündigungen inkl. Anhänge lesen/senden | Ja | Ja | Ja | Ja |
| Sani- und Schulpersonal-Liste sehen | Ja | Ja | Ja | Ja |
| Fremde Detailprofile öffnen | Nein | Ja | Ja | Nein |
| Dienststatistik im eigenen Profil | Ja | Ja | Nein | Nein |
| Dienststatistik anderer sehen | Nein | Nur Sanis | Nur Sanis | Nein |
| Accounts erstellen | Nein | Nur Sanis | Alle Rollen | Nein |
| Accounts deaktivieren/reaktivieren | Nein | Ja | Ja | Nein |
| Accounts zur Löschung vormerken | Nein | Ja | Ja | Nein |
| Datenauskunft für Accounts erzeugen | Nein | Ja | Ja | Nein |
| Rolle Sani ↔ Sani-Leitung ändern | Nein | Ja | Ja | Nein |
| Lehrer-/Sekretariatsrolle ändern | Nein | Nein | Nein | Nein |
| Eigene Geräte und Cloud-Dateien verwalten | Ja | Ja | Ja | Ja |
| Darstellung ändern | Ja | Ja | Ja | Ja |

Serverseitige Regeln:

- Jede geschützte Route validiert die Sitzung.
- Jede Datenabfrage ist auf `school_id` begrenzt.
- Rollenregeln werden in Services geprüft, nicht nur in Flutter.
- Lehrer- und Sekretariatsaccounts können nicht als Sanis in Dienste eingetragen werden.
- Selbst-Rollenwechsel ist gesperrt. Lehreraufsicht und Sani-Leitung können nur
  bestehende Sanis zwischen Schulsanitäter und Sani-Leitung umstellen.
- Lehrer- und Sekretariatsrollen können im Sani-Profil nicht vergeben,
  entfernt oder umgewandelt werden.
- Neue Sani-/Leitungsaccounts benötigen ein später unveränderliches
  `Sanitäter seit`-Datum.
- Ausfalltage können nicht belegt werden. Bereits belegte Tage müssen vor dem Schließen geleert werden.
- Ankündigungsanhänge sind nur mit gültiger Sitzung innerhalb der eigenen Schule abrufbar.
- Eigene Anhänge unterliegen einer serverseitigen 100-MB-Quote und können nur
  vom Uploader in dessen Speicherverwaltung gelöscht werden.
- Aktive Schulsanitäter werden blau und aktive Sani-Leitung grün markiert.
  Deaktivierte Accounts erscheinen ohne öffentlichen Aktiv-Text ausschließlich
  für Lehreraufsicht und Sani-Leitung in einem getrennten Abschnitt am
  Listenende.
- Das Deaktivieren oder Vormerken zur Löschung widerruft alle aktiven Sitzungen
  des betroffenen Accounts sofort.
- Nach 30 Tagen anonymisiert der Wartungsjob fällige Accounts, entfernt
  Geräte-/Token-/Dateidaten und erhält historische Dienste und Nachrichtentexte
  unter `Gelöschter Nutzer`. Eine Reaktivierung innerhalb der Frist hebt die
  Fälligkeit vollständig auf.
