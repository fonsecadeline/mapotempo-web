class ChangeTypeColumnToCustomer < ActiveRecord::Migration
  def change
    change_column :customers, :optimization_time, :float
    change_column :customers, :optimization_minimal_time, :float
  end
end
