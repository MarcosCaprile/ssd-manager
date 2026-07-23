ALTER TABLE user_devices
  ADD COLUMN device_install_id VARCHAR(64) NULL AFTER user_id;

CREATE INDEX idx_user_devices_install_active
  ON user_devices (user_id, device_install_id, revoked_at);
