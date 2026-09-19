# frozen_string_literal: true

class BabyName < ApplicationRecord
  # @extends ..................................................................
  # @includes .................................................................
  # @security (i.e. attr_accessible) ..........................................
  # @relationships ............................................................
  has_many :baby_name_decisions, dependent: :destroy
  has_many :users, through: :baby_name_decisions

  # @validations ..............................................................
  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :position, presence: true, numericality: { only_integer: true, greater_than: 0 }

  # @callbacks ................................................................
  before_validation :normalize_capitalization

  # @scopes ...................................................................
  scope :active, -> { where(active: true) }
  scope :in_display_order, -> { order(:position, :id) }
  scope :unreviewed_by, ->(user) { where.not(id: user.baby_name_decisions.select(:baby_name_id)) }

  # @additional_config ........................................................
  # @class_methods ............................................................
  def self.canonical_name(str)
    str.to_s.strip.split(/\s+/).map(&:capitalize).join(" ")
  end

  # @public_instance_methods ..................................................
  # @protected_instance_methods ...............................................
  # @private_instance_methods .................................................
  def normalize_capitalization
    self.name = self.class.canonical_name(name) if name.present?
  end
end

# == Schema Information
#
# Table name: baby_names
# Database name: primary
#
#  id         :bigint           not null, primary key
#  active     :boolean          default(TRUE), not null, indexed => [position]
#  name       :string           not null
#  position   :integer          not null, indexed => [active]
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_baby_names_on_active_and_position  (active,position)
#  index_baby_names_on_lower_name           (lower((name)::text)) UNIQUE
#
