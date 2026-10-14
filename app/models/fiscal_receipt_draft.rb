# frozen_string_literal: true

class FiscalReceiptDraft < ApplicationRecord
  # @extends ..................................................................
  # @includes ................................................................
  # @security (i.e. attr_accessible) ..........................................
  # @relationships ............................................................
  belongs_to :user
  has_one_attached :source

  # @validations ..............................................................
  validates :payload, presence: true
  validate :payload_follows_contract
  validates :source,
            content_type: %w[application/json application/pdf image/jpeg image/png image/heic application/xml text/xml],
            size: { less_than_or_equal_to: 10.megabytes },
            limit: { max: 1 }

  # @callbacks ................................................................
  # @scopes ...................................................................
  scope :recent, -> { order(created_at: :desc, id: :desc) }

  # @additional_config ........................................................
  # @class_methods ............................................................
  # @public_instance_methods ..................................................
  def fiscal_draft
    payload.deep_stringify_keys
  end

  # @protected_instance_methods ...............................................
  # @private_instance_methods ................................................
  private

  def payload_follows_contract
    unless payload.is_a?(Hash) && payload.present?
      errors.add(:payload, :invalid)
      return
    end

    errors.add(:payload, :too_long, count: 256.kilobytes) if payload.to_json.bytesize > 256.kilobytes
  end
end
