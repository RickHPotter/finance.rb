# frozen_string_literal: true

class ProfilesController < ApplicationController
  include TabsConcern

  before_action :set_basic_tabs

  def edit
    @profile = current_user.profile
    @preference = current_user.preference
    @user_bank_accounts = current_user.user_bank_accounts.active
    @user_cards = current_user.user_cards.active

    render Views::Profiles::Edit.new(
      profile: @profile,
      preference: @preference,
      user_bank_accounts: @user_bank_accounts,
      user_cards: @user_cards
    )
  end

  def update # rubocop:disable Metrics/AbcSize
    @profile = current_user.profile
    @preference = current_user.preference

    ActiveRecord::Base.transaction do
      @profile.update!(profile_params) if params[:user_profile].present?
      @preference.update!(preference_params) if params[:user_preference].present?
    end

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.update(:notification, partial: "shared/flash", locals: { notice: "Profile updated successfully" })
        ]
      end
      format.html { redirect_to edit_profile_path, notice: "Profile updated successfully" }
    end
  rescue ActiveRecord::RecordInvalid
    @profile.validate if params[:user_profile].present?
    @preference.validate if params[:user_preference].present?
    @user_bank_accounts = current_user.user_bank_accounts.active
    @user_cards = current_user.user_cards.active
    render Views::Profiles::Edit.new(
      profile: @profile,
      preference: @preference,
      user_bank_accounts: @user_bank_accounts,
      user_cards: @user_cards
    ), status: :unprocessable_entity
  end

  private

  def set_basic_tabs
    set_tabs(active_menu: :hub, active_sub_menu: :profile)
  end

  def profile_params
    params.require(:user_profile).permit(:display_name, :first_name, :last_name, :locale, :timezone)
  end

  def preference_params
    params.require(:user_preference).permit(
      :theme, :landing_page, :page_density, :date_time_presentation,
      :exchange_default_bound_type, :row_color_mode, :default_account_id,
      :default_card_id, :default_cash_transaction_user_bank_account_id
    )
  end
end
