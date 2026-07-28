# frozen_string_literal: true

class HealthCheck::Broadcaster
  class << self
    def call(scope:, run:)
      broadcast_scopes(scope, run:).each do |broadcast_scope|
        new(scope: broadcast_scope, run:).call
      end
    end

    private

    def broadcast_scopes(scope, run:)
      entry = HealthCheck::Registry.find(run.check_key)
      return [ scope ] if entry.blank? || entry.connection_scoped?

      base_scope = scope.for_entry(entry)
      [ base_scope, *connected_scopes(base_scope) ]
    end

    def connected_scopes(scope)
      connected_user_ids = scope.user.entities.that_are_users.distinct.pluck(:entity_user_id)
      User.where(id: connected_user_ids).map do |connected_user|
        HealthCheck::Scope.new(
          user: scope.user,
          context: scope.context,
          connected_user:,
          locale: scope.locale
        )
      end
    end
  end

  attr_reader :run, :scope

  def initialize(scope:, run:)
    @scope = scope
    @run = run
  end

  def call
    I18n.with_locale(scope.locale) do
      Turbo::StreamsChannel.broadcast_replace_to(
        HealthCheck::Stream.for(scope),
        target: "health_check_check_#{run.check_key}",
        html: render_card
      )
      Turbo::StreamsChannel.broadcast_replace_to(
        HealthCheck::Stream.for(scope),
        target: "health_check_overview",
        html: render_overview
      )
    end
  end

  private

  def summaries
    @summaries ||= HealthCheck::DashboardSnapshot.new(scope:).summaries
  end

  def render_card
    summary = summaries.find { |candidate| candidate.entry.key == run.check_key }
    ApplicationController.render(
      Views::HealthCheck::Dashboard::CheckCard.new(summary:, scope:),
      layout: false
    )
  end

  def render_overview
    ApplicationController.render(
      Views::HealthCheck::Dashboard::Overview.new(scope:, summaries:),
      layout: false
    )
  end
end
