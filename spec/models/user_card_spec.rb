# == Schema Information
#
# Table name: user_cards
#
#  id           :integer          not null, primary key
#  user_id      :integer          not null
#  card_id      :integer          not null
#  card_name    :string           not null
#  due_date     :integer          not null
#  min_spend    :decimal(, )      not null
#  credit_limit :decimal(, )      not null
#  active       :boolean          not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
require 'rails_helper'

RSpec.describe UserCard, type: :model do
  pending "add some examples to (or delete) #{__FILE__}"
end
