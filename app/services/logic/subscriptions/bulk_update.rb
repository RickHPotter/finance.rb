# frozen_string_literal: true

module Logic
  module Subscriptions
    class BulkUpdate
      MAX_SELECTION = 100
      ACTIONS = %w[status replace_category clear_category replace_entity clear_entity].freeze

      class InvalidSelection < StandardError; end

      attr_reader :scope, :user, :ids, :action, :value

      def self.call(scope:, user:, ids:, action:, value: nil)
        new(scope:, user:, ids:, action:, value:).call
      end

      def initialize(scope:, user:, ids:, action:, value:)
        @scope = scope
        @user = user
        @ids = Array(ids).map(&:to_s)
        @action = action.to_s
        @value = value.to_s
      end

      def call
        validate_request!
        target = selection_value

        Subscription.transaction do
          subscriptions = scope.where(id: ids).order(:id).lock.to_a
          raise InvalidSelection, :invalid_selection if subscriptions.size != ids.size

          Audit::Current.metadata = (Audit::Current.metadata || {}).merge("subscription_bulk_edit" => action)
          subscriptions.each { |subscription| update_subscription!(subscription, target) }
        end
      end

      private

      def validate_request!
        raise InvalidSelection, :invalid_selection if ids.empty? || ids.size > MAX_SELECTION || ids.any? { |id| !id.match?(/\A[1-9]\d*\z/) }
        raise InvalidSelection, :invalid_selection if ids.uniq.size != ids.size
        raise InvalidSelection, :invalid_action unless ACTIONS.include?(action)
      end

      def selection_value
        case action
        when "status"
          raise InvalidSelection, :invalid_value unless Logic::Subscriptions::LifecycleTransition::TRANSITIONS.key?(value)

          value
        when "replace_category"
          user.categories.active.find_by(id: value) || raise(InvalidSelection, :invalid_value)
        when "replace_entity"
          user.entities.active.find_by(id: value) || raise(InvalidSelection, :invalid_value)
        else
          raise InvalidSelection, :invalid_value if value.present?

          nil
        end
      end

      def update_subscription!(subscription, target)
        case action
        when "status" then Logic::Subscriptions::LifecycleTransition.call(subscription:, event: target)
        when "replace_category" then subscription.update!(categories: [ target ])
        when "clear_category" then subscription.update!(categories: [])
        when "replace_entity" then subscription.update!(entities: [ target ])
        when "clear_entity" then subscription.update!(entities: [])
        end
      end
    end
  end
end
