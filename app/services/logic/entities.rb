# frozen_string_literal: true

module Logic
  class Entities
    def self.create(entity_params)
      entity = Entity.new(entity_params)
      _handle_creation(entity)
    end

    def self.update(entity, entity_params)
      entity.assign_attributes(entity_params)
      _handle_creation(entity)
    end

    def self._handle_creation(entity)
      entity.save
      entity
    end
  end
end
