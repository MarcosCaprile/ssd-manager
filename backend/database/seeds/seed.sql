INSERT INTO schools (id, name, slug, active)
VALUES (1, 'Beispielschule', 'beispielschule', 1)
ON DUPLICATE KEY UPDATE name = VALUES(name), active = VALUES(active);

-- Local demo password for every seeded account: password
-- Replace these accounts before production use. New real accounts are created with Argon2id by the API.
INSERT INTO users
  (id, school_id, first_name, last_name, username, email, password_hash, role, status, must_change_password)
VALUES
  (1, 1, 'Lena', 'Muster', 'lehrer', 'lehrer@example.edu', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'teacher', 'active', 1),
  (2, 1, 'Mia', 'Leitung', 'leitung', 'leitung@example.edu', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'sani_leitung', 'active', 1),
  (3, 1, 'Noah', 'Sani', 'noah', 'noah@example.edu', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'sanitaeter', 'active', 1),
  (4, 1, 'Emma', 'Hilfe', 'emma', 'emma@example.edu', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'sanitaeter', 'active', 1)
ON DUPLICATE KEY UPDATE
  first_name = VALUES(first_name),
  last_name = VALUES(last_name),
  role = VALUES(role),
  status = VALUES(status);

INSERT INTO duty_days (school_id, duty_date, capacity, is_active)
VALUES
  (1, CURRENT_DATE + INTERVAL 1 DAY, 3, 1),
  (1, CURRENT_DATE + INTERVAL 2 DAY, 3, 1),
  (1, CURRENT_DATE + INTERVAL 3 DAY, 3, 1)
ON DUPLICATE KEY UPDATE capacity = VALUES(capacity), is_active = VALUES(is_active);

INSERT INTO announcements (school_id, sender_user_id, message)
VALUES (1, 1, 'Willkommen im SSD Manager. Bitte ändert beim ersten Login euer Startpasswort.');
