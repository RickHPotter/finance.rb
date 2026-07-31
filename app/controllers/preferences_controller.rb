# frozen_string_literal: true

class PreferencesController < ApplicationController
  def update
    preference = current_user.preference

    if preference.update(preference_params)
      redirect_back fallback_location: root_path, status: :see_other
    else
      redirect_back fallback_location: root_path, alert: "Could not update preference.", status: :see_other
    end
  end

  private

  def preference_params
    params.require(:user_preference).permit(
      :theme, :landing_page, :page_density, :date_time_presentation,
      :active_context_id, :default_account_id, :default_card_id
    )
  end
end
