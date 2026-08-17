# frozen_string_literal: true

class ReferencesController < ApplicationController
  include TabsConcern

  before_action :set_user_card, only: %i[index edit update merge perform_merge]
  before_action :set_reference, only: %i[edit update merge]
  before_action :set_return_to, only: %i[edit update merge perform_merge]
  before_action :set_reference_tabs

  def index
    @references = current_context.references.where(user_card: @user_card)
    render json: @references
  end

  def edit
    render_top_level Views::References::Edit.new(reference: @reference, user_card: @user_card, return_to: @return_to)
  end

  def update
    @reference.skip_reference_closing_date_calculation = true

    if @reference.update(reference_params)
      redirect_to user_card_edit_destination, status: :see_other
    else
      render_top_level Views::References::Edit.new(reference: @reference, user_card: @user_card, return_to: @return_to),
                       status: :unprocessable_content
    end
  end

  def merge
    render_top_level Views::References::Merge.new(reference: @reference, user_card: @user_card, return_to: @return_to)
  end

  def perform_merge
    source_reference_date = "#{merge_reference_params[:source_reference_date]}-01"
    target_reference_date = "#{merge_reference_params[:target_reference_date]}-01"
    merge_mode = merge_reference_params[:merge_mode]
    source_date = source_reference_date.to_date
    @reference = current_context.references.find_by(user_card: @user_card, year: source_date.year, month: source_date.month) ||
                 current_context.references.new(user_card: @user_card, reference_date: source_date)
    @reference.merge_mode = merge_mode

    if perform_reference_merge(source_reference_date, target_reference_date, merge_mode)
      redirect_to user_card_edit_destination, status: :see_other
    else
      if merge_mode.to_s.in?(Logic::References::MERGE_MODES)
        add_reallocation_errors if merge_mode == Logic::References::REALLOCATE_INSTALLMENTS
      else
        @reference.errors.add(:merge_mode, :inclusion)
      end
      render_top_level Views::References::Merge.new(reference: @reference, user_card: @user_card, return_to: @return_to, merge_mode:),
                       status: :unprocessable_content
    end
  end

  private

  def perform_reference_merge(source_reference_date, target_reference_date, merge_mode)
    if merge_mode == Logic::References::REALLOCATE_INSTALLMENTS
      @reallocation_result = Logic::References.reallocation_result(
        @user_card,
        source_reference_date,
        target_reference_date,
        context: current_context
      )
      return @reallocation_result.applied?
    end

    Logic::References.merge(@user_card, source_reference_date, target_reference_date, merge_mode:, context: current_context)
  end

  def add_reallocation_errors
    issues = @reallocation_result.plan.issues
    if issues.present?
      issues.each { |issue| @reference.errors.add(:merge_mode, issue.code, **issue.details) }
    else
      @reference.errors.add(:merge_mode, @reallocation_result.reason_code || :reallocation_blocked)
    end
  end

  def render_top_level(view, status: :ok)
    respond_to do |format|
      format.html { render view, status: }
      format.turbo_stream { render view, formats: :html, content_type: "text/html", status: }
    end
  end

  def set_return_to
    @return_to = Navigation::UserCards.new(raw: params[:return_to], fallback: user_cards_path, current_user:).destination
  end

  def user_card_edit_destination
    return edit_user_card_path(@user_card) if @return_to == user_cards_path

    edit_user_card_path(@user_card, return_to: @return_to)
  end

  def set_reference_tabs
    set_tabs(active_menu: :data, active_sub_menu: :user_card)
  end

  def set_user_card
    @user_card = current_user.user_cards.find(params[:user_card_id])
  end

  def set_reference
    @reference = current_context.references.where(user_card: @user_card).find(params[:id])
  end

  def reference_params
    params.require(:reference).permit(:reference_closing_date, :reference_date)
  end

  def merge_reference_params
    params.permit(:source_reference_date, :target_reference_date, :merge_mode)
  end
end
