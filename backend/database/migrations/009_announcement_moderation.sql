ALTER TABLE announcements
  ADD COLUMN moderated_at TIMESTAMP NULL DEFAULT NULL AFTER system_type,
  ADD COLUMN moderated_by_user_id BIGINT UNSIGNED NULL AFTER moderated_at,
  ADD COLUMN moderation_reason VARCHAR(40) NULL AFTER moderated_by_user_id,
  ADD CONSTRAINT fk_announcements_moderator
    FOREIGN KEY (moderated_by_user_id) REFERENCES users(id) ON DELETE SET NULL;

CREATE TABLE IF NOT EXISTS announcement_reports (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  school_id BIGINT UNSIGNED NOT NULL,
  announcement_id BIGINT UNSIGNED NOT NULL,
  reporter_user_id BIGINT UNSIGNED NOT NULL,
  reason VARCHAR(40) NOT NULL,
  details VARCHAR(500) NULL,
  status ENUM('open', 'resolved', 'dismissed') NOT NULL DEFAULT 'open',
  resolution_action VARCHAR(40) NULL,
  resolved_by_user_id BIGINT UNSIGNED NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  resolved_at TIMESTAMP NULL DEFAULT NULL,
  CONSTRAINT fk_announcement_reports_school
    FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE RESTRICT,
  CONSTRAINT fk_announcement_reports_announcement
    FOREIGN KEY (announcement_id) REFERENCES announcements(id) ON DELETE CASCADE,
  CONSTRAINT fk_announcement_reports_reporter
    FOREIGN KEY (reporter_user_id) REFERENCES users(id) ON DELETE RESTRICT,
  CONSTRAINT fk_announcement_reports_resolver
    FOREIGN KEY (resolved_by_user_id) REFERENCES users(id) ON DELETE SET NULL,
  UNIQUE KEY uq_announcement_reports_reporter (announcement_id, reporter_user_id),
  KEY idx_announcement_reports_school_status_created (school_id, status, created_at),
  KEY idx_announcement_reports_announcement_status (announcement_id, status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
