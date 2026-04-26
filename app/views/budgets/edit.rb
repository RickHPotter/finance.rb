# frozen_string_literal: true

class Views::Budgets::Edit < Views::Base
  def initialize(current_user:, budget:)
    @current_user = current_user
    @budget = budget
  end

  def view_template
    turbo_frame_tag :center_container do
      render Views::Shared::FormShell.new(
        badge_text: I18n.t("gerund.edit"),
        badge_class: "rounded-sm border border border-lime-400 bg-lime-200 px-3 shadow-md",
        skeleton_view: Views::Budgets::FormSubmissionSkeleton
      ) do
        render Views::Budgets::Form.new(current_user: @current_user, budget: @budget)
      end
    end
  end
end
