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

ActiveRecord::Schema[7.0].define(version: 2023_11_32_131733) do
  create_table "card_transactions", force: :cascade do |t|
    t.date "date", null: false
    t.string "description", null: false
    t.text "comment"
    t.integer "category_id", null: false
    t.integer "category2_id"
    t.integer "entity_id", null: false
    t.decimal "starting_price", null: false
    t.decimal "price", null: false
    t.integer "month", null: false
    t.integer "year", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "installment_id", null: false
    t.integer "installments_count", default: 0, null: false
    t.integer "card_id"
    t.integer "user_id"
    t.index ["category2_id"], name: "index_card_transactions_on_category2_id"
    t.index ["category_id"], name: "index_card_transactions_on_category_id"
    t.index ["entity_id"], name: "index_card_transactions_on_entity_id"
    t.index ["installment_id"], name: "index_card_transactions_on_installment_id"
  end

  create_table "cards", force: :cascade do |t|
    t.string "card_name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "categories", force: :cascade do |t|
    t.string "description", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
  end

  create_table "entities", force: :cascade do |t|
    t.string "entity_name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
  end

  create_table "installments", force: :cascade do |t|
    t.string "installable_type", null: false
    t.integer "installable_id", null: false
    t.decimal "price"
    t.integer "number"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["installable_type", "installable_id"], name: "index_installments_on_installable"
  end

  create_table "user_cards", force: :cascade do |t|
    t.integer "user_id"
    t.integer "card_id"
    t.string "card_name", null: false
    t.date "due_date", null: false
    t.decimal "min_spend", null: false
    t.decimal "credit_limit", null: false
    t.boolean "active", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["card_id"], name: "index_user_cards_on_card_id"
    t.index ["user_id"], name: "index_user_cards_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.string "confirmation_token"
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "card_transactions", "categories"
  add_foreign_key "card_transactions", "categories", column: "category2_id"
  add_foreign_key "card_transactions", "entities"
  add_foreign_key "card_transactions", "installments"
  add_foreign_key "card_transactions", "user_cards", column: "card_id"
  add_foreign_key "card_transactions", "users"
  add_foreign_key "categories", "users"
  add_foreign_key "entities", "users"
end
