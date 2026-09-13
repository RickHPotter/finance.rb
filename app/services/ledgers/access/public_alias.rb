# frozen_string_literal: true

class Ledgers::Access::PublicAlias
  Grant = Data.define(:public_id)

  ENTITY_NAMES = {
    "lalas" => "LALA"
  }.freeze

  def self.call(alias_name:, entity_public_id: ENV.fetch("LALAS_ENTITY_PUBLIC_ID", nil))
    alias_name = alias_name.to_s
    entity = resolve_entity(alias_name:, entity_public_id:)
    return if entity.blank?

    context = entity.user.main_context
    return if context.blank?

    grant = Grant.new(public_id: "public-alias:#{alias_name}:#{entity.public_id}")
    Ledgers::Access::Result.new(user: entity.user, entity:, context:, share: grant)
  end

  def self.resolve_entity(alias_name:, entity_public_id:)
    scope = Entity.active.includes(:user)
    return scope.find_by(public_id: entity_public_id) if entity_public_id.present?

    entity_name = ENTITY_NAMES[alias_name]
    return if entity_name.blank?

    matches = scope.where("UPPER(entities.entity_name) = ?", entity_name).limit(2).to_a
    matches.one? ? matches.first : nil
  end
  private_class_method :resolve_entity
end
