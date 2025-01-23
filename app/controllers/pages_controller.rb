# frozen_string_literal: true

# Controller for Pages SPA
class PagesController < ApplicationController
  before_action :set_variables, only: :index

  def index; end

  private

  def set_variables
    @user_cards = current_user.user_cards.pluck(:id, :user_card_name)

    set_new_sublinks
    set_card_transaction_sublinks
    set_cash_transaction_sublinks

    @main_items = [
      { label: "New",              icon: "shared/svgs/wallet",      link: @new_tab.first.link },
      { label: "Card Transaction", icon: "shared/svgs/credit_card", link: @card_transaction_tab.first.link },
      { label: "Cash Transaction", icon: "shared/svgs/plus",        link: @cash_transaction_tab.first.link }
    ].map { |item| item.slice(:label, :icon, :link).values }

    @main_tab = @main_items.map do |label, icon, link|
      TabsComponent::Item.new(label, icon, link, :center_container)
    end

    @sub_tab = [ @new_tab, @card_transaction_tab, @cash_transaction_tab ]
  end

  def set_new_sublinks
    @new_items = [
      { label: "Card",             icon: "shared/svgs/credit_card", link: new_user_card_path },
      { label: "Entity",           icon: "shared/svgs/user_group",  link: new_entity_path },
      { label: "Category",         icon: "shared/svgs/user_group",  link: new_category_path },
      { label: "Card Transaction", icon: "shared/svgs/credit_card", link: new_card_transaction_path },
      { label: "Cash Transaction", icon: "shared/svgs/wallet",      link: new_cash_transaction_path }
    ].map { |item| item.slice(:label, :icon, :link).values }

    @new_tab = @new_items.map do |label, icon, link|
      TabsComponent::Item.new(label, icon, link, :center_container)
    end
  end

  def set_card_transaction_sublinks
    @card_transaction_tab = @user_cards.map do |user_card_id, user_card_name|
      TabsComponent::Item.new(user_card_name, "shared/svgs/credit_card", card_transactions_path(user_card_id:), :center_container)
    end
    return unless @card_transaction_tab.empty?

    @card_transaction_tab << TabsComponent::Item.new("New Card", "shared/svgs/credit_card", new_user_card_path, :center_container)
  end

  def set_cash_transaction_sublinks
    @cash_transaction_items = [
      { label: "PIX",        icon: "shared/svgs/wallet", link: cash_transactions_path },
      { label: "Investment", icon: "shared/svgs/wallet", link: cash_transactions_path }
    ].map { |item| item.slice(:label, :icon, :link).values }

    @cash_transaction_tab = @cash_transaction_items.map do |label, icon, link|
      TabsComponent::Item.new(label, icon, link, :center_container)
    end
  end
end
