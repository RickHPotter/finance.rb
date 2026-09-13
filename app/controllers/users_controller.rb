# frozen_string_literal: true

class UsersController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[update_locale]

  def update_locale
    redirect_back fallback_location: root_path
  end
end
