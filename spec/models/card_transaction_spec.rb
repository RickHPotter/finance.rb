# frozen_string_literal: true

# == Schema Information
#
# Table name: card_transactions
#
#  id                 :integer          not null, primary key
#  date               :date             not null
#  ct_description     :string           not null
#  ct_comment         :text
#  category_id        :integer          not null
#  category2_id       :integer
#  entity_id          :integer          not null
#  starting_price     :decimal(, )      not null
#  price              :decimal(, )      not null
#  month              :integer          not null
#  year               :integer          not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  installments_count :integer          default(0), not null
#  card_id            :integer          not null
#  user_id            :integer          not null
#
require 'rails_helper'

RSpec.describe CardTransaction, type: :model do
  pending "add some examples to (or delete) #{__FILE__}"
end
