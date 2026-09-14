# frozen_string_literal: true

module ReferenceMerges::Lock
  module_function

  def acquire!(user_card:, context:)
    connection = ApplicationRecord.connection
    lock_key = connection.quote("reference-merge:#{user_card.id}:#{context.id}")
    connection.execute("SELECT pg_advisory_xact_lock(hashtextextended(#{lock_key}, 0))")
  end
end
