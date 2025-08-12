# frozen_string_literal: true

class UsersController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[update_locale]

  def update_locale
    if current_user
      current_user.update_columns(locale: params[:locale])
    else
      I18n.locale = params[:locale]
    end

    redirect_back fallback_location: root_path
  end
end
