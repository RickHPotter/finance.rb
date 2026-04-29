# frozen_string_literal: true

class Views::Investments::New < Views::Base
  def initialize(current_user:, investment:, chain_context: nil)
    @current_user = current_user
    @investment = investment
    @chain_context = chain_context
  end

  def view_template
    turbo_frame_tag :center_container do
      render Views::Shared::FormShell.new(
        badge_text:,
        badge_class:,
        skeleton_view: Views::Investments::FormSubmissionSkeleton
      ) do
        render Views::Investments::Form.new(current_user: @current_user, investment: @investment, chain_context: @chain_context)
      end
    end
  end

  private

  def badge_text
    if @chain_context&.dig(:record_ids)&.any?
      I18n.t(@investment.duplicate ? "gerund.chain_duplicate" : "gerund.chain_create")
    elsif @investment.duplicate
      I18n.t("gerund.duplicate")
    else
      I18n.t("gerund.new")
    end
  end

  def badge_class
    return form_badge_class(:duplicate) if @investment.duplicate

    form_badge_class(:new)
  end
end
