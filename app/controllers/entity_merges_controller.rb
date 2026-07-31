# frozen_string_literal: true

class EntityMergesController < ApplicationController
  include TabsConcern

  before_action :set_source_entity
  before_action :set_basic_tabs

  def create
    mode = (params[:mode].presence || "strict").to_sym

    result = EntityMerges::Apply.new(
      actor: current_user,
      context: current_context,
      request_id: request.request_id,
      token: params[:merge_token],
      mode:,
      confirmed: true
    ).call

    respond_to do |format|
      format.html { redirect_after_apply(result) }
      if result.applied?
        format.turbo_stream { redirect_after_apply(result) }
        format.json { render json: result_payload(result), status: :ok }
      else
        format.turbo_stream { render_turbo_result(result) }
        format.json { render json: result_payload(result), status: response_status(result) }
      end
    end
  end

  private

  def set_source_entity
    @source = current_user.entities.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end

  def redirect_after_apply(result)
    options = { status: :see_other }
    options[result.applied? ? :notice : :alert] = result_message(result)
    redirect_to return_to_path, **options
  end

  def render_turbo_result(result)
    render turbo_stream: turbo_streams_for(result), status: response_status(result)
  end

  def turbo_streams_for(result)
    [
      turbo_stream.update(
        :notification,
        partial: "shared/flash",
        locals: { alert: result_message(result) }
      )
    ]
  end

  def result_message(result)
    key = result.applied? ? "entity_merges.applied" : "entity_merges.reasons.#{result.reason_code}"
    I18n.t(key, default: I18n.t("entity_merges.reasons.unexpected_failure", default: "Failed to merge entity"))
  end

  def result_payload(result)
    {
      status: result.status,
      reason_code: result.reason_code,
      operation_id: result.operation&.id
    }
  end

  def response_status(result)
    return :ok if result.applied?
    return :unprocessable_content if result.rejected?

    :internal_server_error
  end

  def return_to_path
    params[:return_to].presence || entities_path
  end

  def set_basic_tabs
    set_tabs(active_menu: :data, active_sub_menu: :entity)
  end
end
