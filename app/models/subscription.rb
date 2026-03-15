# frozen_string_literal: true

class Subscription < ApplicationRecord
  # @extends ..................................................................
  self.table_name = "finance_subscriptions"

  enum :status, { active: "active", paused: "paused", finished: "finished" }

  # @includes .................................................................
  include CategoryTransactable
  include EntityTransactable

  # @security (i.e. attr_accessible) ..........................................
  # @relationships ............................................................
  belongs_to :user

  # @validations ..............................................................
  validates :description, :status, presence: true
  validates :price, numericality: true

  # @callbacks ................................................................
  before_validation :set_defaults, on: :create

  # @scopes ...................................................................
  # @additional_config ........................................................
  # @class_methods ............................................................
  # @public_instance_methods ..................................................
  # @protected_instance_methods ...............................................
  # @private_instance_methods .................................................

  private

  def set_defaults
    self.status ||= :active
  end
end

# == Schema Information
#
# Table name: finance_subscriptions
# Database name: primary
#
#  id          :bigint           not null, primary key
#  comment     :text
#  description :string           not null
#  price       :integer          default(0), not null
#  status      :string           default("active"), not null, indexed
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  user_id     :bigint           not null, indexed
#
# Indexes
#
#  index_finance_subscriptions_on_status   (status)
#  index_finance_subscriptions_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
