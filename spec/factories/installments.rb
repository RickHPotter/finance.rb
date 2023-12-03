# frozen_string_literal: true

# == Schema Information
#
# Table name: installments
#
#  id               :integer          not null, primary key
#  installable_type :string           not null
#  installable_id   :integer          not null
#  price            :decimal(10, 2)   default(0.0), not null
#  number           :integer          default(1), not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
FactoryBot.define do
  factory :installment do
  end
end
