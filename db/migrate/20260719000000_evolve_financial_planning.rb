class EvolveFinancialPlanning < ActiveRecord::Migration[7.0]
  def up
    # 1. Rename installments -> installment_plans (evoluir para "plano de compra parcelada")
    rename_table :installments, :installment_plans

    change_table :installment_plans do |t|
      t.references :user,              type: :uuid, foreign_key: true, index: true
      t.references :category,          type: :uuid, foreign_key: true, index: true
      t.string     :description
      t.string     :transaction_type,  default: "expense", null: false
      t.date       :first_competency
      t.string     :status,            default: "active", null: false
      t.datetime   :canceled_at
    end

    add_index :installment_plans, [:user_id, :status]

    # A antiga coluna transaction_id do plan era o "gancho" pra 1 transaction.
    # A nova relação é 1 plan -> N transactions (via transactions.installment_plan_id).
    # Removemos o vínculo antigo pra evitar confusão semântica.
    if column_exists?(:installment_plans, :transaction_id)
      remove_reference :installment_plans, :transaction, foreign_key: true, index: true
    end

    # 2. Recurrence rules
    create_table :recurrence_rules, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :user,             type: :uuid, null: false, foreign_key: true, index: true
      t.references :category,         type: :uuid, foreign_key: true, index: true
      t.string     :transaction_type, null: false
      t.decimal    :amount,           precision: 10, scale: 2, null: false
      t.string     :description
      t.string     :frequency,        default: "monthly", null: false
      t.integer    :day_of_month
      t.date       :starts_on,        null: false
      t.date       :ends_on
      t.boolean    :active,           default: true, null: false
      t.datetime   :canceled_at
      t.timestamps
    end

    add_index :recurrence_rules, [:user_id, :active]

    # 3. Evoluir transactions
    change_table :transactions do |t|
      t.date       :competency_month
      t.string     :status,             default: "pending", null: false
      t.datetime   :paid_at
      t.integer    :installment_number
      t.references :recurrence_rule,    type: :uuid, foreign_key: true, index: true
      t.references :installment_plan,   type: :uuid, foreign_key: { to_table: :installment_plans }, index: true
    end

    add_index :transactions, [:user_id, :competency_month]
    add_index :transactions, [:user_id, :status]

    # 4. Backfill: transações históricas passam a ter competência = mês do occurred_at
    #    e status = "paid" (elas já aconteceram por definição semântica anterior).
    execute <<~SQL.squish
      UPDATE transactions
      SET competency_month = date_trunc('month', COALESCE(occurred_at, created_at))::date,
          status = 'paid',
          paid_at = COALESCE(occurred_at, created_at)
      WHERE competency_month IS NULL
    SQL

    change_column_null :transactions, :competency_month, false
  end

  def down
    remove_index :transactions, [:user_id, :status]
    remove_index :transactions, [:user_id, :competency_month]

    remove_reference :transactions, :installment_plan, foreign_key: { to_table: :installment_plans }, index: true
    remove_reference :transactions, :recurrence_rule, foreign_key: true, index: true
    remove_column :transactions, :installment_number
    remove_column :transactions, :paid_at
    remove_column :transactions, :status
    remove_column :transactions, :competency_month

    drop_table :recurrence_rules

    remove_index :installment_plans, [:user_id, :status]
    remove_column :installment_plans, :canceled_at
    remove_column :installment_plans, :status
    remove_column :installment_plans, :first_competency
    remove_column :installment_plans, :transaction_type
    remove_column :installment_plans, :description
    remove_reference :installment_plans, :category, foreign_key: true, index: true
    remove_reference :installment_plans, :user, foreign_key: true, index: true

    add_reference :installment_plans, :transaction, type: :uuid, foreign_key: true, index: true
    rename_table :installment_plans, :installments
  end
end
