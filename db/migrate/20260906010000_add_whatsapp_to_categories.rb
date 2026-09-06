# frozen_string_literal: true

class AddWhatsappToCategories < ActiveRecord::Migration[7.0]
  def change
    add_column :categories, :whatsapp, :string
  end
end
