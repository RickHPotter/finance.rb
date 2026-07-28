# frozen_string_literal: true

class Audit::Current < ActiveSupport::CurrentAttributes
  attribute :operation_id,
            :actor_id,
            :context_id,
            :request_id,
            :root_source,
            :mutation_source,
            :parent_operation_id,
            :rollback_of_operation_id,
            :selected_version_id,
            :metadata

  def self.active?
    operation_id.present?
  end
end
