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

  def set_user
    @user = current_user if user_signed_in?
  end

  def set_cards
    @cards = Card.order(:card_name).pluck(:card_name, :id)
  end

  def set_user_cards
    @user_cards = @user.user_cards.active.order(:user_card_name).pluck(:user_card_name, :id)
  end

  def set_categories
    @categories = @user.custom_categories.active.order(:category_name).pluck(:category_name, :id)
  end

  def set_entities
    @entities = @user.entities.active.order(:entity_name).pluck(:entity_name, :id)
  end
end
