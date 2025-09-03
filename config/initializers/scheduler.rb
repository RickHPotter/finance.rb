require "rufus-scheduler"

scheduler = Rufus::Scheduler.singleton

if Rails.env.production?
  scheduler.cron "0 0 * * *" do
    Rails.logger.info "Running daily backup job"

    Export::DatabaseService.backup
  end

  scheduler.cron "0 9 * * *" do
    Rails.logger.info "Running daily due payment notifier"

    DuePaymentsNotifier.new.call
  end

  scheduler.cron "0 17 * * *" do
    Rails.logger.info "Running nightly due payment notifier"

    DuePaymentsNotifier.new.call
  end
end
