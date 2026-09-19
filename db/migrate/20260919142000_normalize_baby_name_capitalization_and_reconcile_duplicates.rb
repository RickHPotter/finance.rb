# frozen_string_literal: true

class NormalizeBabyNameCapitalizationAndReconcileDuplicates < ActiveRecord::Migration[8.1]
  class MigrationBabyName < ActiveRecord::Base
    self.table_name = "baby_names"
    has_many :decisions, class_name: "MigrationDecision", foreign_key: :baby_name_id, dependent: :destroy
  end

  class MigrationDecision < ActiveRecord::Base
    self.table_name = "baby_name_decisions"
    belongs_to :baby_name, class_name: "MigrationBabyName", foreign_key: :baby_name_id
  end

  def up
    normalize_and_reconcile_all_names
    replace_name_unique_index
  end

  def down
    remove_index :baby_names, name: "index_baby_names_on_lower_name" if index_exists?(:baby_names, name: "index_baby_names_on_lower_name")
    add_index :baby_names, :name, unique: true, name: "index_baby_names_on_name"
  end

  private

  def normalize_and_reconcile_all_names
    name_groups = MigrationBabyName.all.group_by { |bn| bn.name.to_s.strip.downcase }

    name_groups.each_value do |records|
      canonical_title = records.first.name.to_s.strip.split(/\s+/).map(&:capitalize).join(" ")

      if records.size == 1
        records.first.update_columns(name: canonical_title) if records.first.name != canonical_title
      else
        reconcile_duplicate_group(records, canonical_title)
      end
    end
  end

  def reconcile_duplicate_group(records, canonical_title)
    all_decisions = MigrationDecision.where(baby_name_id: records.map(&:id)).order(:created_at, :id).to_a
    surviving_record = pick_surviving_record(records, all_decisions)
    excess_records = records.reject { |r| r.id == surviving_record.id }

    all_decisions.group_by(&:user_id).each_value do |user_decisions|
      reconcile_user_decisions(user_decisions, surviving_record)
    end

    MigrationBabyName.where(id: excess_records.map(&:id)).delete_all
    surviving_record.update_columns(name: canonical_title)
  end

  def pick_surviving_record(records, all_decisions)
    earliest_accepted = all_decisions.find { |d| d.choice == "accepted" }
    return records.find { |r| r.id == earliest_accepted.baby_name_id } if earliest_accepted

    records.min_by(&:id)
  end

  def reconcile_user_decisions(user_decisions, surviving_record)
    surviving_decision = user_decisions.find { |d| d.baby_name_id == surviving_record.id }
    accepted_decision = user_decisions.find { |d| d.choice == "accepted" }

    if accepted_decision
      handle_accepted_user_decision(user_decisions, surviving_decision, accepted_decision, surviving_record)
    else
      handle_unaccepted_user_decision(user_decisions, surviving_decision, surviving_record)
    end
  end

  def handle_accepted_user_decision(user_decisions, surviving_decision, accepted_decision, surviving_record)
    if surviving_decision
      surviving_decision.update_columns(choice: "accepted") if surviving_decision.choice != "accepted"
      delete_other_decisions(user_decisions, surviving_decision.id)
    else
      delete_other_decisions(user_decisions, accepted_decision.id)
      accepted_decision.update_columns(baby_name_id: surviving_record.id)
    end
  end

  def handle_unaccepted_user_decision(user_decisions, surviving_decision, surviving_record)
    if surviving_decision
      delete_other_decisions(user_decisions, surviving_decision.id)
    else
      kept = user_decisions.first
      delete_other_decisions(user_decisions, kept.id)
      kept.update_columns(baby_name_id: surviving_record.id)
    end
  end

  def delete_other_decisions(user_decisions, kept_id)
    other_ids = user_decisions.map(&:id) - [ kept_id ]
    MigrationDecision.where(id: other_ids).delete_all if other_ids.any?
  end

  def replace_name_unique_index
    remove_index :baby_names, :name if index_exists?(:baby_names, :name)
    add_index :baby_names, "LOWER(name)", unique: true, name: "index_baby_names_on_lower_name"
  end
end
