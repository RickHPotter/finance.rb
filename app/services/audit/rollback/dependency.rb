# frozen_string_literal: true

Audit::Rollback::Dependency = Data.define(:record_type, :item_id, :relationship, :included) do
  def initialize(record_type:, item_id:, relationship:, included:)
    super(record_type:, item_id:, relationship: relationship.to_s, included: included == true)
  end

  def key
    "#{record_type}:#{item_id}"
  end
end
