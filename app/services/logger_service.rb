# frozen_string_literal: true

class LoggerService
  def self.log_with(message = "")
    Rails.logger.info [ "[START]".purple, message.blue ].join(" ")

    yield if block_given?

    Rails.logger.info [ "[ENDED]".purple, message.green ].join(" ")
    Rails.logger.error [ "=======", "=" * message.length ].join(" ")
  end
end
