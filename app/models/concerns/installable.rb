# frozen_string_literal: true

# Shared functionality for models that can produce Installments.
module Installable
  extend ActiveSupport::Concern

  included do
    # @relationships ..........................................................
    has_many :installments, as: :installable, dependent: :destroy
    accepts_nested_attributes_for :installments, allow_destroy: true, reject_if: :all_blank
  end

  # @public_class_methods .....................................................
  # @protected_instance_methods ...............................................
end
