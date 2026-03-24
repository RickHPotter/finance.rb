# frozen_string_literal: true

class AddScenarioKeyToContextsAndConversations < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  class Context < ApplicationRecord
    self.table_name = "contexts"
  end

  class Conversation < ApplicationRecord
    self.table_name = "conversations"
  end

  def up
    add_column :contexts, :scenario_key, :string
    add_column :conversations, :scenario_key, :string

    add_index :contexts, :scenario_key, algorithm: :concurrently
    add_index :conversations, :scenario_key, algorithm: :concurrently

    backfill_context_scenario_keys!
  end

  def down
    remove_index :conversations, :scenario_key
    remove_index :contexts, :scenario_key

    remove_column :conversations, :scenario_key
    remove_column :contexts, :scenario_key
  end

  private

  def backfill_context_scenario_keys!
    say_with_time "Backfilling derived contexts with scenario keys" do
      Context.where(main: false, scenario_key: nil).find_each do |context|
        context.update_columns(scenario_key: SecureRandom.uuid)
      end
    end

    say_with_time "Backfilling conversations into the main scenario" do
      Conversation.where(scenario_key: nil).update_all(scenario_key: nil)
    end
  end
end
