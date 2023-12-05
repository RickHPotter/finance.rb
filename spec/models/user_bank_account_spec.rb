# == Schema Information
#
# Table name: user_bank_accounts
#
#  id             :integer          not null, primary key
#  agency_number  :integer
#  account_number :integer
#  user_id        :integer          not null
#  bank_id        :integer          not null
#  active         :boolean          default(TRUE), not null
#  balance        :decimal(, )      default(0.0), not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
require 'rails_helper'

RSpec.describe UserBankAccount, type: :model do
  pending "add some examples to (or delete) #{__FILE__}"
end
