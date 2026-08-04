# frozen_string_literal: true

class CreateUserPreferences < ActiveRecord::Migration[8.1]
  def change
    create_table :user_preferences do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.string :theme, null: false, default: "system"
      t.string :landing_page, null: false, default: "cash_transactions"
      t.integer :active_context_id

      t.string :exchange_default_bound_type, default: "standalone", null: false
      t.string :row_color_mode, default: "badges_only", null: false
      t.integer :default_cash_transaction_user_bank_account_id

      t.string :default_card_transaction_date_order, default: "card_installment_date", null: false
      t.string :default_cash_transaction_date_order, default: "cash_transaction_date", null: false

      t.timestamps
    end

    up_only do
      User.find_each do |user|
        UserPreference.create!(
          user_id: user.id,
          theme: "system",
          landing_page: "cash_transactions",
          active_context_id: user.contexts.first&.id
        )
      end
    end
  end
end
