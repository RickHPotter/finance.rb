# frozen_string_literal: true

class Views::Investments::Edit < Views::Base
  def initialize(current_user:, investment:, return_to: "/investments")
    @current_user = current_user
    @investment = investment
    @return_to = return_to
  end

  def view_template
    turbo_frame_tag :center_container do
      render Views::Shared::FormShell.new(
        badge_text: I18n.t("gerund.edit"),
        badge_class: form_badge_class(:edit),
        skeleton_view: Views::Investments::FormSubmissionSkeleton
      ) do
        render Views::Investments::Form.new(current_user: @current_user, investment: @investment, return_to: @return_to)
      end
    end
  end
end
