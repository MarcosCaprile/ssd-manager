# SSD Manager Backup and Recovery

## Production design

- All-Inkl KAS calls `GET /api/v1/ops/backup/run?secret=...` once daily.
- Railway creates a transaction-consistent MySQL dump, compresses it, and
  encrypts it with authenticated XChaCha20-Poly1305 encryption.
- A dedicated, restricted All-Inkl FTPS account receives only the encrypted
  `.sql.gz.enc` file and its checksum manifest.
- Remote backup files older than 30 days are deleted during each successful
  run. Database run records older than 90 days are also removed.
- The encryption key must be retained outside All-Inkl. Losing that key makes
  every backup unrecoverable.

## Daily verification

KAS must report a successful HTTP invocation. The protected status endpoint
returns the most recent run state, timestamps, filename, size, and a generic
failure code without exposing credentials or database contents.

## Restore drill

1. Download one encrypted backup and its manifest from the dedicated All-Inkl
   FTP account.
2. Compare the downloaded file's SHA-256 value and byte count with the
   manifest.
3. In a secure local environment, expose `BACKUP_ENCRYPTION_KEY_BASE64` and run:

   ```bash
   php backend/scripts/decrypt_backup.php backup.sql.gz.enc restore.sql.gz
   gzip -t restore.sql.gz
   gunzip -c restore.sql.gz | mysql --host=HOST --user=USER --password DATABASE
   ```

4. Restore only into an empty, isolated test database. Run the migration status
   check and application smoke tests against that database.
5. Delete the downloaded and decrypted files after the drill.

Perform one drill immediately after production setup, after material schema or
backup-format changes, and at least every six months. A production restore must
be authorized by the controller and must never overwrite the live database as
an initial validation step.
