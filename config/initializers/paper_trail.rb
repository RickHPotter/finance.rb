# frozen_string_literal: true

PaperTrail.config.has_paper_trail_defaults = {
  on: %i[create update destroy],
  versions: { class_name: "AuditVersion", autosave: false }
}
PaperTrail.config.version_error_behavior = :exception
PaperTrail.config.version_limit = nil
