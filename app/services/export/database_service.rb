# frozen_string_literal: true

module Export
  class DatabaseService
    DB_CONFIG = Rails.configuration.database_configuration[Rails.env]["primary"]

    def self.backup
      new.backup
    end

    def self.restore(sql_file)
      new.restore(sql_file)
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

      BackupMailer.with(file_path:).send_backup.deliver_now

      Rails.logger.info "✅ Email sent!"
    end

    def restore(sql_file)
      sql_file = File.expand_path(sql_file)
      raise "File not found: #{sql_file}" unless File.exist?(sql_file)

      db_name = DB_CONFIG["database"]
      db_user = DB_CONFIG["username"]
      db_pass = DB_CONFIG["password"]
      db_host = DB_CONFIG["host"]
      db_port = DB_CONFIG["port"]

      Rails.logger.info "Restoring DB '#{db_name}' from #{sql_file}..."

      ENV["PGPASSWORD"] = db_pass.to_s if db_pass

      system(%[dropdb -h "#{db_host}" -p #{db_port} -U "#{db_user}" "#{db_name}"])
      system(%[createdb -h "#{db_host}" -p #{db_port} -U "#{db_user}" "#{db_name}"])
      system(%[psql -h "#{db_host}" -p #{db_port} -U "#{db_user}" -d "#{db_name}" -f "#{sql_file}"])

      Rails.logger.info "✅ Restore complete!"
    end
  end
end
