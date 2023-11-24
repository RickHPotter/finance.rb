# frozen_string_literal: true

# == Schema Information
#
# Table name: users
#
#  id                     :integer          not null, primary key
#  email                  :string           default(""), not null
#  encrypted_password     :string           default(""), not null
#  reset_password_token   :string
#  reset_password_sent_at :datetime
#  remember_created_at    :datetime
#  confirmation_token     :string
#  first_name             :string           not null
#  last_name              :string           not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  confirmed_at           :datetime
#  confirmation_sent_at   :datetime
#  unconfirmed_email      :string
#
class User < ApplicationRecord
  # extends ..................................................................
  # TODO: Add :confirmable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # includes ..................................................................
  # security (i.e. attr_accessible) ...........................................
  # relationships .............................................................
  has_many :user_cards
  has_many :card_transactions
  has_many :categories
  has_many :entities

  # validations ...............................................................
  validates :first_name, :last_name, :email, presence: true
  validates :email, uniqueness: true

  # callbacks .................................................................
  # scopes ....................................................................
  # additional config .........................................................
  # class methods .............................................................
  # public instance methods ...................................................
  def full_name
    "#{first_name} #{last_name}"
  end

  # protected instance methods ................................................
  # private instance methods ..................................................
end

# TODO: Following Features:
# - Implement confirmable
