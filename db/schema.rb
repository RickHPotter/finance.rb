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

ActiveRecord::Schema[7.0].define(version: 2023_11_11_011820) do
  create_table "card_transactions", force: :cascade do |t|
    t.date "date", null: false
    t.integer "card_id", null: false
    t.string "description", null: false
    t.text "comment"
    t.integer "category_id", null: false
    t.integer "category2_id"
    t.integer "entity_id", null: false
    t.decimal "starting_price", null: false
    t.decimal "price", null: false
    t.integer "month", null: false
    t.integer "year", null: false
    t.integer "installments", null: false
    t.integer "installments_number", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["card_id"], name: "index_card_transactions_on_card_id"
    t.index ["category2_id"], name: "index_card_transactions_on_category2_id"
    t.index ["category_id"], name: "index_card_transactions_on_category_id"
    t.index ["entity_id"], name: "index_card_transactions_on_entity_id"
  end

  create_table "cards", force: :cascade do |t|
    t.string "card_name", null: false
    t.date "due_date", null: false
    t.decimal "min_spend", null: false
    t.decimal "credit_limit", null: false
    t.boolean "active", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "categories", force: :cascade do |t|
    t.string "description", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "entities", force: :cascade do |t|
    t.string "entity_name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "card_transactions", "cards"
  add_foreign_key "card_transactions", "categories"
  add_foreign_key "card_transactions", "category2s"
  add_foreign_key "card_transactions", "entities"
end
