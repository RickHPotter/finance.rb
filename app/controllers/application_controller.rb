# frozen_string_literal: true

# God Controller
class ApplicationController < ActionController::Base
  # @callbacks ...............................................................
  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :authenticate_user!

  # @protected_instance_methods ..............................................
  protected

  # Configure permitted parameters for Devise controllers.
  #
  # @return [void].
  #
  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: %i[first_name last_name])
    devise_parameter_sanitizer.permit(:account_update, keys: %i[first_name last_name])
  end

  def set_banks
    @banks = Bank.order(:bank_name).pluck(:bank_name, :id)
  end

  def set_cards
    @cards = Card.order(:card_name).pluck(:card_name, :id)
  end

  def set_user_bank_accounts
    @user_bank_accounts = current_user.user_bank_accounts.active.order(:agency_number, :account_number).map do |user_bank_account|
      [ "#{user_bank_account.agency_number} - #{user_bank_account.account_number}", user_bank_account.id ]
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
