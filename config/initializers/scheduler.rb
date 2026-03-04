require "rufus-scheduler"

return if Rails.env.development?
return if defined?(Rails::Console)
return if File.basename($PROGRAM_NAME) == "rake"

# Add this at the TOP of the file
File.open("log/scheduler_debug.log", "a") do |f|
  f.puts "--- Scheduler Loading in PID: #{Process.pid} at #{Time.now} ---"
end

scheduler = Rufus::Scheduler.new(lockfile: File.join(Rails.root, "tmp", ".rufus-scheduler.lock"))

Rails.logger.info("Scheduler leader active in pid=#{Process.pid}")

scheduler.cron "0 0 * * *" do
  User.find_each do |user|
    RecalculateBalanceJob.perform_now(user:)
  end

  DbBackupJob.perform_now
end

scheduler.cron "0 9 * * *" do
  Rails.logger.info "Running daily due payment notifier"
  DuePaymentsNotifier.new.call
end

scheduler.cron "0 17 * * *" do
  Rails.logger.info "Running nightly due payment notifier"
  DuePaymentsNotifier.new.call
end
