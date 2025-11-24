# frozen_string_literal: true

class AddContextToMessages < ActiveRecord::Migration[7.0]
  def change
    add_reference :messages, :superseded_by, foreign_key: { to_table: :messages }
    add_reference :messages, :reference_transactable, polymorphic: true, index: true
  end
end
