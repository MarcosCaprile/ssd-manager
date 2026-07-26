const gallery = document.querySelector('#screenshot-gallery');
const shots = [
  ['dienstplan.png', 'Dienstplan', 'Dienste und Verfügbarkeiten übersichtlich verwalten.'],
  ['ankuendigungen.png', 'Ankündigungen', 'Schulweite Informationen und Dateien an einem Ort.'],
  ['team.png', 'Team', 'Rollen, Profile und Zuständigkeiten klar organisiert.'],
];
if (gallery) {
  gallery.innerHTML = shots.map(([file, title, text]) => `<figure class="shot"><img src="/assets/screenshots/${file}" alt="SSD Manager – ${title}"><figcaption><strong>${title}</strong><br>${text}</figcaption></figure>`).join('');
}
