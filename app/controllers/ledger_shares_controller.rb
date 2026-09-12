# frozen_string_literal: true

class LedgerSharesController < ApplicationController
  include TabsConcern

  class InvalidExpiryError < StandardError; end

  before_action :set_entity
  before_action :set_share, only: %i[destroy rotate]
  before_action :set_basic_tabs

  def create
    result = Ledgers::Shares::Create.call(entity:, context: current_context, expires_at: parsed_expires_at, audit: true)
    render_success(result:, notice: t("ledger_shares.notices.created"), status: :created)
  rescue ActiveRecord::RecordInvalid, InvalidExpiryError => e
    render_failure(message_for(e))
  end

  def destroy
    Ledgers::Shares::Revoke.call(share:, audit: true)
    render_success(notice: t("ledger_shares.notices.revoked"))
  rescue ActiveRecord::RecordInvalid => e
    render_failure(message_for(e))
  end

  def rotate
    result = Ledgers::Shares::Rotate.call(share:, audit: true)
    render_success(result:, notice: t("ledger_shares.notices.rotated"))
  rescue ActiveRecord::RecordInvalid, Ledgers::Shares::Rotate::UnavailableError => e
    render_failure(message_for(e))
  end

  private

  attr_reader :entity, :share

  def set_entity
    @entity = current_user.entities.find(params[:entity_id])
  end

  def set_share
    @share = entity.ledger_shares.where(context: current_context).find_by!(public_id: params[:id])
  end

  def set_basic_tabs
    set_tabs(active_menu: :data, active_sub_menu: :entity)
  end

  def parsed_expires_at
    value = params.dig(:ledger_share, :expires_at).to_s
    return if value.blank?

    Time.zone.parse(value) || raise(InvalidExpiryError, t("ledger_shares.errors.invalid_expiry"))
  rescue ArgumentError
    raise InvalidExpiryError, t("ledger_shares.errors.invalid_expiry")
  end

  def render_success(notice:, result: nil, status: :ok)
    created_share_url = external_root_url(share_token: result.token) if result
    component = ledger_shares_component(created_share_url:)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace("entity_ledger_shares", component),
          turbo_stream.update(:notification, partial: "shared/flash", locals: { notice:, alert: nil })
        ], status:
      end
      format.html { render_entity_dashboard(created_share_url:, status:) }
    end
  end

  def render_failure(message)
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update(:notification, partial: "shared/flash", locals: { notice: nil, alert: message }),
               status: :unprocessable_content
      end
      format.html { redirect_to entity_path(entity), alert: message, status: :see_other }
    end
  end

  def render_entity_dashboard(created_share_url:, status:)
    render Views::Entities::Show.new(
      entity:,
      ledger_context: current_context,
      ledger_shares: ledger_shares,
      created_share_url:
    ), status:
  end

  def ledger_shares_component(created_share_url: nil)
    Views::Entities::LedgerShares.new(entity:, ledger_context: current_context, shares: ledger_shares, created_share_url:)
  end

  def ledger_shares
    entity.ledger_shares.where(context: current_context).order(created_at: :desc)
  end

  def message_for(error)
    return t("ledger_shares.errors.unavailable") if error.is_a?(Ledgers::Shares::Rotate::UnavailableError)
    return error.record.errors.full_messages.to_sentence if error.respond_to?(:record)

    error.message
  end
end
