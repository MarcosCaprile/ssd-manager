# Rollen- und Berechtigungsmatrix

| Funktion | Schulsanitäter | Sani-Leitung | Lehreraufsicht |
| --- | --- | --- | --- |
| Dienstplan ansehen | Ja | Ja | Ja |
| Vergangenheit ansehen | Eigene/angezeigte Dienste | Vollständig | Vollständig |
| Sich selbst eintragen | Ja | Ja | Nein |
| Sich regulär austragen > 48h | Ja | Ja | Nein |
| Sich krankmelden < 48h | Ja | Ja | Nein |
| Andere Sanis eintragen | Nein | Ja | Ja |
| Andere Sanis entfernen | Nein | Ja | Ja |
| Ankündigungen lesen/senden | Ja | Ja | Ja |
| Sani-Liste sehen | Ja | Ja | Ja |
| Fremde Detailprofile öffnen | Nein | Ja | Ja |
| Dienststatistik anderer sehen | Nein | Ja | Ja |
| Accounts erstellen | Nein | Nur Sanis | Ja |
| Accounts deaktivieren/reaktivieren | Nein | Ja | Ja |
| Accounts zur Löschung vormerken | Nein | Ja | Ja |
| Sani-Leitungsrolle vergeben/entfernen | Nein | Nein | Ja |
| Lehrerrolle vergeben | Nein | Nein | Ja |
| Eigene Geräte verwalten | Ja | Ja | Ja |
| Alle anderen eigenen Geräte abmelden | Ja | Ja | Ja |

Serverseitige Regeln:

- Jede geschützte Route validiert die Sitzung.
- Jede Datenabfrage ist auf `school_id` begrenzt.
- Rollenregeln werden in Services geprüft, nicht nur in Flutter.
- Lehreraccounts können nicht als Sanis in Dienste eingetragen werden.
- Die Sani-Leitung kann sich keine zusätzliche Rolle vergeben und keine Leitungs-/Lehrerrolle vergeben.
- Rollenwechsel ist auf Lehreraufsicht beschränkt; Selbst-Rollenwechsel ist gesperrt.
