# SSD Manager Website

Statische, ohne Build-Schritt veröffentlichbare Website für
`https://ssd-manager.minutmate.com`.

Den **Inhalt** dieses Ordners in den Webroot der SSD-Manager-Subdomain bei
All-Inkl hochladen. Nicht den übergeordneten Projektordner und keine internen
Dokumente, Secrets oder Konfigurationsdateien hochladen.

Danach mindestens diese Pfade per HTTPS prüfen: `/`, `/impressum/`,
`/datenschutz/`, `/nutzungsbedingungen/`, `/support/`, `/konto-loeschen/`,
`/avv/`, `/toms/`, `/unterauftragnehmer/` und `/loeschkonzept/`.

Die HTML-Rechtsseiten und Word-Downloads werden mit
`generate_legal_pages.py` aus den geprüften DOCX-Fassungen neu erzeugt. Nach
einer Änderung immer beides gemeinsam veröffentlichen.
