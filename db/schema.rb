# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_08_01_132224) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"

  create_table "banks", force: :cascade do |t|
    t.string "bank_name", null: false
    t.integer "bank_code", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "budget_categories", force: :cascade do |t|
    t.bigint "budget_id", null: false
    t.bigint "category_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["budget_id", "category_id"], name: "index_budget_categories_on_composite_key", unique: true
    t.index ["budget_id"], name: "index_budget_categories_on_budget_id"
    t.index ["category_id"], name: "index_budget_categories_on_category_id"
  end

  create_table "budget_entities", force: :cascade do |t|
    t.bigint "budget_id", null: false
    t.bigint "entity_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["budget_id", "entity_id"], name: "index_budget_entities_on_composite_key", unique: true
    t.index ["budget_id"], name: "index_budget_entities_on_budget_id"
    t.index ["entity_id"], name: "index_budget_entities_on_entity_id"
  end

  create_table "budgets", force: :cascade do |t|
    t.integer "order_id"
    t.string "description", null: false
    t.integer "month", null: false
    t.integer "year", null: false
    t.integer "value", null: false
    t.integer "starting_value", null: false
    t.integer "remaining_value", null: false
    t.integer "balance"
    t.boolean "inclusive", default: true, null: false
    t.boolean "active", default: true, null: false
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id"], name: "idx_budgets_order_id"
    t.index ["user_id"], name: "index_budgets_on_user_id"
  end

  create_table "card_transactions", force: :cascade do |t|
    t.string "description", null: false
    t.text "comment"
    t.datetime "date", null: false
    t.integer "month", null: false
    t.integer "year", null: false
    t.integer "starting_price", null: false
    t.integer "price", null: false
    t.boolean "paid", default: false
    t.boolean "imported", default: false
    t.integer "card_installments_count", default: 0, null: false
    t.bigint "user_id", null: false
    t.bigint "user_card_id", null: false
    t.bigint "advance_cash_transaction_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["advance_cash_transaction_id"], name: "index_card_transactions_on_advance_cash_transaction_id"
    t.index ["description"], name: "idx_card_transactions_description_trgm", opclass: :gin_trgm_ops, using: :gin
    t.index ["price"], name: "idx_card_transactions_price"
    t.index ["user_card_id"], name: "index_card_transactions_on_user_card_id"
    t.index ["user_id"], name: "index_card_transactions_on_user_id"
  end

  create_table "cards", force: :cascade do |t|
    t.string "card_name", null: false
    t.bigint "bank_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["bank_id"], name: "index_cards_on_bank_id"
    t.index ["card_name"], name: "index_cards_on_card_name", unique: true
  end

  create_table "cash_transactions", force: :cascade do |t|
    t.string "description", null: false
    t.text "comment"
    t.datetime "date", null: false
    t.integer "month", null: false
    t.integer "year", null: false
    t.integer "starting_price", null: false
    t.integer "price", null: false
    t.boolean "paid", default: false
    t.boolean "imported", default: false
    t.string "cash_transaction_type"
    t.integer "cash_installments_count", default: 0, null: false
    t.bigint "user_id", null: false
    t.bigint "user_card_id"
    t.bigint "user_bank_account_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_bank_account_id"], name: "index_cash_transactions_on_user_bank_account_id"
    t.index ["user_card_id"], name: "index_cash_transactions_on_user_card_id"
    t.index ["user_id"], name: "index_cash_transactions_on_user_id"
  end

  create_table "categories", force: :cascade do |t|
    t.string "category_name", null: false
    t.boolean "built_in", default: false, null: false
    t.boolean "active", default: true, null: false
    t.string "colour", default: "white", null: false
    t.integer "card_transactions_count", default: 0, null: false
    t.integer "card_transactions_total", default: 0, null: false
    t.integer "cash_transactions_count", default: 0, null: false
    t.integer "cash_transactions_total", default: 0, null: false
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "category_name"], name: "index_category_name_on_composite_key", unique: true
    t.index ["user_id"], name: "index_categories_on_user_id"
  end

  create_table "category_transactions", force: :cascade do |t|
    t.bigint "category_id", null: false
    t.string "transactable_type", null: false
    t.bigint "transactable_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id", "transactable_type", "transactable_id"], name: "index_category_transactions_on_composite_key", unique: true
    t.index ["category_id"], name: "index_category_transactions_on_category_id"
    t.index ["transactable_type", "transactable_id"], name: "index_category_transactions_on_transactable"
  end

  create_table "entities", force: :cascade do |t|
    t.string "entity_name", null: false
    t.boolean "active", default: true, null: false
    t.string "avatar_name", default: "people/0.png", null: false
    t.integer "card_transactions_count", default: 0, null: false
    t.integer "card_transactions_total", default: 0, null: false
    t.integer "cash_transactions_count", default: 0, null: false
    t.integer "cash_transactions_total", default: 0, null: false
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "entity_name"], name: "index_entity_name_on_composite_key", unique: true
    t.index ["user_id"], name: "index_entities_on_user_id"
  end

  create_table "entity_transactions", force: :cascade do |t|
    t.boolean "is_payer", default: false, null: false
    t.integer "status", default: 0, null: false
    t.integer "price", default: 0, null: false
    t.integer "price_to_be_returned", default: 0, null: false
    t.integer "exchanges_count", default: 0, null: false
    t.bigint "entity_id", null: false
    t.string "transactable_type", null: false
    t.bigint "transactable_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["entity_id", "transactable_type", "transactable_id"], name: "index_entity_transactions_on_composite_key", unique: true
    t.index ["entity_id"], name: "index_entity_transactions_on_entity_id"
    t.index ["transactable_type", "transactable_id"], name: "index_entity_transactions_on_transactable"
  end

  create_table "exchanges", force: :cascade do |t|
    t.string "bound_type", default: "standalone", null: false
    t.integer "exchange_type", default: 0, null: false
    t.integer "number", default: 1, null: false
    t.integer "starting_price", null: false
    t.integer "price", null: false
    t.integer "exchanges_count", default: 0, null: false
    t.bigint "entity_transaction_id", null: false
    t.bigint "cash_transaction_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "date", null: false
    t.integer "month", null: false
    t.integer "year", null: false
    t.index ["cash_transaction_id"], name: "index_exchanges_on_cash_transaction_id"
    t.index ["entity_transaction_id"], name: "index_exchanges_on_entity_transaction_id"
  end

  create_table "installments", force: :cascade do |t|
    t.integer "order_id"
    t.integer "number", null: false
    t.datetime "date", null: false
    t.virtual "date_year", type: :integer, null: false, as: "EXTRACT(year FROM date)", stored: true
    t.virtual "date_month", type: :integer, null: false, as: "EXTRACT(month FROM date)", stored: true
    t.integer "month", null: false
    t.integer "year", null: false
    t.integer "starting_price", null: false
    t.integer "price", null: false
    t.integer "balance"
    t.boolean "paid", default: false
    t.string "installment_type", null: false
    t.integer "card_installments_count", default: 0
    t.integer "cash_installments_count", default: 0
    t.bigint "card_transaction_id"
    t.bigint "cash_transaction_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["card_transaction_id"], name: "index_installments_on_card_transaction_id"
    t.index ["cash_transaction_id"], name: "index_installments_on_cash_transaction_id"
    t.index ["date_year", "date_month", "date"], name: "idx_installments_year_month_date"
    t.index ["order_id"], name: "idx_installments_order_id"
    t.index ["price"], name: "idx_installments_price"
  end

  create_table "investments", force: :cascade do |t|
    t.string "description"
    t.datetime "date", null: false
    t.integer "month", null: false
    t.integer "year", null: false
    t.integer "price", null: false
    t.bigint "user_id", null: false
    t.bigint "user_bank_account_id", null: false
    t.bigint "cash_transaction_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cash_transaction_id"], name: "index_investments_on_cash_transaction_id"
    t.index ["user_bank_account_id"], name: "index_investments_on_user_bank_account_id"
    t.index ["user_id"], name: "index_investments_on_user_id"
  end

  create_table "references", force: :cascade do |t|
    t.bigint "user_card_id", null: false
    t.integer "month", null: false
    t.integer "year", null: false
    t.date "reference_closing_date", null: false
    t.date "reference_date", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_card_id", "month", "year"], name: "idx_references_user_card_month_year", unique: true
    t.index ["user_card_id"], name: "index_references_on_user_card_id"
  end

  create_table "user_bank_accounts", force: :cascade do |t|
    t.string "user_bank_account_name"
    t.integer "agency_number"
    t.integer "account_number"
    t.boolean "active", default: true, null: false
    t.integer "balance", default: 0, null: false
    t.integer "cash_transactions_count", default: 0, null: false
    t.integer "cash_transactions_total", default: 0, null: false
    t.bigint "user_id", null: false
    t.bigint "bank_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["bank_id"], name: "index_user_bank_accounts_on_bank_id"
    t.index ["user_id"], name: "index_user_bank_accounts_on_user_id"
  end

  create_table "user_cards", force: :cascade do |t|
    t.string "user_card_name", null: false
    t.integer "days_until_due_date", null: false
    t.integer "due_date_day", default: 1, null: false
    t.integer "min_spend", null: false
    t.integer "credit_limit", null: false
    t.boolean "active", default: true, null: false
    t.integer "card_transactions_count", default: 0, null: false
    t.integer "card_transactions_total", default: 0, null: false
    t.bigint "user_id", null: false
    t.bigint "card_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["card_id"], name: "index_user_cards_on_card_id"
    t.index ["user_id", "card_id", "user_card_name"], name: "index_user_cards_on_on_composite_key", unique: true
    t.index ["user_id"], name: "index_user_cards_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.string "confirmation_token"
    t.string "unconfirmed_email"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.string "locale", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "budget_categories", "budgets"
  add_foreign_key "budget_categories", "categories"
  add_foreign_key "budget_entities", "budgets"
  add_foreign_key "budget_entities", "entities"
  add_foreign_key "budgets", "users"
  add_foreign_key "card_transactions", "cash_transactions", column: "advance_cash_transaction_id"
  add_foreign_key "card_transactions", "user_cards"
  add_foreign_key "card_transactions", "users"
  add_foreign_key "cards", "banks"
  add_foreign_key "cash_transactions", "user_bank_accounts"
  add_foreign_key "cash_transactions", "user_cards"
  add_foreign_key "cash_transactions", "users"
  add_foreign_key "categories", "users"
  add_foreign_key "category_transactions", "categories"
  add_foreign_key "entities", "users"
  add_foreign_key "entity_transactions", "entities"
  add_foreign_key "exchanges", "cash_transactions"
  add_foreign_key "exchanges", "entity_transactions"
  add_foreign_key "installments", "card_transactions"
  add_foreign_key "installments", "cash_transactions"
  add_foreign_key "investments", "cash_transactions"
  add_foreign_key "investments", "user_bank_accounts"
  add_foreign_key "investments", "users"
  add_foreign_key "references", "user_cards"
  add_foreign_key "user_bank_accounts", "banks"
  add_foreign_key "user_bank_accounts", "users"
end
