# frozen_string_literal: true

class BackupMailer < ApplicationMailer
  default to: "luisfla55@gmail.com"

  def send_backup(backup_file_path:, attachment_file_path: nil, skipped_attachment_reason: nil)
    attachments[File.basename(attachment_file_path)] = File.binread(attachment_file_path) if attachment_file_path.present?

    mail(subject: I18n.t("backup_mailer.send_backup.subject", timestamp: Time.current.strftime("%Y-%m-%d %H:%M"))) do |format|
      format.text do
        render plain: backup_body(
          backup_file_path:,
          attachment_file_path:,
          skipped_attachment_reason:
        )
      end
    end
  end

  private

  def backup_body(backup_file_path:, attachment_file_path:, skipped_attachment_reason:)
    if attachment_file_path.present?
      I18n.t(
        "backup_mailer.send_backup.attached_body",
        backup_file_path:,
        attachment_file_path:,
        attachment_size: ActiveSupport::NumberHelper.number_to_human_size(File.size(attachment_file_path))
      )
    else
      I18n.t(
        "backup_mailer.send_backup.skipped_attachment_body",
        backup_file_path:,
        reason: I18n.t("backup_mailer.send_backup.skip_reasons.#{skipped_attachment_reason}")
      )
    end
  end
end
