# frozen_string_literal: true

class UserCardsController < ApplicationController
  include TabsConcern

  before_action :set_user_card, only: %i[show edit update destroy]
  before_action :set_user, :set_cards, :set_user_cards, :set_entities, :set_categories, only: %i[new create edit update]

  def index
    params[:include_inactive] ||= "false"
    conditions = { active: [ true, !JSON.parse(params[:include_inactive]) ] }
    @user_cards = @user.user_cards.includes(:card).where(conditions)
  end

  def show; end

  def new
    @user_card = UserCard.new
  end

  def create
    @user_card = UserCard.new(user_card_params)

    if @user_card.save
      set_user_cards
      set_tabs(active_menu: :new, active_sub_menu: :card_transaction)
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace(:center_container, partial: "card_transactions/new", locals: { card_transaction: @user_card.card_transactions.new }),
            turbo_stream.replace(:notification, partial: "shared/flash", locals: { notice: "A card has been created." }),
            turbo_stream.replace(:tabs, partial: "shared/tabs")
          ]
        end
      end
    else
      respond_to do |format|
        format.turbo_stream do
          # FIXME: when with errors, priceInput should applyMask again
          render turbo_stream: turbo_stream.update(:notification, partial: "shared/flash", locals: { alert: "Something is wrong." })
        end
      end
    end
  end

  def edit; end

  def update
    # if @card_transaction.update(card_transaction_params)
    #   flash[:notice] = "Card Transaction was successfully updated."
    # else
    #   flash[:alert] = @card_transaction.errors.full_messages
    # end

    respond_to(&:turbo_stream)
  end

  def destroy
    # if @card_transaction.destroy
    #   flash[:notice] = "Card Transaction was successfully destroyed."
    # else
    #   flash[:alert] = @card_transaction.errors.full_messages
    # end

    respond_to(&:turbo_stream)
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_user_card
    @user_card = UserCard.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def user_card_params
    params.require(:user_card).permit(:user_card_name, :days_until_due_date, :current_closing_date, :current_due_date, :min_spend,
                                      :credit_limit, :active, :user_id, :card_id)
  end
end
