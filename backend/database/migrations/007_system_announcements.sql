ALTER TABLE announcements
  ADD COLUMN message_type ENUM('user', 'system') NOT NULL DEFAULT 'user' AFTER message,
  ADD COLUMN system_type VARCHAR(80) NULL AFTER message_type;

CREATE INDEX idx_announcements_school_type_created
  ON announcements (school_id, message_type, created_at);
