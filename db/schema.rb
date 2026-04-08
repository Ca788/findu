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

ActiveRecord::Schema[7.0].define(version: 2026_04_08_002454) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pgcrypto"
  enable_extension "plpgsql"

  create_table "artifacts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "organization_id", null: false
    t.uuid "user_id", null: false
    t.string "artifact_type", null: false
    t.string "source"
    t.jsonb "raw_data", default: {}
    t.jsonb "processed_data", default: {}
    t.string "status", default: "pending"
    t.datetime "occurred_at"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id"], name: "index_artifacts_on_organization_id"
    t.index ["status"], name: "index_artifacts_on_status"
    t.index ["user_id"], name: "index_artifacts_on_user_id"
  end

  create_table "budgets", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "organization_id", null: false
    t.uuid "user_id", null: false
    t.integer "month", null: false
    t.integer "year", null: false
    t.decimal "limit_amount", precision: 10, scale: 2
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id"], name: "index_budgets_on_organization_id"
    t.index ["user_id", "month", "year"], name: "index_budgets_on_user_id_and_month_and_year", unique: true
    t.index ["user_id"], name: "index_budgets_on_user_id"
  end

  create_table "categories", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "organization_id", null: false
    t.string "name", null: false
    t.uuid "parent_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id"], name: "index_categories_on_organization_id"
    t.index ["parent_id"], name: "index_categories_on_parent_id"
  end

  create_table "insights", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "organization_id", null: false
    t.uuid "user_id", null: false
    t.string "reference_type", null: false
    t.uuid "reference_id"
    t.text "content"
    t.string "severity"
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id"], name: "index_insights_on_organization_id"
    t.index ["reference_type"], name: "index_insights_on_reference_type"
    t.index ["user_id"], name: "index_insights_on_user_id"
  end

  create_table "installments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "transaction_id", null: false
    t.decimal "total_amount", precision: 10, scale: 2
    t.integer "total_installments"
    t.integer "current_installment"
    t.decimal "monthly_amount", precision: 10, scale: 2
    t.datetime "started_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["transaction_id"], name: "index_installments_on_transaction_id"
  end

  create_table "organizations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.string "plan"
    t.jsonb "settings", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "transactions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "organization_id", null: false
    t.uuid "user_id", null: false
    t.uuid "artifact_id"
    t.uuid "category_id"
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.string "transaction_type", null: false
    t.string "description"
    t.datetime "occurred_at"
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["artifact_id"], name: "index_transactions_on_artifact_id"
    t.index ["category_id"], name: "index_transactions_on_category_id"
    t.index ["organization_id"], name: "index_transactions_on_organization_id"
    t.index ["user_id"], name: "index_transactions_on_user_id"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "organization_id", null: false
    t.string "name", null: false
    t.string "email", null: false
    t.string "phone"
    t.string "role"
    t.jsonb "settings", default: {}
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.index ["organization_id", "email"], name: "index_users_on_organization_id_and_email", unique: true
    t.index ["organization_id"], name: "index_users_on_organization_id"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "artifacts", "organizations"
  add_foreign_key "artifacts", "users"
  add_foreign_key "budgets", "organizations"
  add_foreign_key "budgets", "users"
  add_foreign_key "categories", "categories", column: "parent_id"
  add_foreign_key "categories", "organizations"
  add_foreign_key "insights", "organizations"
  add_foreign_key "insights", "users"
  add_foreign_key "installments", "transactions"
  add_foreign_key "transactions", "artifacts"
  add_foreign_key "transactions", "categories"
  add_foreign_key "transactions", "organizations"
  add_foreign_key "transactions", "users"
  add_foreign_key "users", "organizations"
end
