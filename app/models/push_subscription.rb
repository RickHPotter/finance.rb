# frozen_string_literal: true

class PushSubscription < ApplicationRecord
  # @extends ..................................................................
  self.table_name = "subscriptions"

  # @includes .................................................................
  # @security (i.e. attr_accessible) ..........................................
  # @relationships ............................................................
  belongs_to :user

  # @validations ..............................................................
  # @callbacks ................................................................
  # @scopes ...................................................................
  # @additional_config ........................................................
  # @class_methods ............................................................
  # @public_instance_methods ..................................................
end

# == Schema Information
#
# Table name: subscriptions
# Database name: primary
#
#  id         :bigint           not null, primary key
#  auth       :text
#  endpoint   :text
#  p256dh     :text
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :bigint           not null, indexed
#
# Indexes
#
#  index_subscriptions_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
