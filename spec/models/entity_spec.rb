# == Schema Information
#
# Table name: entities
#
#  id          :integer          not null, primary key
#  entity_name :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  user_id     :integer          not null
#
require 'rails_helper'

RSpec.describe Entity, type: :model do
  pending "add some examples to (or delete) #{__FILE__}"
end
