# frozen_string_literal: true

class Reference < ApplicationRecord
  # @extends ..................................................................
  # @includes .................................................................
  # @security (i.e. attr_accessible) ..........................................
  # @relationships ............................................................
  belongs_to :user_card

  # @validations ..............................................................
  validates :month, :year, :reference_date, presence: true
  validates :user_card_id, uniqueness: { scope: %i[month year] }
  validates :reference_date, uniqueness: { scope: :user_card_id }

  # @callbacks ................................................................
  before_save :set_reference_closing_date

  # @scopes ...................................................................
  # @additional_config ........................................................
  # @class_methods ............................................................
  # @public_instance_methods ..................................................
  def self.find_by_month_year(month_year)
    month = month_year.month
    year = month_year.year

    find_by(month:, year:)
  end

  # @protected_instance_methods ...............................................

  protected

  def set_reference_closing_date
    self.reference_closing_date = if user_card.nil?
                                    reference_date - 1.day
                                  else
                                    reference_date - user_card.days_until_due_date.days
                                  end
  end
  # @private_instance_methods .................................................
end

# == Schema Information
#
# Table name: references
#
#  id                     :bigint           not null, primary key
#  month                  :integer          not null, indexed => [user_card_id, year]
#  reference_closing_date :date             not null
#  reference_date         :date             not null
#  year                   :integer          not null, indexed => [user_card_id, month]
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  user_card_id           :bigint           not null, indexed => [month, year], indexed
#
# Indexes
#
#  idx_references_user_card_month_year  (user_card_id,month,year) UNIQUE
#  index_references_on_user_card_id     (user_card_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_card_id => user_cards.id)
#
