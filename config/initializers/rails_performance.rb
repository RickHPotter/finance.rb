if defined?(RailsPerformance)
  RailsPerformance.setup do |config|
    config.duration = 24.hours
    config.mount_at = "/monitor"

    # config.http_basic_authentication_enabled   = false
    # config.http_basic_authentication_user_name = "rails_performance"
    # config.http_basic_authentication_password  = "password12"

    config.verify_access_proc = proc { |controller| controller.current_user && controller.current_user.admin? }

    config.ignored_paths = [ "/rails/performance", "/monitor" ]

    # You can ignore endpoints with Rails standard notation controller#action
    # config.ignored_endpoints = ['HomeController#contact']

    # config home button link
    config.home_link = "/"

    # To skip some Rake tasks from monitoring
    config.skipable_rake_tasks = [ "webpacker:compile" ]

    # To monitor rake tasks performance, you need to include rake tasks
    # config.include_rake_tasks = false

    # To monitor custom events with `RailsPerformance.measure` block
    # config.include_custom_events = true

    # To monitor system resources (CPU, memory, disk)
    # to enabled add required gems (see README)
    # config.system_monitor_duration = 24.hours
  end
end
