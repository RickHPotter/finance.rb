# frozen_string_literal: true

ActionView::Base.field_error_proc = proc do |html|
  frag = Nokogiri::HTML5::DocumentFragment.parse(html)
  klass = frag.children[0].attributes['class']
  frag.children[0].attributes['class'].value = [klass, 'is-invalid'].join(' ')
  frag.to_html.html_safe
end
