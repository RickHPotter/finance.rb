# frozen_string_literal: true

class BabyNamesController < ApplicationController
  layout "baby_names"

  include BabyNamesAccess

  skip_before_action :resolve_current_context
  skip_after_action :check_reasoning

  def index
    flow = BabyNames::Flow.new(current_user)
    redirect_to rank_baby_names_path, status: :see_other and return if flow.current_phase != "phase1"

    decisions = current_user.baby_name_decisions
    stats = decisions.group(:choice).count
    baby_name = BabyName.active.unreviewed_by(current_user).in_display_order.first
    baby_name ||= decisions.later.joins(:baby_name).merge(BabyName.active).order(:updated_at, :id).first&.baby_name

    render Views::BabyNames::Index.new(
      baby_name:,
      stats:,
      total: BabyName.active.count,
      current_user:,
      flow:
    )
  end

  def review
    filter = params[:filter].presence_in(%w[accepted rejected later])
    user_decisions = current_user.baby_name_decisions.index_by(&:baby_name_id)

    names = BabyName.active.in_display_order
    names = names.where(id: current_user.baby_name_decisions.where(choice: filter).select(:baby_name_id)) if filter

    render Views::BabyNames::Review.new(
      names:,
      user_decisions:,
      current_filter: filter || "all",
      current_user:
    )
  end

  def rank
    flow = BabyNames::Flow.new(current_user)
    redirect_to baby_names_path, status: :see_other and return if flow.current_phase == "phase1"

    render Views::BabyNames::Rank.new(
      flow:,
      names: flow.phase_names,
      current_user:
    )
  end

  def submit_rank
    flow = BabyNames::Flow.new(current_user)
    ordered_ids = params[:name_ids].to_a.map(&:to_i)

    case flow.current_phase
    when "phase2" then flow.complete_phase2!(ordered_ids)
    when "phase3" then flow.complete_phase3!(ordered_ids)
    when "phase4" then flow.complete_phase4!(ordered_ids)
    end

    redirect_to rank_baby_names_path, status: :see_other
  end
end
