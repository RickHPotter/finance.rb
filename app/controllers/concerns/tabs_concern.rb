# frozen_string_literal: true

module TabsConcern
  extend ActiveSupport::Concern

  included do
    before_action :set_user_agent
  end

  def set_user_agent
    # @mobile = true

    return unless request.user_agent =~ /Mobile|Android|iPhone|iPad/

    @mobile = true
  end

  def set_tabs(active_menu: :new, active_sub_menu: :category)
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
      { label: "New",              icon: "shared/svgs/wallet",      link: @new_tab.first.link,              default: @active_menu == :new  },
      { label: "Card Transaction", icon: "shared/svgs/credit_card", link: @card_transaction_tab.first.link, default: @active_menu == :card },
      { label: "Cash Transaction", icon: "shared/svgs/plus",        link: @cash_transaction_tab.first.link, default: @active_menu == :cash }
    ].map { |item| item.slice(:label, :icon, :link, :default).values }

    @main_tab = @main_items.map do |label, icon, link, default|
      Components::TabsComponent::Item.new(label, icon, link, default, :center_container)
    end

    @main_tab.each { |tab| tab.label = tab.label.split.first } if @mobile

    @sub_tab = [ @new_tab, @card_transaction_tab, @cash_transaction_tab ]
  end

  def set_new_sublinks
    can_create_card_transaction = current_user.user_cards.active.present?
    card_transaction_link = can_create_card_transaction ? new_card_transaction_path : new_user_card_path(no_user_card: true, format: :turbo_stream)
    @active_sub_menu = :user_card if @active_sub_menu == :card_transaction && !can_create_card_transaction

    @new_items = [
      { label: "Card",             icon: "shared/svgs/credit_card", link: new_user_card_path,        default: @active_sub_menu == :user_card },
      { label: "Entity",           icon: "shared/svgs/user_group",  link: new_entity_path,           default: @active_sub_menu == :entity },
      { label: "Category",         icon: "shared/svgs/user_group",  link: new_category_path,         default: @active_sub_menu == :category },
      { label: "Card Transaction", icon: "shared/svgs/credit_card", link: card_transaction_link,     default: @active_sub_menu == :card_transaction },
      { label: "Cash Transaction", icon: "shared/svgs/wallet",      link: new_cash_transaction_path, default: @active_sub_menu == :cash_transaction }
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

    @card_transaction_tab << Components::TabsComponent::Item.new("New Card", "shared/svgs/credit_card", new_user_card_path, false, :center_container)
  end

  def set_cash_transaction_sublinks
    @cash_transaction_items = [
      { label: "PIX",        icon: "shared/svgs/wallet", link: cash_transactions_path, default: @active_sub_menu == :pix },
      { label: "Investment", icon: "shared/svgs/wallet", link: cash_transactions_path, default: @active_sub_menu == :investment }
    ].map { |item| item.slice(:label, :icon, :link, :default).values }

    @cash_transaction_tab = @cash_transaction_items.map do |label, icon, link, default|
      Components::TabsComponent::Item.new(label, icon, link, default, :center_container)
    end
  end
end
