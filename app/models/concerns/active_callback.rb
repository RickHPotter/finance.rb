# frozen_string_literal: true

# Shared functionality for models with audited price.
module ActiveCallback
  extend ActiveSupport::Concern

  included do
    # @callbacks ..............................................................
    before_validation :set_active, on: :create
  end

  # @protected_instance_methods ...............................................

  protected

  # Sets active state in case it was not previously set.
  #
  # @note This is a method that is called before_validation.
  #
  # @return [void]
  #
  def set_active
    self.active ||= true
  end
end
