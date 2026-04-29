# frozen_string_literal: true

class Views::Subscriptions::New < Views::Base
  attr_reader :current_user, :subscription

  def initialize(current_user:, subscription:)
    @current_user = current_user
    @subscription = subscription
  end

  def view_template
    turbo_frame_tag :center_container do
      render Views::Shared::FormShell.new(badge_text: I18n.t("gerund.new"), badge_class: form_badge_class(:new)) do
        div(class: "flex min-h-[calc(100svh-22rem)] flex-col") do
          render Views::Subscriptions::Form.new(current_user:, subscription:)
        end
      end
    end
  end
end
