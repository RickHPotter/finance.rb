# frozen_string_literal: true

# Helper for Context
module ContextHelper
  def set_banks
    @banks = Bank.order(:bank_name).pluck(:bank_name, :id)
  end

  def set_cards
    @cards = Card.order(:card_name).pluck(:card_name, :id)
  end

  def set_user_bank_accounts
    @user_bank_accounts = current_user.user_bank_accounts.active.includes(:bank).order(:agency_number, :account_number).map do |user_bank_account|
      [
        "[#{user_bank_account.bank.bank_name}] #{user_bank_account.agency_number || 'XXXX'} - #{user_bank_account.account_number || 'YY'}",
        user_bank_account.id
      ]
    end
  end

  def set_user_cards
    @user_cards = current_user.user_cards.active.order(:user_card_name).pluck(:user_card_name, :id)
  end

  def set_categories
    @categories = current_user.custom_categories.active.order(:category_name).pluck(:category_name, :id)
  end

  def set_entities
    @entities = current_user.entities.active.order(:entity_name).pluck(:entity_name, :id)
  end

  def set_all_categories
    @categories = current_user.categories.active.order(:category_name).pluck(:category_name, :id)
  end
end
