# frozen_string_literal: true

RSpec.configure do |config|
  config.before do
    Audit::Current.reset
    PaperTrail.request.whodunnit = nil
    PaperTrail.request.controller_info = {}
    PaperTrail.request.enabled = true
  end

  config.after do
    Audit::Current.reset
    PaperTrail.request.whodunnit = nil
    PaperTrail.request.controller_info = {}
    PaperTrail.request.enabled = true
  end
end
