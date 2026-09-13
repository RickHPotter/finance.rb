# frozen_string_literal: true

class Ledgers::Access::Internal
  def self.call(user:, entity_public_id:, context:)
    return if user.blank? || context.blank? || context.user_id != user.id

    entity = user.entities.find_by(public_id: entity_public_id)
    return if entity.blank?

    Ledgers::Access::Result.new(user:, entity:, context:, share: nil)
  end
end
