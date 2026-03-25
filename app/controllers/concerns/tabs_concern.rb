# frozen_string_literal: true

module TabsConcern
  extend ActiveSupport::Concern

  include TranslateHelper

  included do
    before_action :set_user_agent
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

  def set_variables
    set_data_sublinks
    set_card_sublinks
    set_cash_sublinks
    set_hub_sublinks
    set_main_sublinks

    set_main_tab
    set_sub_tab
  end

  def set_data_sublinks
    @data_tab = [
      Item.new(t("tabs.user_bank_account"), :bank,        user_bank_accounts_path, @active_sub_menu == :user_bank_account),
      Item.new(t("tabs.user_card"),         :credit_card, user_cards_path,         @active_sub_menu == :user_card),
      Item.new(t("tabs.category"),          :category,    categories_path,         @active_sub_menu == :category),
      Item.new(t("tabs.entity"),            :user_circle, entities_path,           @active_sub_menu == :entity)
    ]
  end

  def set_card_sublinks
    user_cards = current_user.user_cards.active.order(:id).pluck(:id, :user_card_name)

    @card_tab = user_cards.map do |user_card_id, user_card_name|
      default = @active_sub_menu.to_sym == user_card_name.to_sym
      Item.new(user_card_name, :credit_card, card_transactions_path(user_card_id:), default)
    end

    if @card_tab.present?
      @card_tab << Item.new(
        action_message(:search), :magnifying_glass, search_card_transactions_path, @active_sub_menu.to_sym == :search
      )
      return
    end

    @card_tab << Item.new(action_model(:new, UserCard), "credit_card", new_user_card_path, false)
  end

  def set_cash_sublinks
    cash_notification_type = current_context.cash_installments.due_today.any? ? 1 : 0

    @cash_tab = [
      Item.new(t("tabs.pix"),          :mobile,      cash_transactions_path, @active_sub_menu == :pix, cash_notification_type),
      Item.new(t("tabs.budget"),       :piggy_bank,  budgets_path,           @active_sub_menu == :budget),
      Item.new(t("tabs.investment"),   :trending_up, investments_path,       @active_sub_menu == :investment),
      Item.new(t("tabs.subscription"), :refresh,     subscriptions_path,     @active_sub_menu == :subscription)
    ]
  end

  def set_hub_sublinks
    conversation_notification_type =
      if current_user.received_messages
                     .joins(:conversation)
                     .where(conversations: { scenario_key: current_context.scenario_key })
                     .unread
                     .any?
        1
      else
        0
      end

    @hub_tab = [
      Item.new(t("tabs.balance"),      :chart,    balances_path,        @active_sub_menu == :balance),
      Item.new(t("tabs.conversation"), :message,  conversations_path,   @active_sub_menu == :conversation, conversation_notification_type),
      Item.new(t("tabs.context"),      :exchange, contexts_path,        @active_sub_menu == :context),
      Item.new(t("tabs.settings"),     :cog,      donation_static_path, @active_sub_menu == :settings)
    ]
  end

  def set_main_sublinks
    @bank_link = (@data_tab.find(&:default) || @data_tab.first).link
    @card_link = (@card_tab.find(&:default) || @card_tab.first).link
    @cash_link = (@cash_tab.find(&:default) || @cash_tab.first).link
    @hub_link  = (@hub_tab.find(&:default) || @hub_tab.first).link
  end

  def set_main_tab
    @main_tab = [
      Item.new(t("tabs.data"),
               :bank,
               @bank_link,
               @active_menu == :data,
               @data_tab.map(&:notification_type).max),

      Item.new(t("tabs.card"),
               :wallet,
               @card_link,
               @active_menu == :card,
               @card_tab.map(&:notification_type).max),

      Item.new(t("tabs.cash"),
               :cash,
               @cash_link,
               @active_menu == :cash,
               @cash_tab.map(&:notification_type).max),

      Item.new(t("tabs.hub"),
               :light_bulb,
               @hub_link,
               @active_menu == :hub,
               @hub_tab.map(&:notification_type).max)
    ]
  end

  def set_sub_tab
    @sub_tab = [ @data_tab, @card_tab, @cash_tab, @hub_tab ]
  end
end
