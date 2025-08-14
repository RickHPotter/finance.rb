require "rufus-scheduler"

scheduler = Rufus::Scheduler.singleton

if Rails.env.production?
  scheduler.cron "0 0 * * *" do
    Rails.logger.info "Running daily backup job"

    Export::DatabaseService.backup
  end
end
