require "rufus-scheduler"

return unless Rails.env.production?

module CronWithLock
  def self.run(lock_id)
    acquired = ActiveRecord::Base.connection.select_value("SELECT pg_try_advisory_lock(?)", [ lock_id ])

    return unless acquired

    yield
  ensure
    ActiveRecord::Base.connection.execute("SELECT pg_advisory_unlock(?)", [ lock_id ]) if acquired
  end
end

scheduler = Rufus::Scheduler.singleton

scheduler.cron "0 0 * * *" do
  CronWithLock.run(111_111_111) do
    Rails.logger.info "Running daily backup job"

    User.find_each do |user|
      RecalculateBalanceJob.perform_later(user:)
    end

    Export::DatabaseService.backup
  end
end

scheduler.cron "0 9 * * *" do
  CronWithLock.run(222_222_222) do
    Rails.logger.info "Running daily due payment notifier"
    DuePaymentsNotifier.new.call
  end
end

scheduler.cron "0 17 * * *" do
  CronWithLock.run(333_333_333) do
    Rails.logger.info "Running nightly due payment notifier"
    DuePaymentsNotifier.new.call
  end
end
