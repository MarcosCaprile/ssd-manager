CREATE TABLE IF NOT EXISTS schools (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(180) NOT NULL,
  slug VARCHAR(120) NOT NULL,
  active TINYINT(1) NOT NULL DEFAULT 1,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_schools_slug (slug)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS users (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  school_id BIGINT UNSIGNED NOT NULL,
  first_name VARCHAR(120) NOT NULL,
  last_name VARCHAR(120) NOT NULL,
  username VARCHAR(120) NOT NULL,
  email VARCHAR(180) NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  role ENUM('sanitaeter', 'sani_leitung', 'teacher') NOT NULL DEFAULT 'sanitaeter',
  status ENUM('active', 'inactive', 'pending_deletion', 'deleted') NOT NULL DEFAULT 'active',
  must_change_password TINYINT(1) NOT NULL DEFAULT 1,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deactivated_at TIMESTAMP NULL DEFAULT NULL,
  deleted_at TIMESTAMP NULL DEFAULT NULL,
  permanent_deletion_due_at TIMESTAMP NULL DEFAULT NULL,
  CONSTRAINT fk_users_school FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE RESTRICT,
  UNIQUE KEY uq_users_school_username (school_id, username),
  UNIQUE KEY uq_users_school_email (school_id, email),
  KEY idx_users_school_role_status (school_id, role, status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS user_devices (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT UNSIGNED NOT NULL,
  refresh_token_hash CHAR(64) NOT NULL,
  device_name VARCHAR(120) NOT NULL,
  platform VARCHAR(32) NOT NULL,
  device_model VARCHAR(120) NULL,
  app_version VARCHAR(40) NULL,
  firebase_token TEXT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  last_active_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  revoked_at TIMESTAMP NULL DEFAULT NULL,
  expires_at TIMESTAMP NOT NULL,
  CONSTRAINT fk_user_devices_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  UNIQUE KEY uq_user_devices_refresh_token_hash (refresh_token_hash),
  KEY idx_user_devices_user_active (user_id, revoked_at, expires_at),
  KEY idx_user_devices_last_active (last_active_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS duty_days (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  school_id BIGINT UNSIGNED NOT NULL,
  duty_date DATE NOT NULL,
  capacity TINYINT UNSIGNED NOT NULL DEFAULT 3,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_duty_days_school FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE RESTRICT,
  UNIQUE KEY uq_duty_days_school_date (school_id, duty_date),
  KEY idx_duty_days_school_date (school_id, duty_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS duty_assignments (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  duty_day_id BIGINT UNSIGNED NOT NULL,
  user_id BIGINT UNSIGNED NOT NULL,
  status ENUM('planned', 'completed', 'sick_reported', 'cancelled', 'admin_removed') NOT NULL DEFAULT 'planned',
  assigned_by_user_id BIGINT UNSIGNED NULL,
  assignment_type ENUM('self', 'sani_leitung', 'teacher') NOT NULL DEFAULT 'self',
  assigned_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  cancelled_at TIMESTAMP NULL DEFAULT NULL,
  sick_reported_at TIMESTAMP NULL DEFAULT NULL,
  completed_at TIMESTAMP NULL DEFAULT NULL,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  active_user_slot TINYINT GENERATED ALWAYS AS (
    CASE WHEN status = 'planned' THEN 1 ELSE NULL END
  ) STORED,
  CONSTRAINT fk_duty_assignments_day FOREIGN KEY (duty_day_id) REFERENCES duty_days(id) ON DELETE CASCADE,
  CONSTRAINT fk_duty_assignments_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE RESTRICT,
  CONSTRAINT fk_duty_assignments_assigned_by FOREIGN KEY (assigned_by_user_id) REFERENCES users(id) ON DELETE SET NULL,
  UNIQUE KEY uq_duty_assignments_active_user (duty_day_id, user_id, active_user_slot),
  KEY idx_duty_assignments_day_status (duty_day_id, status),
  KEY idx_duty_assignments_user_status (user_id, status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS announcements (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  school_id BIGINT UNSIGNED NOT NULL,
  sender_user_id BIGINT UNSIGNED NOT NULL,
  message TEXT NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted_at TIMESTAMP NULL DEFAULT NULL,
  CONSTRAINT fk_announcements_school FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE RESTRICT,
  CONSTRAINT fk_announcements_sender FOREIGN KEY (sender_user_id) REFERENCES users(id) ON DELETE RESTRICT,
  KEY idx_announcements_school_created (school_id, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS notification_logs (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  school_id BIGINT UNSIGNED NOT NULL,
  user_id BIGINT UNSIGNED NULL,
  notification_type VARCHAR(80) NOT NULL,
  duty_day_id BIGINT UNSIGNED NULL,
  announcement_id BIGINT UNSIGNED NULL,
  title VARCHAR(160) NOT NULL,
  body VARCHAR(500) NOT NULL,
  sent_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  delivery_status VARCHAR(40) NOT NULL,
  deduplication_key VARCHAR(180) NOT NULL,
  CONSTRAINT fk_notification_logs_school FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE RESTRICT,
  CONSTRAINT fk_notification_logs_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
  CONSTRAINT fk_notification_logs_duty_day FOREIGN KEY (duty_day_id) REFERENCES duty_days(id) ON DELETE SET NULL,
  CONSTRAINT fk_notification_logs_announcement FOREIGN KEY (announcement_id) REFERENCES announcements(id) ON DELETE SET NULL,
  UNIQUE KEY uq_notification_logs_dedupe (deduplication_key),
  KEY idx_notification_logs_school_type (school_id, notification_type, sent_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS audit_logs (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  school_id BIGINT UNSIGNED NOT NULL,
  actor_user_id BIGINT UNSIGNED NULL,
  action VARCHAR(120) NOT NULL,
  target_user_id BIGINT UNSIGNED NULL,
  target_type VARCHAR(80) NULL,
  target_id BIGINT UNSIGNED NULL,
  metadata_json JSON NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_audit_logs_school FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE RESTRICT,
  CONSTRAINT fk_audit_logs_actor FOREIGN KEY (actor_user_id) REFERENCES users(id) ON DELETE SET NULL,
  CONSTRAINT fk_audit_logs_target_user FOREIGN KEY (target_user_id) REFERENCES users(id) ON DELETE SET NULL,
  KEY idx_audit_logs_school_created (school_id, created_at),
  KEY idx_audit_logs_action (action)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS login_attempts (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  identifier VARCHAR(180) NOT NULL,
  ip_address VARCHAR(64) NOT NULL,
  success TINYINT(1) NOT NULL,
  attempted_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_login_attempts_identifier_ip_time (identifier, ip_address, attempted_at),
  KEY idx_login_attempts_cleanup (attempted_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
