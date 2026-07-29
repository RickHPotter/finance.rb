# frozen_string_literal: true

class AllocationMutationsController < ApplicationController
  include TabsConcern

  before_action :set_allocation_tabs

  def create
    result = AllocationMutations::Apply.new(
      actor: current_user,
      context: current_context,
      request_id: request.request_id,
      token: params[:apply_token],
      mode: params[:mode],
      confirmed: params[:allocation_confirmation]
    ).call

    respond_to do |format|
      format.html { redirect_after_apply(result) }
      format.turbo_stream { render_turbo_result(result) }
      format.json { render json: result_payload(result), status: response_status(result) }
    end
  end

  private

  def render_turbo_result(result)
    render turbo_stream: turbo_streams_for(result), status: response_status(result)
  end

  def turbo_streams_for(result)
    streams = []
    refresh = index_refresh(result)
    streams << if refresh
                 turbo_stream.replace(:center_container, refresh)
               else
                 turbo_stream.replace(
                   "allocation_mutation_preview",
                   Views::AllocationMutations::Result.new(result:, frame_only: true)
                 )
               end
    streams << turbo_stream.update(
      :notification,
      partial: "shared/flash",
      locals: result.applied? ? { notice: result_message(result) } : { alert: result_message(result) }
    )
    streams
  end

  def index_refresh(result)
    return unless result.applied?

    case token_selection&.fetch("owner_type", nil)
    when "CashTransaction", "CardTransaction"
      AllocationMutations::TransactionIndexRefresh.new(
        actor: current_user,
        context: current_context,
        owner_type: token_selection.fetch("owner_type"),
        destination: allocation_return_path,
        mobile: @mobile
      ).view
    when "Budget"
      AllocationMutations::BudgetIndexRefresh.new(
        actor: current_user,
        context: current_context,
        destination: allocation_return_path,
        mobile: @mobile
      ).view
    end
  rescue StandardError => e
    Rails.error.report(e, handled: true, severity: :warning, context: { component: "allocation_mutation_index_refresh" })
    nil
  end

  def redirect_after_apply(result)
    options = { status: :see_other }
    options[result.applied? ? :notice : :alert] = result_message(result)
    redirect_to allocation_return_path, **options
  end

  def result_message(result)
    key = result.applied? ? "allocation_mutations.apply.applied" : "allocation_mutations.apply.reasons.#{result.reason_code}"
    I18n.t(key, default: I18n.t("allocation_mutations.apply.reasons.unexpected_failure"))
  end

  def result_payload(result)
    {
      status: result.status,
      reason_code: result.reason_code,
      operation_id: result.operation&.id,
      affected_count: result.impacts.size,
      mode: result.mode,
      duplicate: result.duplicate?
    }
  end

  def response_status(result)
    return :ok if result.applied?
    return :unprocessable_content if result.rejected?

    :internal_server_error
  end

  def allocation_return_path
    return @allocation_return_path if defined?(@allocation_return_path)

    owner_type = token_selection&.fetch("owner_type", nil)
    raw = params[:return_to].presence

    @allocation_return_path =
      case owner_type
      when "CardTransaction"
        Navigation::CardTransactions.new(raw:, fallback: card_transactions_path, current_user:, current_context:).destination
      when "Budget"
        budget_allocation_return_path(raw)
      else
        Navigation::CashTransactions.new(raw:, fallback: cash_transactions_path, current_user:, current_context:).destination
      end
  end

  def budget_allocation_return_path(raw)
    uri = URI.parse(raw.presence || budgets_path)
    return Navigation::CashTransactions.new(raw:, fallback: cash_transactions_path, current_user:, current_context:).destination if uri.path == cash_transactions_path

    Navigation::Budgets.new(raw:, fallback: budgets_path, current_user:, current_context:).destination
  rescue URI::InvalidURIError
    budgets_path
  end

  def token_selection
    AllocationMutations::PreviewToken.verify(params[:apply_token])&.fetch("selection", nil)
  end

  def set_allocation_tabs
    case token_selection&.fetch("owner_type", nil)
    when "CardTransaction"
      set_tabs(active_menu: :card, active_sub_menu: :search)
    when "Budget"
      set_tabs(active_menu: :cash, active_sub_menu: :budget)
    else
      set_tabs(active_menu: :cash, active_sub_menu: :pix)
    end
  end
end
