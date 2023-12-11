# frozen_string_literal: true

# Shared functionality for models with audited price.
module ActiveCallback
  extend ActiveSupport::Concern

  included do
    before_validation :set_active, on: :create
  end

  # @protected_instance_methods ...............................................

  protected

  # Sets active state in case it was not previously set.
  #
  # @note This is a callback that is called before_validation.
  #
  # @return [void]
  #
  def set_active
    self.active ||= true
  end
end
