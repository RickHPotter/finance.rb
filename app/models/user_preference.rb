# frozen_string_literal: true

class UserPreference < ApplicationRecord
  # @extends ..................................................................
  # @includes .................................................................
  # @security (i.e. attr_accessible) ..........................................
  enum :theme, { system: "system", light: "light", dark: "dark" }, suffix: true

  enum :exchange_default_bound_type, { standalone: "standalone", card_bound: "card_bound" }, suffix: true
  enum :row_color_mode, { badges_only: "badges_only", row_coloured: "row_coloured" }, suffix: true
  enum :default_card_transaction_date_order, { card_installment_date: "card_installment_date", card_transaction_date: "card_transaction_date" }, suffix: true
  enum :default_cash_transaction_date_order, { cash_installment_date: "cash_installment_date", cash_transaction_date: "cash_transaction_date" }, suffix: true

  # @relationships ............................................................
  belongs_to :user
  belongs_to :active_context, class_name: "Context", optional: true
  belongs_to :default_cash_transaction_user_bank_account, class_name: "UserBankAccount", optional: true

  # @validations ..............................................................
  validates :theme, :exchange_default_bound_type, :row_color_mode,
            :default_card_transaction_date_order, :default_cash_transaction_date_order, presence: true
end

# == Schema Information
#
# Table name: user_preferences
# Database name: primary
#
#  id                                            :bigint           not null, primary key
#  default_card_transaction_date_order           :string           default("card_installment_date"), not null
#  default_cash_transaction_date_order           :string           default("cash_installment_date"), not null
#  exchange_default_bound_type                   :string           default("standalone"), not null
#  landing_page                                  :string           default("cash_transactions"), not null
#  row_color_mode                                :string           default("row_coloured"), not null
#  theme                                         :string           default("light"), not null
#  created_at                                    :datetime         not null
#  updated_at                                    :datetime         not null
#  active_context_id                             :integer
#  default_cash_transaction_user_bank_account_id :integer
#  user_id                                       :bigint           not null, uniquely indexed
#
# Indexes
#
#  index_user_preferences_on_user_id  (user_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
