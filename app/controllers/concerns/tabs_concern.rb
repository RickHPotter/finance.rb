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

  def set_tabs(active_menu: :card, active_sub_menu: :a)
    @active_menu = active_menu
    @active_sub_menu = active_sub_menu

    set_variables
  end

  private

  def set_variables
    set_basic_sublinks
    set_card_transaction_sublinks
    set_cash_transaction_sublinks

    @main_items = [
      { label: t("tabs.basic"),            icon: :exchange, link: @basic_tab.first.link,            default: @active_menu == :basic },
      { label: t("tabs.card_transaction"), icon: :wallet,   link: @card_transaction_tab.first.link, default: @active_menu == :card },
      { label: t("tabs.cash_transaction"), icon: :cash,     link: @cash_transaction_tab.first.link, default: @active_menu == :cash }
    ].map { |item| item.slice(:label, :icon, :link, :default).values }

    @main_tab = @main_items.map do |label, icon, link, default|
      Components::TabsComponent::Item.new(label, icon, link, default, :center_container)
    end

    @main_tab.each { |tab| tab.label = tab.label.split.first } if @mobile

    @sub_tab = [ @basic_tab, @card_transaction_tab, @cash_transaction_tab ]
  end

  def set_basic_sublinks
    @basic_items = [
      { label: t("tabs.user_bank_account"), icon: :safe,        link: user_bank_accounts_path, default: @active_sub_menu == :user_bank_account },
      { label: t("tabs.user_card"),         icon: :credit_card, link: user_cards_path,         default: @active_sub_menu == :user_card },
      { label: t("tabs.category"),          icon: :category,    link: categories_path,         default: @active_sub_menu == :category },
      { label: t("tabs.entity"),            icon: :user_circle, link: entities_path,           default: @active_sub_menu == :entity }
    ].map { |item| item.slice(:label, :icon, :link, :default).values }

    @basic_tab = @basic_items.map do |label, icon, link, default|
      Components::TabsComponent::Item.new(label, icon, link, default, :center_container)
    end
  end

  def set_card_transaction_sublinks
    # user_cards = current_user.user_cards.active.pluck(:id, :user_card_name)

    @card_transaction_tab = []
    @card_transaction_tab <<
      Components::TabsComponent::Item.new(:a, :credit_card, new_card_transaction_path, true, :center_container)

    # @card_transaction_tab = user_cards.map do |user_card_id, user_card_name|
    #   default = @active_sub_menu.to_sym == user_card_name.to_sym
    #   Components::TabsComponent::Item.new(user_card_name, :credit_card, card_transactions_path(user_card_id:), default, :center_container)
    # end
    #
    # if @card_transaction_tab.present?
    #   @card_transaction_tab << Components::TabsComponent::Item.new(action_message(:search),
    #                                                                :magnifying_glass,
    #                                                                search_card_transactions_path,
    #                                                                @active_sub_menu.to_sym == :search,
    #                                                                :center_container)
    #   return
    # end
    #
    # @card_transaction_tab <<
    #   Components::TabsComponent::Item.new(action_model(:new, UserCard), "credit_card", new_user_card_path, false, :center_container)
  end

  def set_cash_transaction_sublinks
    @cash_transaction_items = [
      { label: t("tabs.pix"),        icon: :mobile,      link: cash_transactions_path, default: @active_sub_menu == :pix },
      { label: t("tabs.budget"),     icon: :piggy_bank,  link: new_budget_path,        default: @active_sub_menu == :budget },
      { label: t("tabs.investment"), icon: :trending_up, link: cash_transactions_path, default: @active_sub_menu == :investment }
    ].map { |item| item.slice(:label, :icon, :link, :default).values }

    @cash_transaction_tab = @cash_transaction_items.map do |label, icon, link, default|
      Components::TabsComponent::Item.new(label, icon, link, default, :center_container)
    end
  end
end
