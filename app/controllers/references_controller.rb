# frozen_string_literal: true

class ReferencesController < ApplicationController
  before_action :set_user_card, only: %i[index edit update merge perform_merge]
  before_action :set_reference, only: %i[edit update merge]

  def index
    @references = @user_card.references
    render json: @references
  end

  def edit
    # The view will be rendered automatically
  end

  def update
    if @reference.update(reference_params)
      redirect_to edit_user_card_path(@user_card), notice: "Reference was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def merge; end

  def perform_merge
    source_reference_date = "#{merge_reference_params[:source_reference_date]}-01"
    target_reference_date = "#{merge_reference_params[:target_reference_date]}-01"

    if Logic::References.merge(@user_card, source_reference_date, target_reference_date)
      redirect_to edit_user_card_path(@user_card), notice: "References were successfully merged."
    else
      render :merge, status: :unprocessable_entity
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

  def merge_reference_params
    params.permit(:source_reference_date, :target_reference_date)
  end
end
