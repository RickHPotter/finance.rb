# frozen_string_literal: true

class Views::Subscriptions::Edit < Views::Base
  attr_reader :current_user, :subscription

  def initialize(current_user:, subscription:)
    @current_user = current_user
    @subscription = subscription
  end

  def view_template
    turbo_frame_tag :center_container do
      render Views::Shared::FormShell.new(
        badge_text: I18n.t("gerund.edit"),
        badge_class: form_badge_class(:edit),
        skeleton_view: Views::Subscriptions::FormSubmissionSkeleton
      ) do
        div(class: "flex min-h-[calc(100svh-22rem)] flex-col") do
          render Views::Subscriptions::Form.new(current_user:, subscription:)
        end
      end
    end
  end
end
