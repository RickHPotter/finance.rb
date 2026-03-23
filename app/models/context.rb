# frozen_string_literal: true

class Context < ApplicationRecord
  belongs_to :user
  belongs_to :source_context, class_name: "Context", optional: true

  has_many :derived_contexts, class_name: "Context", foreign_key: :source_context_id, dependent: :nullify, inverse_of: :source_context

  validates :name, presence: true, uniqueness: { scope: :user_id }
  validates :main, inclusion: { in: [ true, false ] }

  scope :main, -> { where(main: true) }
  scope :derived, -> { where(main: false) }

  def archived?
    archived_at.present?
  end
end
