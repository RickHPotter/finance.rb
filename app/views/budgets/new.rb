# frozen_string_literal: true

class Views::Budgets::New < Views::Base
  def initialize(current_user:, budget:)
    @current_user = current_user
    @budget = budget
  end

  def view_template
    turbo_frame_tag :center_container do
      render Views::Shared::FormShell.new(
        badge_text: badge_text,
        badge_class: badge_class,
        skeleton_view: Views::Budgets::FormSubmissionSkeleton
      ) do
        render Views::Budgets::Form.new(current_user: @current_user, budget: @budget)
      end
    end
  end

  private

  def badge_text
    return I18n.t("gerund.duplicate") if @budget.duplicate

    I18n.t("gerund.new")
  end

  def badge_class
    base = "rounded-sm border border px-3 shadow-md"
    return "#{base} border-orange-400 bg-orange-200" if @budget.duplicate

    "#{base} border-sky-400 bg-sky-200"
  end
end
