# frozen_string_literal: true

# Controller for Unauthenticated User Lala
class LalasController < ApplicationController
  include TranslateHelper

  skip_before_action :authenticate_user!
  before_action :set_user_agent, :set_tabs

  def index
    render Views::Lalas::Index.new
  end

  def set_user_agent
    return unless request.user_agent =~ /Mobile|Android|iPhone|iPad/

    @mobile = true
  end

  def set_tabs(active_menu: :cash, active_sub_menu: :pix)
    @active_menu = active_menu
    @active_sub_menu = active_sub_menu

    set_variables
  end

  private

  def user
    User.first
  end

  def lala
    user.entities.find_by(entity_name: "LALA")
  end

  def exchange_category
    user.categories.find_by(category_name: "EXCHANGE")
  end

  def user_cards
    return user.user_cards if exchange_category.nil? && lala.nil?

    user.user_cards
        .joins(card_transactions: %i[category_transactions entity_transactions])
        .where(category_transactions: { category_id: exchange_category.id })
        .where(entity_transactions: { entity_id: lala.id })
        .group("user_cards.id")
        .order(active: :desc)
  end

  def set_variables
    @main_items = [ { label: t("tabs.pix"), icon: :mobile, link: lalas_cash_transactions_path, default: @active_menu == :pix } ]

    card_items = user_cards.pluck(:id, :user_card_name).map do |user_card_id, user_card_name|
      default = @active_sub_menu.to_sym == user_card_name.to_sym
      { label: user_card_name, icon: :credit_card, link: lalas_card_transactions_path(user_card_id:), default: }
    end

    @main_items += card_items

    @main_items.first[:default] = true if @main_items.pluck(:default).uniq == [ false ]
    @main_items.map! { |item| item.slice(:label, :icon, :link, :default).values }

    @main_tab = @main_items.map do |label, icon, link, default|
      Item.new(label, icon, link, default, 0, "_top")
    end

    @main_tab.each { |tab| tab.label = tab.label.split.first } if @mobile
  end
end
