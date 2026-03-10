# frozen_string_literal: true

class CreateInvestmentTypes < ActiveRecord::Migration[7.1]
  def change
    create_table :investment_types do |t|
      t.string :investment_type_name_fallback, null: false
      t.string :investment_type_code
      t.boolean :built_in, null: false, default: false

      t.timestamps
    end

    add_index :investment_types, :investment_type_code, unique: true
    add_index :investment_types, :built_in

    add_reference :investments, :investment_type, foreign_key: true
    add_reference :cash_transactions, :investment_type, foreign_key: true

    investment_types = [
      # ============================================================================
      # RENDA FIXA - LIQUIDEZ DIÁRIA (Fixed Income - Daily Liquidity)
      # ============================================================================
      { code: "renda_fixa_liquidez_diaria", name: "Renda Fixa - Liquidez Diária", built_in: true },
      { code: "renda_fixa_cdb_liquidez_diaria", name: "Renda Fixa - CDB Liquidez Diária", built_in: true },
      { code: "renda_fixa_rdb", name: "Renda Fixa - RDB", built_in: true },
      { code: "renda_fixa_rdb_liquidez_diaria", name: "Renda Fixa - RDB Liquidez Diária", built_in: true },
      { code: "renda_fixa_fundos_di", name: "Renda Fixa - Fundos DI", built_in: true },
      { code: "renda_fixa_tesouro_selic_liquidez_diaria", name: "Renda Fixa - Tesouro Selic (Liquidez Diária)", built_in: true },
      # ============================================================================
      # RENDA FIXA (Fixed Income)
      # ============================================================================
      { code: "renda_fixa", name: "Renda Fixa", built_in: true },
      { code: "renda_fixa_tesouro_direto", name: "Renda Fixa - Tesouro Direto", built_in: true },
      { code: "renda_fixa_tesouro_selic", name: "Renda Fixa - Tesouro Selic", built_in: true },
      { code: "renda_fixa_tesouro_prefixado", name: "Renda Fixa - Tesouro Prefixado", built_in: true },
      { code: "renda_fixa_tesouro_ipca", name: "Renda Fixa - Tesouro IPCA+", built_in: true },
      { code: "renda_fixa_cdb", name: "Renda Fixa - CDB", built_in: true },
      { code: "renda_fixa_lci", name: "Renda Fixa - LCI", built_in: true },
      { code: "renda_fixa_lca", name: "Renda Fixa - LCA", built_in: true },
      { code: "renda_fixa_lc", name: "Renda Fixa - LC", built_in: true },
      { code: "renda_fixa_debentures", name: "Renda Fixa - Debêntures", built_in: true },
      { code: "renda_fixa_cri", name: "Renda Fixa - CRI", built_in: true },
      { code: "renda_fixa_cra", name: "Renda Fixa - CRA", built_in: true },

      # ============================================================================
      # RENDA VARIÁVEL (Variable Income)
      # ============================================================================
      { code: "renda_variavel", name: "Renda Variável", built_in: true },
      { code: "renda_variavel_acoes", name: "Renda Variável - Ações", built_in: true },
      { code: "renda_variavel_fiis", name: "Renda Variável - FIIs", built_in: true },
      { code: "renda_variavel_etfs", name: "Renda Variável - ETFs", built_in: true },
      { code: "renda_variavel_bdrs", name: "Renda Variável - BDRs", built_in: true },
      { code: "renda_variavel_stocks", name: "Renda Variável - Stocks (Exterior)", built_in: true },
      { code: "renda_variavel_reits", name: "Renda Variável - REITs", built_in: true },

      # ============================================================================
      # FUNDOS DE INVESTIMENTO (Investment Funds)
      # ============================================================================
      { code: "fundos", name: "Fundos de Investimento", built_in: true },
      { code: "fundos_renda_fixa", name: "Fundos - Renda Fixa", built_in: true },
      { code: "fundos_multimercado", name: "Fundos - Multimercado", built_in: true },
      { code: "fundos_acoes", name: "Fundos - Ações", built_in: true },
      { code: "fundos_cambiais", name: "Fundos - Cambiais", built_in: true },
      { code: "fundos_imobiliarios", name: "Fundos - Imobiliários", built_in: true },

      # ============================================================================
      # PREVIDÊNCIA (Pension/Retirement)
      # ============================================================================
      { code: "previdencia", name: "Previdência", built_in: true },
      { code: "previdencia_pgbl", name: "Previdência - PGBL", built_in: true },
      { code: "previdencia_vgbl", name: "Previdência - VGBL", built_in: true },

      # ============================================================================
      # CRIPTOMOEDAS (Cryptocurrencies)
      # ============================================================================
      { code: "cripto", name: "Criptomoedas", built_in: true },
      { code: "cripto_bitcoin", name: "Criptomoedas - Bitcoin", built_in: true },
      { code: "cripto_ethereum", name: "Criptomoedas - Ethereum", built_in: true },
      { code: "cripto_stablecoins", name: "Criptomoedas - Stablecoins", built_in: true },
      { code: "cripto_altcoins", name: "Criptomoedas - Altcoins", built_in: true },

      # ============================================================================
      # DERIVATIVOS (Derivatives)
      # ============================================================================
      { code: "derivativos", name: "Derivativos", built_in: true },
      { code: "derivativos_opcoes", name: "Derivativos - Opções", built_in: true },
      { code: "derivativos_futuros", name: "Derivativos - Futuros", built_in: true },
      { code: "derivativos_termo", name: "Derivativos - Termo", built_in: true },
      { code: "derivativos_swap", name: "Derivativos - Swap", built_in: true },

      # ============================================================================
      # CÂMBIO (Foreign Exchange)
      # ============================================================================
      { code: "cambio", name: "Câmbio", built_in: true },
      { code: "cambio_dolar", name: "Câmbio - Dólar", built_in: true },
      { code: "cambio_euro", name: "Câmbio - Euro", built_in: true },
      { code: "cambio_outras_moedas", name: "Câmbio - Outras Moedas", built_in: true },

      # ============================================================================
      # COMMODITIES
      # ============================================================================
      { code: "commodities", name: "Commodities", built_in: true },
      { code: "commodities_ouro", name: "Commodities - Ouro", built_in: true },
      { code: "commodities_prata", name: "Commodities - Prata", built_in: true },
      { code: "commodities_petroleo", name: "Commodities - Petróleo", built_in: true },
      { code: "commodities_agricolas", name: "Commodities - Agrícolas", built_in: true },

      # ============================================================================
      # OUTROS (Others)
      # ============================================================================
      { code: "outros", name: "Outros", built_in: true },
      { code: "outros_poupanca", name: "Outros - Poupança", built_in: true },
      { code: "outros_consorcio", name: "Outros - Consórcio", built_in: true },
      { code: "outros_emprestimo_p2p", name: "Outros - Empréstimo P2P", built_in: true },
      { code: "outros_crowdfunding", name: "Outros - Crowdfunding", built_in: true },
      { code: "outros_cofrinho", name: "Outros - Cofrinho", built_in: true }
    ]

    investment_types.each do |type_data|
      InvestmentType.find_or_create_by!(investment_type_code: type_data[:code]) do |type|
        type.investment_type_name_fallback = type_data[:name]
        type.built_in = type_data[:built_in]
      end
    end
  end
end
