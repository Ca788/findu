class RestructureBudgetsWithPeriods < ActiveRecord::Migration[7.0]
  def up
    remove_index :budgets, name: "index_budgets_on_user_id_and_month_and_year"
    remove_column :budgets, :month
    remove_column :budgets, :year

    add_column :budgets, :period_type, :string, null: false, default: "monthly"
    add_column :budgets, :period_start, :date, null: false, default: -> { "CURRENT_DATE" }
    add_column :budgets, :period_end,   :date, null: false, default: -> { "CURRENT_DATE" }

    change_column_default :budgets, :period_type,  from: "monthly", to: nil
    change_column_default :budgets, :period_start, from: nil, to: nil
    change_column_default :budgets, :period_end,   from: nil, to: nil

    add_index :budgets, [:user_id, :period_start, :period_end], unique: true,
              name: "index_budgets_on_user_id_and_period"
    add_index :budgets, :period_type
  end

  def down
    remove_index :budgets, name: "index_budgets_on_user_id_and_period"
    remove_index :budgets, :period_type
    remove_column :budgets, :period_type
    remove_column :budgets, :period_start
    remove_column :budgets, :period_end

    add_column :budgets, :month, :integer, null: false, default: 1
    add_column :budgets, :year,  :integer, null: false, default: 2026
    change_column_default :budgets, :month, from: 1,    to: nil
    change_column_default :budgets, :year,  from: 2026, to: nil
    add_index :budgets, [:user_id, :month, :year], unique: true,
              name: "index_budgets_on_user_id_and_month_and_year"
  end
end
