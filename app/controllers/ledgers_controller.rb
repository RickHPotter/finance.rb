# frozen_string_literal: true

class LedgersController < ApplicationController
  include TranslateHelper

  before_action :resolve_ledger_access!
  before_action :set_user_agent, :set_tabs

  private

  attr_reader :ledger_access

  def resolve_ledger_access!
    raise NotImplementedError
  end

  def user
    ledger_access.user
  end

  def lala
    ledger_access.entity
  end

  def lala_context
    ledger_access.context
  end

  def set_user_agent
    @mobile = true if request.user_agent =~ /Mobile|Android|iPhone|iPad/
  end

  def set_tabs(active_menu: :cash, active_sub_menu: :pix)
    @active_menu = active_menu
    @active_sub_menu = active_sub_menu
    set_variables
  end

  def exchange_category
    user.categories.find_by(category_name: "EXCHANGE")
  end

  def user_cards
    return user.user_cards if exchange_category.nil?

    user.user_cards
        .joins(card_transactions: %i[category_transactions entity_transactions])
        .where(card_transactions: { context_id: lala_context.id })
        .where(category_transactions: { category_id: exchange_category.id })
        .where(entity_transactions: { entity_id: lala.id })
        .group("user_cards.id")
        .order(active: :desc)
  end

  def set_variables
    @main_items = [ { label: t("tabs.pix"), icon: :mobile, link: ledger_cash_transactions_path, default: @active_menu == :pix } ]
    @main_items += user_cards.pluck(:id, :user_card_name).map do |user_card_id, user_card_name|
      default = @active_sub_menu.to_sym == user_card_name.to_sym
      { label: user_card_name, icon: :credit_card, link: ledger_card_transactions_path(user_card_id:), default: }
    end

    @main_items.first[:default] = true if @main_items.pluck(:default).uniq == [ false ]
    @main_items.map! { |item| item.slice(:label, :icon, :link, :default).values }
    @main_tab = @main_items.map { |label, icon, link, default| Item.new(label, icon, link, default, 0) }
    @main_tab.each { |tab| tab.label = tab.label.split.first } if @mobile
  end

  def external_route_params
    return unless ledger_access.share

    { share_token: params[:share_token] }
  end

  def internal_route_params
    return if ledger_access.share

    { entity_public_id: lala.public_id }
  end

  def ledger_cash_transactions_path(**query_params)
    return external_cash_transactions_path(**external_route_params, **query_params) if ledger_access.share

    internal_cash_transactions_path(**internal_route_params, **query_params)
  end

  def ledger_card_transactions_path(**query_params)
    return external_card_transactions_path(**external_route_params, **query_params) if ledger_access.share

    internal_card_transactions_path(**internal_route_params, **query_params)
  end
end
