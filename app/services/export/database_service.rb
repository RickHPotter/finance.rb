# frozen_string_literal: true

require "net/protocol"
require "open3"
require "shellwords"
require "zlib"

module Export
  class DatabaseService
    DB_CONFIG = Rails.configuration.database_configuration[Rails.env]["primary"]
    BACKUP_EMAIL_MAX_ATTACHMENT_BYTES = ENV.fetch("DB_BACKUP_EMAIL_MAX_ATTACHMENT_BYTES", 18.megabytes).to_i

    def self.backup
      new.backup
    end

    def self.restore(sql_file)
      Rails.logger.info "Restoring DB '#{DB_CONFIG['database']}' from #{sql_file}..."

      new.restore(sql_file)

      Rails.logger.info "✅ Restore complete!"
    end

    def backup
      file_path, compressed_file_path = backup_paths
      File.binwrite(file_path, dump_database)
      compress_backup(file_path:, compressed_file_path:)

      Rails.logger.info "✅ Backup saved to #{file_path}"
      Rails.logger.info "✅ Compressed backup saved to #{compressed_file_path}"

      deliver_backup_email(sql_file_path: file_path, compressed_file_path:)
    end

    def restore(sql_file)
      sql_file = File.expand_path(sql_file)
      raise "File not found: #{sql_file}" unless File.exist?(sql_file)

      ENV["PGPASSWORD"] = DB_CONFIG["password"].to_s if DB_CONFIG["password"]

      drop_db
      create_db
      populate_db(sql_file)
    end

    private

    def backup_paths
      timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
      file_path = Rails.root.join("tmp", "backup_#{timestamp}.sql")

      [ file_path, Pathname.new("#{file_path}.gz") ]
    end

    def dump_database
      ENV["PGPASSWORD"] ||= DB_CONFIG["password"].to_s

      stdout, stderr, status = Open3.capture3(ENV.to_h, *pg_dump_command)

      return stdout if status.success?

      Rails.logger.error("Backup failed: #{stderr.presence || stdout}")
      raise "pg_dump failed with status #{status.exitstatus}"
    end

    def pg_dump_command
      [
        "pg_dump",
        "--inserts",
        "--column-inserts",
        "-h", DB_CONFIG["host"].to_s,
        "-p", DB_CONFIG["port"].to_s,
        "-U", DB_CONFIG["username"].to_s,
        DB_CONFIG["database"].to_s
      ]
    end

    def compress_backup(file_path:, compressed_file_path:)
      Zlib::GzipWriter.open(compressed_file_path) do |gzip|
        File.open(file_path, "rb") do |sql_file|
          IO.copy_stream(sql_file, gzip)
        end
      end
    end

    def deliver_backup_email(sql_file_path:, compressed_file_path:)
      skipped_attachment_reason = attachment_skip_reason_for(compressed_file_path)
      attachment_file_path = skipped_attachment_reason.present? ? nil : compressed_file_path.to_s

      BackupMailer.send_backup(
        backup_file_path: sql_file_path.to_s,
        attachment_file_path:,
        skipped_attachment_reason:
      ).deliver_now

      Rails.logger.info("✅ Email sent#{' without attachment' if skipped_attachment_reason.present?}!")
    rescue Net::OpenTimeout, Net::ReadTimeout => e
      Rails.logger.error("Backup email timed out after backup creation: #{e.class}: #{e.message}")
    end

    def attachment_skip_reason_for(file_path)
      return if File.size(file_path) <= BACKUP_EMAIL_MAX_ATTACHMENT_BYTES

      Rails.logger.warn(
        "Skipping DB backup email attachment because #{file_path} exceeds #{BACKUP_EMAIL_MAX_ATTACHMENT_BYTES} bytes"
      )

      "attachment_too_large"
    end

    def drop_db
      system("dropdb",
             "-h", DB_CONFIG["host"],
             "-p", DB_CONFIG["port"].to_s,
             "-U", DB_CONFIG["username"],
             DB_CONFIG["database"])
    end

    def create_db
      system("createdb",
             "-h", DB_CONFIG["host"],
             "-p", DB_CONFIG["port"].to_s,
             "-U", DB_CONFIG["username"],
             DB_CONFIG["database"])
    end

    def populate_db(sql_file_path)
      return populate_db_from_gzip(sql_file_path) if File.extname(sql_file_path) == ".gz"

      run_system_command!(
        "psql",
        "-h", DB_CONFIG["host"],
        "-p", DB_CONFIG["port"].to_s,
        "-U", DB_CONFIG["username"],
        "-d", DB_CONFIG["database"],
        "-f", sql_file_path
      )
    end

    def populate_db_from_gzip(sql_file_path)
      stdout, stderr, status = Open3.capture3(
        ENV.to_h,
        "sh",
        "-lc",
        "gunzip -c #{Shellwords.escape(sql_file_path)} | " \
        "psql -h #{Shellwords.escape(DB_CONFIG['host'].to_s)} " \
        "-p #{Shellwords.escape(DB_CONFIG['port'].to_s)} " \
        "-U #{Shellwords.escape(DB_CONFIG['username'].to_s)} " \
        "-d #{Shellwords.escape(DB_CONFIG['database'].to_s)}"
      )

      return if status.success?

      Rails.logger.error("Restore failed: #{stderr.presence || stdout}")
      raise "psql restore failed with status #{status.exitstatus}"
    end

    def run_system_command!(*cmd)
      success = system(*cmd)
      return if success

      raise "#{cmd.first} failed"
    end
  end
end
