# frozen_string_literal: true

module BabyNamesAccess
  extend ActiveSupport::Concern

  ALLOWED_USER_IDS = [ 1, 4 ].freeze

  included do
    before_action :ensure_baby_names_access
  end

  private

  def ensure_baby_names_access
    return if current_user&.id&.in?(ALLOWED_USER_IDS)

    redirect_to root_path, status: :see_other
  end
end
