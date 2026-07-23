ALTER TABLE users
  MODIFY role ENUM('sanitaeter', 'sani_leitung', 'teacher', 'sekretariat')
    NOT NULL DEFAULT 'sanitaeter',
  ADD COLUMN sanitaeter_since DATE NULL AFTER role;

CREATE INDEX idx_announcement_attachments_user_created
  ON announcement_attachments (school_id, uploaded_by_user_id, created_at);
