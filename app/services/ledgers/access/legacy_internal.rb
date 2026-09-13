# frozen_string_literal: true

class Ledgers::Access::LegacyInternal
  def self.call(user:, entity_slug:, context:)
    return if user.blank? || context.blank? || context.user_id != user.id

    normalized_slug = entity_slug.to_s.parameterize
    return if normalized_slug.blank?

    matches = Entity.where(user_id: user.id).select { |entity| entity.entity_name.parameterize == normalized_slug }
    return unless matches.one?

    Ledgers::Access::Result.new(user:, entity: matches.first, context:, share: nil)
  end
end
