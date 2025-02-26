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

ActiveRecord::Schema[8.0].define(version: 2024_05_00_000003) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "banks", force: :cascade do |t|
    t.string "bank_name", null: false
    t.string "bank_code", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "card_transactions", force: :cascade do |t|
    t.string "description", null: false
    t.text "comment"
    t.date "date", null: false
    t.integer "month", null: false
    t.integer "year", null: false
    t.integer "starting_price", null: false
    t.integer "price", null: false
    t.boolean "paid", default: false
    t.integer "card_installments_count", default: 0, null: false
    t.bigint "user_id", null: false
    t.bigint "user_card_id", null: false
    t.bigint "advance_cash_transaction_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["advance_cash_transaction_id"], name: "index_card_transactions_on_advance_cash_transaction_id"
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
    t.date "date", null: false
    t.integer "month", null: false
    t.integer "year", null: false
    t.integer "starting_price", null: false
    t.integer "price", null: false
    t.boolean "paid", default: false
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
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["entity_name"], name: "index_entities_on_entity_name", unique: true
    t.index ["user_id", "entity_name"], name: "index_entity_name_on_composite_key", unique: true
    t.index ["user_id"], name: "index_entities_on_user_id"
  end

  create_table "entity_transactions", force: :cascade do |t|
    t.boolean "is_payer", default: false, null: false
    t.integer "status", default: 0, null: false
    t.integer "price", default: 0, null: false
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
    t.integer "exchange_type", default: 0, null: false
    t.integer "number", default: 1, null: false
    t.integer "starting_price", null: false
    t.integer "price", null: false
    t.bigint "entity_transaction_id", null: false
    t.bigint "cash_transaction_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cash_transaction_id"], name: "index_exchanges_on_cash_transaction_id"
    t.index ["entity_transaction_id"], name: "index_exchanges_on_entity_transaction_id"
  end

  create_table "installments", force: :cascade do |t|
    t.integer "number", null: false
    t.date "date", null: false
    t.integer "month", null: false
    t.integer "year", null: false
    t.integer "starting_price", null: false
    t.integer "price", null: false
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
  end

  create_table "investments", force: :cascade do |t|
    t.string "description"
    t.date "date", null: false
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

  create_table "user_bank_accounts", force: :cascade do |t|
    t.integer "agency_number"
    t.integer "account_number"
    t.boolean "active", default: true, null: false
    t.integer "balance", default: 0, null: false
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
    t.date "current_closing_date", null: false
    t.date "current_due_date", null: false
    t.integer "min_spend", null: false
    t.integer "credit_limit", null: false
    t.boolean "active", default: true, null: false
    t.bigint "user_id", null: false
    t.bigint "card_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["card_id"], name: "index_user_cards_on_card_id"
    t.index ["user_card_name"], name: "index_user_cards_on_user_card_name", unique: true
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
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

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
  add_foreign_key "user_bank_accounts", "banks"
  add_foreign_key "user_bank_accounts", "users"
end
