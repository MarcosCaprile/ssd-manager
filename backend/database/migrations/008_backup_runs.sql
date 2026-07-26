CREATE TABLE IF NOT EXISTS backup_runs (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  status ENUM('running', 'succeeded', 'failed') NOT NULL,
  filename VARCHAR(255) NULL,
  encrypted_bytes BIGINT UNSIGNED NULL,
  sha256 CHAR(64) NULL,
  error_code VARCHAR(80) NULL,
  started_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  finished_at TIMESTAMP NULL DEFAULT NULL,
  KEY idx_backup_runs_started (started_at),
  KEY idx_backup_runs_status (status, started_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
