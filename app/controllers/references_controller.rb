# frozen_string_literal: true

class ReferencesController < ApplicationController
  before_action :set_user_card, only: %i[index edit update]
  before_action :set_reference, only: %i[edit update]

  def index
    @references = @user_card.references
    render json: @references
  end

  def edit
    # The view will be rendered automatically
  end

  def update
    if @reference.update_columns(reference_params)
      redirect_to edit_user_card_path(@user_card), notice: "Reference was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_user_card
    @user_card = current_user.user_cards.find(params[:user_card_id])
  end

  def set_reference
    @reference = @user_card.references.find(params[:id])
  end

  def reference_params
    params.require(:reference).permit(:reference_closing_date, :reference_date)
  end
end
