# frozen_string_literal: true

# == Schema Information
#
# Table name: transactions
#
#  id             :integer          not null, primary key
#  t_description  :string           not null
#  t_comment      :string
#  date           :date             not null
#  user_id        :integer          not null
#  category_id    :integer          not null
#  starting_price :decimal(, )      not null
#  price          :decimal(, )      not null
#  month          :integer          not null
#  year           :integer          not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
class Transaction < ApplicationRecord
  # @extends ..................................................................
  # @includes .................................................................
  include MonthYear
  include StartingPriceCallback

  # @security (i.e. attr_accessible) ..........................................
  # @relationships ............................................................
  belongs_to :user
  belongs_to :category

  # @validations ..............................................................
  validates :t_description, :date, :user_id, :category_id, :starting_price,
            :price, :month, :year, presence: true

  # @callbacks ................................................................
  before_validation :set_starting_price, on: :create

  # @scopes ...................................................................
  # @public_instance_methods ..................................................
  # @protected_instance_methods ...............................................
  # @private_instance_methods .................................................
end
