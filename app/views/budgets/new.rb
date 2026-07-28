# frozen_string_literal: true

class Views::Budgets::New < Views::Base
  def initialize(current_user:, budget:, return_to: "/budgets")
    @current_user = current_user
    @budget = budget
    @return_to = return_to
  end

  def view_template
    turbo_frame_tag :center_container do
      render Views::Shared::FormShell.new(
        badge_text: badge_text,
        badge_class: badge_class,
        skeleton_view: Views::Budgets::FormSubmissionSkeleton
      ) do
        render Views::Budgets::Form.new(current_user: @current_user, budget: @budget, return_to: @return_to)
      end
    end
  end

  private

  def badge_text
    return I18n.t("gerund.duplicate") if @budget.duplicate

    I18n.t("gerund.new")
  end

  def badge_class
    return form_badge_class(:duplicate) if @budget.duplicate

    form_badge_class(:new)
  end
end
