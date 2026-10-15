# frozen_string_literal: true

module FiscalReceipts
  class GoiasHtmlSnapshot
    ALLOWED_TAGS = %w[article b br div em fieldset h1 h2 h3 h4 h5 h6 hr i label legend li ol p section small span strong table tbody td tfoot th thead tr ul].freeze
    ALLOWED_ATTRIBUTES = %w[class colspan id rowspan].freeze
    REMOVED_TAGS = %w[base button form iframe img input link meta noscript object script style svg].freeze

    def initialize(markup, title:, access_key:)
      @markup = markup
      @title = title
      @access_key = access_key
    end

    def call
      document = Nokogiri::HTML(@markup)
      document.css("#botoes_nft, #{REMOVED_TAGS.join(', ')}").remove
      document.xpath("//comment()").remove
      sanitize_elements(document.at_css("body"))

      <<~HTML
        <!doctype html>
        <html lang="pt-BR">
          <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <title>#{ERB::Util.html_escape(@title)}</title>
            <style>#{stylesheet}</style>
          </head>
          <body>
            <main class="receipt">
              <header class="snapshot-header">
                <span class="eyebrow">NFC-e · Goiás</span>
                <h1>#{ERB::Util.html_escape(@title)}</h1>
                <p>Cópia para consulta offline dos dados exibidos pela SEFAZ-GO. Não substitui o XML fiscal autorizado.</p>
                <p class="access-key">Chave de acesso: #{ERB::Util.html_escape(@access_key)}</p>
              </header>
              <div class="receipt-content">#{document.at_css('body')&.inner_html}</div>
            </main>
          </body>
        </html>
      HTML
    end

    private

    def sanitize_elements(root)
      root.css("*").reverse_each do |element|
        unless ALLOWED_TAGS.include?(element.name)
          element.replace(element.children)
          next
        end

        element.attribute_nodes.each { |attribute| element.remove_attribute(attribute.name) unless ALLOWED_ATTRIBUTES.include?(attribute.name) }
      end
    end

    def stylesheet
      <<~CSS
        :root { color-scheme: light; font-family: system-ui, -apple-system, "Segoe UI", sans-serif; color: #17212b; background: #f3f5f6; }
        * { box-sizing: border-box; }
        body { margin: 0; padding: 32px 16px; }
        .receipt { max-width: 920px; margin: auto; background: #fff; border: 1px solid #dce2e6; border-radius: 14px; box-shadow: 0 8px 30px #17212b12; overflow: hidden; }
        .snapshot-header { padding: 28px 32px; background: #eef7f3; border-bottom: 1px solid #dce2e6; }
        .snapshot-header h1 { margin: 6px 0 8px; font-size: 1.6rem; }
        .snapshot-header p { margin: 8px 0 0; color: #425466; line-height: 1.5; }
        .eyebrow { color: #176b4a; font-size: .78rem; font-weight: 700; letter-spacing: .08em; text-transform: uppercase; }
        .access-key, .chave { overflow-wrap: anywhere; font-family: ui-monospace, SFMono-Regular, Consolas, monospace; font-size: .88rem; }
        .receipt-content { padding: 28px 32px 36px; line-height: 1.5; overflow-wrap: anywhere; }
        .receipt-content h1, .receipt-content h2, .receipt-content h3, .receipt-content h4 { color: #263f35; }
        .receipt-content h1 { font-size: 1.2rem; }
        .receipt-content h4, .receipt-content legend { font-size: 1rem; }
        .receipt-content fieldset { min-width: 0; margin: 22px 0; padding: 16px; border: 1px solid #dce2e6; border-radius: 10px; }
        .receipt-content legend { padding: 0 8px; font-weight: 700; color: #176b4a; }
        .receipt-content table { width: 100%; border-collapse: collapse; margin: 10px 0; }
        .receipt-content tr + tr { border-top: 1px solid #e8edef; }
        .receipt-content th, .receipt-content td { padding: 9px 10px; text-align: left; vertical-align: top; }
        .receipt-content td > label { display: block; color: #62717d; font-size: .78rem; font-weight: 600; }
        .receipt-content td > span { display: inline-block; }
        .receipt-content #tabResult td:last-child { text-align: right; white-space: nowrap; }
        .receipt-content #tabResult .txtTit { font-weight: 600; }
        .receipt-content #tabResult .Rqtd, .receipt-content #tabResult .RUN, .receipt-content #tabResult .RvlUnit { display: inline-block; margin-right: 12px; font-size: .85rem; color: #52616b; }
        .receipt-content .txtCenter, .receipt-content .tit { text-align: center; }
        .receipt-content .txtTopo { font-size: 1.15rem; font-weight: 700; }
        .receipt-content #linhaTotal { display: flex; justify-content: space-between; gap: 16px; padding: 8px 10px; border-bottom: 1px solid #e8edef; }
        .receipt-content #linhaTotal .totalNumb { font-weight: 700; }
        .receipt-content .GeralXslt > h1 { display: none; }
        @media (max-width: 640px) { body { padding: 0; } .receipt { border: 0; border-radius: 0; box-shadow: none; } .snapshot-header, .receipt-content { padding: 20px 16px; } .receipt-content fieldset { padding: 10px; } .receipt-content th, .receipt-content td { padding: 7px 5px; font-size: .85rem; } }
        @media print { :root { background: #fff; } body { padding: 0; } .receipt { border: 0; box-shadow: none; } .receipt-content fieldset { break-inside: avoid; } }
      CSS
    end
  end
end
