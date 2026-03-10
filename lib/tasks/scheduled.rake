# frozen_string_literal: true

def with_advisory_lock(lock_id)
  ActiveRecord::Base.connection_pool.with_connection do |connection|
    acquired = connection.select_value("SELECT pg_try_advisory_lock(#{lock_id.to_i})")
    yield if acquired.in?([ true, "t" ])
  ensure
    connection.execute("SELECT pg_advisory_unlock(#{lock_id.to_i})") if [ true, "t" ].include?(acquired)
  end
end

namespace :scheduled do
  desc "Run daily recalculation and database backup"
  task daily_backup: :environment do
    with_advisory_lock(111_111_111) do
      Rails.logger.info "[scheduled:daily_backup] started"

      User.find_each do |user|
        RecalculateBalanceJob.perform_now(user:)
      end

      DbBackupJob.perform_now
      Rails.logger.info "[scheduled:daily_backup] completed"
    end
  end

  desc "Send due payments notifications"
  task due_payments: :environment do
    with_advisory_lock(222_222_222) do
      Rails.logger.info "[scheduled:due_payments] started"
      DuePaymentsNotifier.new.call
      Rails.logger.info "[scheduled:due_payments] completed"
    end
  end
end
