# frozen_string_literal: true

class UserCardsController < ApplicationController
  include TabsConcern

  before_action :set_user, only: %i[index new create edit update destroy]
  before_action :set_user_card, only: %i[edit update destroy]
  before_action :set_cards, :set_user_cards, :set_entities, :set_categories, only: %i[new create edit update]

  def index
    params[:include_inactive] ||= "false"
    conditions = { active: [ true, !JSON.parse(params[:include_inactive]) ] }
    @user_cards = current_user.user_cards.includes(:card).where(conditions)
  end

  def new
    @user_card = UserCard.new
  end

  def create
    @user_card = Logic::UserCards.create(user_card_params)
    @card_transaction = Logic::CardTransactions.create_from_user_card(@user_card) if @user_card.valid?

    # FIXME: handle this monstrosity by creating .turbo_stream.erb files
    if @card_transaction
      respond_to do |format|
        set_user_cards
        set_tabs(active_menu: :new, active_sub_menu: :card_transaction)
        format.turbo_stream do
          render turbo_stream: [ turbo_stream.replace(:center_container, template: "card_transactions/new", locals: { card_transaction: @card_transaction }),
                                 turbo_stream.replace(:notification, partial: "shared/flash", locals: { notice: "Card has been created." }),
                                 turbo_stream.replace(:tabs, partial: "shared/tabs") ]
        end
      end
    else
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [ turbo_stream.replace(:center_container, template: "user_cards/new", locals: { user_card: @user_card }),
                                 turbo_stream.update(:notification, partial: "shared/flash", locals: { alert: "Something is wrong." }) ]
        end
      end
    end
  end

  def edit; end

  def update # rubocop:disable all
    @user_card = Logic::UserCards.update(@user_card, user_card_params)
    @card_transaction = Logic::CardTransactions.create_from_user_card(@user_card) if @user_card.valid?

    # FIXME: handle this monstrosity by creating .turbo_stream.erb files
    if @card_transaction
      respond_to do |format|
        format.turbo_stream do
          set_user_cards
          if @user_card.active?
            set_tabs(active_menu: :new, active_sub_menu: :card_transaction)
            render turbo_stream: [ turbo_stream.replace(:center_container, template: "card_transactions/new", locals: { card_transaction: @card_transaction }),
                                   turbo_stream.replace(:notification, partial: "shared/flash", locals: { notice: "Card has been updated." }),
                                   turbo_stream.replace(:tabs, partial: "shared/tabs") ]
          else
            index
            render turbo_stream: [ turbo_stream.replace(:center_container, template: "user_cards/index") ]
          end
        end
      end
    else
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [ turbo_stream.replace(:center_container, template: "user_cards/new", locals: { user_card: @user_card }),
                                 turbo_stream.update(:notification, partial: "shared/flash", locals: { alert: "Something is wrong." }) ]
        end
      end
    end
  end

  def destroy
    respond_to do |format|
      format.turbo_stream do
        index
        if @user_card.card_transactions.empty?
          @user_card.destroy
          render turbo_stream: [ turbo_stream.replace(:center_container, template: "user_cards/index"),
                                 turbo_stream.update(:notification, partial: "shared/flash", locals: { notice: "Card has been deleted." }) ]
        else
          render turbo_stream: [ turbo_stream.update(:notification, partial: "shared/flash", locals: { alert: "User Card with transactions cannot be deleted." }) ]
        end
      end
    end
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
