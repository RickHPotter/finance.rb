# frozen_string_literal: true

class BackupMailer < ApplicationMailer
  default to: "luisfla55@gmail.com"

  def send_backup
    file_path = params[:file_path]
    attachments[File.basename(file_path)] = File.read(file_path)
    mail(subject: "Database Backup - #{Time.zone.now.strftime('%Y-%m-%d %H:%M')}") do |format|
      format.text { render plain: "Attached is the latest database backup." }
    end
  end
end
