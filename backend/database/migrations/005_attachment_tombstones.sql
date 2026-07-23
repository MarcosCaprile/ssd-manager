ALTER TABLE announcement_attachments
  MODIFY content LONGBLOB NULL,
  ADD COLUMN deleted_at TIMESTAMP NULL DEFAULT NULL AFTER created_at;

CREATE INDEX idx_announcement_attachments_deleted
  ON announcement_attachments (school_id, announcement_id, deleted_at);
