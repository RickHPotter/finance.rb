# frozen_string_literal: true

module TabsConcern
  extend ActiveSupport::Concern

  included do
    before_action :set_user_agent
  end

  def set_user_agent
    return unless request.user_agent =~ /Mobile|Android|iPhone|iPad/

    @mobile = true
  end

  def set_tabs(active_menu: :basic, active_sub_menu: :user_card)
    @active_menu = active_menu
    @active_sub_menu = active_sub_menu

    set_variables
  end

  private

  def set_variables
    set_new_sublinks
    set_card_transaction_sublinks
    set_cash_transaction_sublinks

    @main_items = [
      { label: t("tabs.basic"),            icon: "shared/svgs/exchange", link: @new_tab.first.link,              default: @active_menu == :basic },
      { label: t("tabs.card_transaction"), icon: "shared/svgs/wallet",   link: @card_transaction_tab.first.link, default: @active_menu == :card },
      { label: t("tabs.cash_transaction"), icon: "shared/svgs/cash",     link: @cash_transaction_tab.first.link, default: @active_menu == :cash }
    ].map { |item| item.slice(:label, :icon, :link, :default).values }

    @main_tab = @main_items.map do |label, icon, link, default|
      Components::TabsComponent::Item.new(label, icon, link, default, :center_container)
    end

    @main_tab.each { |tab| tab.label = tab.label.split.first } if @mobile

    @sub_tab = [ @new_tab, @card_transaction_tab, @cash_transaction_tab ]
  end

  def set_new_sublinks
    @new_items = [
      { label: t("tabs.user_card"), icon: "shared/svgs/credit_card", link: user_cards_path, default: @active_sub_menu == :user_card },
      { label: t("tabs.category"),  icon: "shared/svgs/category",    link: categories_path, default: @active_sub_menu == :category },
      { label: t("tabs.entity"),    icon: "shared/svgs/user",        link: entities_path,   default: @active_sub_menu == :entity }
    ].map { |item| item.slice(:label, :icon, :link, :default).values }

    @new_tab = @new_items.map do |label, icon, link, default|
      Components::TabsComponent::Item.new(label, icon, link, default, :center_container)
    end
  end

  def set_card_transaction_sublinks
    user_cards = current_user.user_cards.active.pluck(:id, :user_card_name)

    @card_transaction_tab = user_cards.map do |user_card_id, user_card_name|
      default = @active_sub_menu.to_sym == user_card_name.to_sym
      Components::TabsComponent::Item.new(user_card_name, "shared/svgs/credit_card", card_transactions_path(user_card_id:), default, :center_container)
    end
    return unless @card_transaction_tab.empty?

    @card_transaction_tab << Components::TabsComponent::Item.new(t("user_cards.new"), "shared/svgs/credit_card", new_user_card_path, false, :center_container)
  end

  def set_cash_transaction_sublinks
    @cash_transaction_items = [
      { label: t("tabs.pix"),        icon: "shared/svgs/mobile",      link: cash_transactions_path, default: @active_sub_menu == :pix },
      { label: t("tabs.investment"), icon: "shared/svgs/trending_up", link: cash_transactions_path, default: @active_sub_menu == :investment }
    ].map { |item| item.slice(:label, :icon, :link, :default).values }

    @cash_transaction_tab = @cash_transaction_items.map do |label, icon, link, default|
      Components::TabsComponent::Item.new(label, icon, link, default, :center_container)
    end
  end
end
