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

  def set_tabs(active_menu: :cash, active_sub_menu: :cash)
    @active_menu = active_menu
    @active_sub_menu = active_sub_menu

    set_variables
  end

  private

  def set_variables # rubocop:disable Metrics/MethodLength
    set_sublinks

    @main_tab = [
      Item.new(
        t("tabs.basic"),
        :exchange,
        (@basic_tab.find(&:default) || @basic_tab.first).link,
        @active_menu == :basic,
        @basic_tab.map(&:notification_type).max,
        :_top
      ),
      Item.new(
        t("tabs.card_transaction"),
        :wallet,
        (@card_transaction_tab.find(&:default) || @card_transaction_tab.first).link,
        @active_menu == :card,
        @card_transaction_tab.map(&:notification_type).max,
        :_top
      ),
      Item.new(
        t("tabs.cash_transaction"),
        :cash,
        (@cash_transaction_tab.find(&:default) || @cash_transaction_tab.first).link,
        @active_menu == :cash,
        @cash_transaction_tab.map(&:notification_type).max,
        :_top
      )
    ]

    @main_tab.each { |tab| tab.label = tab.label.split.first } if @mobile

    @sub_tab = [ @basic_tab, @card_transaction_tab, @cash_transaction_tab ]
  end

  def set_sublinks
    set_basic_sublinks
    set_card_transaction_sublinks
    set_cash_transaction_sublinks
  end

  def set_basic_sublinks
    converstion_notification_type = current_user.received_messages.unread.any? ? 1 : 0

    @basic_tab = [
      Item.new(t("tabs.user_bank_account"), :bank,        user_bank_accounts_path, @active_sub_menu == :user_bank_account, 0, :_top),
      Item.new(t("tabs.user_card"),         :credit_card, user_cards_path,         @active_sub_menu == :user_card,         0, :_top),
      Item.new(t("tabs.category"),          :category,    categories_path,         @active_sub_menu == :category,          0, :_top),
      Item.new(t("tabs.entity"),            :user_circle, entities_path,           @active_sub_menu == :entity,            0, :_top),
      Item.new(t("tabs.conversation"),      :message,     conversation_path(1),    @active_sub_menu == :conversation,      converstion_notification_type, :_top)
    ]
  end

  def set_card_transaction_sublinks
    user_cards = current_user.user_cards.active.order(:id).pluck(:id, :user_card_name)

    @card_transaction_tab = user_cards.map do |user_card_id, user_card_name|
      default = @active_sub_menu.to_sym == user_card_name.to_sym
      Item.new(user_card_name, :credit_card, card_transactions_path(user_card_id:), default, 0, :_top)
    end

    if @card_transaction_tab.present?
      @card_transaction_tab << Item.new(
        action_message(:search), :magnifying_glass, search_card_transactions_path, @active_sub_menu.to_sym == :search, 0, :_top
      )
      return
    end

    @card_transaction_tab << Item.new(action_model(:new, UserCard), "credit_card", new_user_card_path, false, 0, :_top)
  end

  def set_cash_transaction_sublinks
    cash_notification_type = current_user.cash_installments.due_today.any? ? 1 : 0

    @cash_transaction_tab = [
      Item.new(t("tabs.pix"),        :mobile,      cash_transactions_path, @active_sub_menu == :pix,        cash_notification_type, :_top),
      Item.new(t("tabs.budget"),     :piggy_bank,  budgets_path,           @active_sub_menu == :budget,     0, :_top),
      Item.new(t("tabs.investment"), :trending_up, investments_path,       @active_sub_menu == :investment, 0, :_top),
      Item.new(t("tabs.subscription"), :refresh,   subscriptions_path,     @active_sub_menu == :subscription, 0, :_top),
      Item.new(t("tabs.balance"), :chart, balances_path, @active_sub_menu == :balance, 0, :_top)
    ]
  end
end
