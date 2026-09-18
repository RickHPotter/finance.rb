# frozen_string_literal: true

class PiggyBankReconciliationsController < ApplicationController
  include TabsConcern
  include TranslateHelper

  before_action :set_return_transaction
  before_action :set_cash_tabs

  def new
    return handle_ineligible_return(alert: I18n.t("piggy_bank_reconciliations.reasons.invalid_return")) unless @return_cash_transaction.generated_piggy_bank_return?
    return handle_ineligible_return(alert: I18n.t("piggy_bank_reconciliations.reasons.settled_return")) unless open_piggy_bank_return?

    @observed_on = Time.zone.today
    @return_to = return_to_path

    render Views::PiggyBankReconciliations::New.new(
      return_cash_transaction: @return_cash_transaction,
      observed_on: @observed_on,
      return_to: @return_to
    )
  end

  def preview
    return render_ineligible_preview(:invalid_return) unless @return_cash_transaction.generated_piggy_bank_return?
    return render_ineligible_preview(:settled_return) unless open_piggy_bank_return?

    extract_inputs
    @plan = calculate_preview

    if @plan.valid?
      render_preview_success
    else
      render_preview_failure
    end
  end

  def create
    return render_ineligible_apply(:invalid_return) unless @return_cash_transaction.generated_piggy_bank_return?
    return render_ineligible_apply(:settled_return) unless open_piggy_bank_return?

    extract_inputs
    @digest = reconciliation_params[:digest]

    result = apply_reconciliation
    if result.applied?
      redirect_to @return_to, notice: I18n.t("piggy_bank_reconciliations.applied"), status: :see_other
    elsif result.noop?
      redirect_to @return_to, notice: I18n.t("piggy_bank_reconciliations.noop"), status: :see_other
    else
      render_apply_failure(result)
    end
  end

  private

  def set_return_transaction
    @return_cash_transaction = current_context.cash_transactions
                                              .where(user: current_user)
                                              .find(params[:cash_transaction_id])
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end

  def set_cash_tabs
    set_tabs(active_menu: :cash, active_sub_menu: :pix)
  end

  def open_piggy_bank_return?
    @return_cash_transaction.cash_installments.any? { |installment| !installment.paid? }
  end

  def handle_ineligible_return(alert:)
    redirect_to cash_transaction_path(@return_cash_transaction), alert:, status: :see_other
  end

  def extract_inputs
    @observed_on = parse_date(reconciliation_params[:observed_on])
    @observed_net_cents = parse_cents(reconciliation_params[:observed_net])
    @description = reconciliation_params[:description].presence
    @return_to = return_to_path
  end

  def calculate_preview
    PiggyBankReconciliations::Preview.new(
      user: current_user,
      context: current_context,
      return_cash_transaction_id: @return_cash_transaction.id,
      observed_net_cents: @observed_net_cents,
      observed_on: @observed_on
    ).call
  end

  def apply_reconciliation
    PiggyBankReconciliations::Apply.new(
      user: current_user,
      context: current_context,
      return_cash_transaction_id: @return_cash_transaction.id,
      observed_net_cents: @observed_net_cents,
      observed_on: @observed_on,
      digest: @digest,
      description: @description,
      request_id: request.request_id
    ).call
  end

  def render_preview_success
    respond_to do |format|
      format.html do
        render Views::PiggyBankReconciliations::New.new(
          return_cash_transaction: @return_cash_transaction,
          observed_on: @observed_on,
          observed_net: reconciliation_params[:observed_net],
          description: @description,
          plan: @plan,
          return_to: @return_to
        )
      end
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.update(:notification, ""),
          turbo_stream.replace(
            "piggy_bank_reconciliation_preview",
            Views::PiggyBankReconciliations::PreviewCard.new(
              return_cash_transaction: @return_cash_transaction,
              plan: @plan,
              description: @description,
              return_to: @return_to
            )
          )
        ]
      end
    end
  end

  def render_preview_failure
    @reconciliation = build_reconciliation
    @reconciliation.add_plan_errors(@plan)

    respond_to do |format|
      format.html do
        flash.now[:alert] = failure_notifications_for(@reconciliation, :not_reconciled, PiggyBankReconciliation).join(" ")
        render Views::PiggyBankReconciliations::New.new(
          return_cash_transaction: @return_cash_transaction,
          observed_on: @observed_on,
          observed_net: reconciliation_params[:observed_net],
          description: @description,
          plan: nil,
          return_to: @return_to
        ), status: :unprocessable_content
      end
      format.turbo_stream do
        render turbo_stream: failure_streams_for(@reconciliation) + [ turbo_stream.update("piggy_bank_reconciliation_preview", "") ],
               status: :unprocessable_content
      end
    end
  end

  def render_apply_failure(result)
    @reconciliation = build_reconciliation(digest: @digest)
    @reconciliation.add_result_errors(result)
    fresh_plan = calculate_fresh_plan_if_stale(result)

    respond_to do |format|
      format.html do
        flash.now[:alert] = failure_notifications_for(@reconciliation, :not_reconciled, PiggyBankReconciliation).join(" ")
        render Views::PiggyBankReconciliations::New.new(
          return_cash_transaction: @return_cash_transaction,
          observed_on: @observed_on,
          observed_net: reconciliation_params[:observed_net],
          description: @description,
          plan: fresh_plan&.valid? ? fresh_plan : nil,
          return_to: @return_to
        ), status: :unprocessable_content
      end
      format.turbo_stream do
        render turbo_stream: apply_failure_streams(fresh_plan), status: :unprocessable_content
      end
    end
  end

  def apply_failure_streams(fresh_plan)
    streams = failure_streams_for(@reconciliation)
    streams << if fresh_plan&.valid?
                 turbo_stream.replace(
                   "piggy_bank_reconciliation_preview",
                   Views::PiggyBankReconciliations::PreviewCard.new(
                     return_cash_transaction: @return_cash_transaction,
                     plan: fresh_plan,
                     description: @description,
                     return_to: @return_to
                   )
                 )
               else
                 turbo_stream.update("piggy_bank_reconciliation_preview", "")
               end
    streams
  end

  def calculate_fresh_plan_if_stale(result)
    return unless result.stale? && @observed_on.present? && @observed_net_cents.present?

    calculate_preview
  end

  def render_ineligible_preview(reason_code)
    render_ineligible_response(reason_code, stream_preview: true)
  end

  def render_ineligible_apply(reason_code)
    render_ineligible_response(reason_code, stream_preview: false)
  end

  def render_ineligible_response(reason_code, stream_preview:)
    @reconciliation = build_reconciliation
    @reconciliation.errors.add(:base, I18n.t("piggy_bank_reconciliations.reasons.#{reason_code}"))

    respond_to do |format|
      format.html do
        flash.now[:alert] = failure_notifications_for(@reconciliation, :not_reconciled, PiggyBankReconciliation).join(" ")
        render Views::PiggyBankReconciliations::New.new(
          return_cash_transaction: @return_cash_transaction,
          return_to: return_to_path
        ), status: :unprocessable_content
      end
      format.turbo_stream do
        streams = failure_streams_for(@reconciliation)
        streams << turbo_stream.update("piggy_bank_reconciliation_preview", "") if stream_preview
        render turbo_stream: streams, status: :unprocessable_content
      end
    end
  end

  def build_reconciliation(digest: nil)
    PiggyBankReconciliation.new(
      return_cash_transaction_id: @return_cash_transaction.id,
      observed_on: @observed_on,
      observed_net: reconciliation_params[:observed_net],
      observed_net_cents: @observed_net_cents,
      description: @description,
      digest:
    )
  end

  def failure_streams_for(reconciliation)
    notifications = failure_notifications_for(reconciliation, :not_reconciled, PiggyBankReconciliation)
    notifications.each_with_index.map do |alert, index|
      turbo_stream.public_send(
        index.zero? ? :update : :append,
        :notification,
        partial: "shared/flash",
        locals: { notice: nil, alert: }
      )
    end
  end

  def parse_cents(value)
    return nil if value.blank?
    return value if value.is_a?(Integer)

    str = value.to_s.strip
    return str.to_i if str.match?(/\A\d+\z/)

    if str.include?(".") && str.include?(",")
      str = str.rindex(",") > str.rindex(".") ? str.tr(".", "").tr(",", ".") : str.delete(",")
    end

    cleaned = str.gsub(/[^\d.,-]/, "")
    if cleaned.match?(/\A-?\d+[.,]\d{1,2}\z/)
      (cleaned.tr(",", ".").to_f * 100).round
    elsif cleaned.match?(/\A-?\d+\z/)
      cleaned.to_i
    end
  end

  def parse_date(value)
    return value.to_date if value.respond_to?(:to_date) && !value.is_a?(String)
    return nil if value.blank?

    Date.parse(value.to_s.split("T").first)
  rescue Date::Error
    nil
  end

  def return_to_path
    fallback = cash_transaction_path(@return_cash_transaction)
    Navigation::CashTransactions.new(
      raw: params[:return_to],
      fallback:,
      current_user:,
      current_context:
    ).destination
  end

  def reconciliation_params
    params.permit(:observed_on, :observed_net, :description, :digest, :return_to)
  end
end
