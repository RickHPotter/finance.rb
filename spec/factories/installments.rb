# frozen_string_literal: true

# == Schema Information
#
# Table name: installments
#
#  id               :bigint           not null, primary key
#  price            :decimal(10, 2)   default(0.0), not null
#  number           :integer          default(1), not null
#  paid             :boolean          default(FALSE), not null
#  installable_type :string           not null
#  installable_id   :bigint           not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
FactoryBot.define do
  factory :installment do
    price { '9.99' }
    number { 1 }
    paid { false }
  end
end
