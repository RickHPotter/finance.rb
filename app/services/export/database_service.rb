# frozen_string_literal: true

module Export
  class DatabaseService
    DB_CONFIG = Rails.configuration.database_configuration[Rails.env]["primary"]

    def self.backup
      new.backup
    end

    def self.restore(sql_file)
      Rails.logger.info "Restoring DB '#{DB_CONFIG['database']}' from #{sql_file}..."

      new.restore(sql_file)

      Rails.logger.info "✅ Restore complete!"
    end

    def backup
      timestamp = Time.now.strftime("%Y%m%d_%H%M%S")
      file_path = Rails.root.join("tmp", "backup_#{timestamp}.sql")

      cmd = [
        "pg_dump",
        "--inserts",
        "--column-inserts",
        "-h", DB_CONFIG["host"].to_s,
        "-p", DB_CONFIG["port"].to_s,
        "-U", DB_CONFIG["username"].to_s,
        DB_CONFIG["database"].to_s
      ]

      ENV["PGPASSWORD"] ||= DB_CONFIG["password"].to_s

      File.open(file_path, "w") do |file|
        IO.popen(cmd, err: %i[child out]) do |io|
          file.write(io.read)
        end
      end

      Rails.logger.info "✅ Backup saved to #{file_path}"

      BackupMailer.send_backup(file_path:).deliver_now

      Rails.logger.info "✅ Email sent!"
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
      system("psql",
             "-h", DB_CONFIG["host"],
             "-p", DB_CONFIG["port"].to_s,
             "-U", DB_CONFIG["username"],
             "-d", DB_CONFIG["database"],
             "-f", sql_file_path)
    end
  end
end
