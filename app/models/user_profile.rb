# frozen_string_literal: true

class UserProfile < ApplicationRecord
  # @extends ..................................................................
  # @includes .................................................................
  # @security (i.e. attr_accessible) ..........................................
  # @relationships ............................................................
  belongs_to :user

  has_one_attached :avatar

  before_validation :set_display_name

  # @validations ..............................................................
  validates :display_name, :locale, :timezone, presence: true

  private

  def set_display_name
    self.display_name = "#{first_name} #{last_name}".strip
    self.display_name = "User" if display_name.blank?
  end
end

# == Schema Information
#
# Table name: user_profiles
# Database name: primary
#
#  id           :bigint           not null, primary key
#  display_name :string
#  first_name   :string
#  last_name    :string
#  locale       :string           default("en"), not null
#  sex          :string           default("not_specified"), not null
#  timezone     :string           default("UTC"), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  user_id      :bigint           not null, uniquely indexed
#
# Indexes
#
#  index_user_profiles_on_user_id  (user_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
