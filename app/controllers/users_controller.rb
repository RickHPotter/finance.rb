# frozen_string_literal: true

class UsersController < ApplicationController
  def update_locale
    current_user.update_columns(locale: params[:locale])
    redirect_back fallback_location: root_path
  end
end
