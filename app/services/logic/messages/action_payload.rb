# frozen_string_literal: true

module Logic
  module Messages
    class ActionPayload
      NOTIFICATION_ACTIONS = %w[create update destroy].freeze
      PAID_STATE_ACTIONS = %w[paid unpaid].freeze

      attr_reader :data, :error

      def initialize(headers)
        @data = parse(headers)
        @error ||= validation_error
        deep_freeze(@data)
      end

      def valid?
        error.nil?
      end

      def version
        data["version"]
      end

      def action
        event["action"]
      end

      def event
        value = data["event"]
        value.is_a?(Hash) ? value : {}
      end

      def replay
        version == "message_notification_v2" ? data["replay"] : data
      end

      private

      def parse(headers)
        return {} if headers.blank?

        parsed = JSON.parse(headers)
        return parsed if parsed.is_a?(Hash)

        @error = :payload_not_an_object
        {}
      rescue JSON::ParserError
        @error = :malformed_json
        {}
      end

      def validation_error
        case version
        when nil then nil
        when "message_notification_v2" then notification_validation_error
        when "message_paid_state_v1" then paid_state_validation_error
        else :unsupported_version
        end
      end

      def notification_validation_error
        return :missing_event unless event.present?
        return :invalid_notification_action unless action.in?(NOTIFICATION_ACTIONS)
        return :invalid_details if event["details"].present? && !event["details"].is_a?(Hash)
        return :missing_replay if action.in?(%w[create update]) && !data["replay"].is_a?(Hash)

        :destroy_replay_present if action == "destroy" && data["replay"].present?
      end

      def paid_state_validation_error
        return :missing_event unless event.present?
        return :invalid_details if event["details"].present? && !event["details"].is_a?(Hash)
        return if action.in?(PAID_STATE_ACTIONS)

        :invalid_paid_state_action
      end

      def deep_freeze(value)
        if value.is_a?(Hash)
          value.each do |key, child|
            deep_freeze(key)
            deep_freeze(child)
          end
        end
        value.each { |child| deep_freeze(child) } if value.is_a?(Array)
        value.freeze
      end
    end
  end
end
