# frozen_string_literal: true

module Users
  # Overwriting Devise ConfirmationsController
  class ConfirmationsController < Devise::ConfirmationsController
    # Overwriting after_confirmation_path_for
    #
    # @see https://github.com/plataformatec/devise/blob/master/lib/devise/controllers/confirmations_controller.rb
    #
    def after_confirmation_path_for(_resource_name, resource)
      sign_in(resource)
      root_path
    end
  end
end
