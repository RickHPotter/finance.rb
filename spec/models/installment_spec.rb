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
require 'rails_helper'

RSpec.describe Installment, type: :model do
  pending "add some examples to (or delete) #{__FILE__}"
end
