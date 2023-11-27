# frozen_string_literal: true

# Controller for CardTransaction
class CardTransactionsController < ApplicationController
  before_action :set_card_transaction, only: %i[show edit update destroy]
  before_action :set_cards, only: %i[new edit]
  before_action :set_entities, only: %i[new edit]
  before_action :set_categories, only: %i[new edit]

  def index
    # WARNING: Do I need installments in this eager load?
    @card_transactions = CardTransaction.all.eager_load(:card, :category, :entity, :installments)
  end

  def show; end

  def new
    @card_transaction = CardTransaction.new
  end

  def edit; end

  def create
    @card_transaction = CardTransaction.new(card_transaction_params)

    respond_to do |format|
      if @card_transaction.save
        format.html { redirect_to card_transactions_path }
      else
        format.html { render card_transactions_path, status: :unprocessable_entity }
      end
      format.turbo_stream
    end
  end

  def update
    respond_to do |format|
      if @card_transaction.update(card_transaction_params)
        format.html { redirect_to card_transactions_path, notice: 'Card Transaction was successfully updated.' }
      else
        format.html { render card_transactions_path, status: :unprocessable_entity }
      end
      format.turbo_stream
    end
  end

  def destroy
    @card_transaction.destroy
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to card_transactions_url, notice: 'Card Transaction was successfully destroyed.' }
    end
  end

  def clear_message
    respond_to(&:turbo_stream)
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_card_transaction
    @card_transaction = CardTransaction.find(params[:id])
  end

  # FIXME: NOT all cards, but only UserCards, SAME FOR CATEGORIES AND ENTITIES
  def set_cards
    @cards = Card.all.order(:card_name).pluck(:id, :card_name)
  end

  def set_entities
    @entities = Entity.all.order(:entity_name).pluck(:id, :entity_name)
  end

  def set_categories
    @categories = Category.all.order(:description).pluck(:id, :description)
  end

  # Only allow a list of trusted parameters through.
  def card_transaction_params
    params.require(:card_transaction).permit(
      :date, :card_id, :ct_description, :ct_comment, :category_id, :category2_id, :entity_id,
      :price, :month, :year, :installments, :installments_count
    )
  end
end
