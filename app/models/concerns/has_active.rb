# frozen_string_literal: true

# Shared functionality for models with audited price.
module HasActive
  extend ActiveSupport::Concern

  included do
    # @callbacks ..............................................................
    before_validation :set_active, on: :create

    # @validations ............................................................
    validates :active, inclusion: { in: [ true, false ] }

    # @scopes ...................................................................
    scope :active, -> { where(active: true) }
  end

  # @public_class_methods .....................................................
  def inactive?
    !active
  end

  # @protected_instance_methods ...............................................

  protected

  # Sets `active` in case it was not previously set.
  #
  # @note This is a method that is called before_validation.
  #
  # @return [void].
  #
  def set_active
    return if [ false, true ].include?(active)

    self.active = true
  end
end
