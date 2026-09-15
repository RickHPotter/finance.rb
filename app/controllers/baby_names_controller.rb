# frozen_string_literal: true

class BabyNamesController < ApplicationController
  layout "baby_names"

  skip_before_action :resolve_current_context
  skip_after_action :check_reasoning

  def index
    decisions = current_user.baby_name_decisions
    stats = decisions.group(:choice).count
    baby_name = BabyName.active.unreviewed_by(current_user).in_display_order.first
    baby_name ||= decisions.later.joins(:baby_name).merge(BabyName.active).order(:updated_at, :id).first&.baby_name

    render Views::BabyNames::Index.new(
      baby_name:,
      stats:,
      total: BabyName.active.count,
      current_user:
    )
  end
end
