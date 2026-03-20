require_relative "production"

Rails.application.configure do
  config.log_tags = [ :request_id, "homolog" ]

  config.action_mailer.default_url_options = {
    host: ENV.fetch("APP_HOST", "homolog.30fev.com"),
    protocol: "https"
  }
  config.action_mailer.delivery_method = :test
  config.action_mailer.perform_deliveries = false
  config.action_mailer.raise_delivery_errors = false
end
