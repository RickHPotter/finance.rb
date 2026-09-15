# frozen_string_literal: true

class BabyNameDecisionsController < ApplicationController
  layout "baby_names"

  skip_before_action :resolve_current_context
  skip_after_action :check_reasoning

  def create
    baby_name = BabyName.active.find(params[:baby_name_id])
    decision = current_user.baby_name_decisions.find_or_initialize_by(baby_name:)
    choice = permitted_choice

    if decision.new_record? || decision.later?
      decision.choice = choice
      decision.touch if decision.persisted? && !decision.changed?
    end
    decision.save!

    redirect_to baby_names_path, status: :see_other
  rescue ActionController::ParameterMissing, ActiveRecord::RecordInvalid
    head :unprocessable_content
  end

  private

  def permitted_choice
    choice = params.require(:choice)
    return choice if BabyNameDecision.choices.key?(choice)

    raise ActionController::ParameterMissing, :choice
  end

  def audit_mutating_request?
    false
  end
end
