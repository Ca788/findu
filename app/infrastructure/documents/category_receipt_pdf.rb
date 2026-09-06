# frozen_string_literal: true

require "prawn"
require "prawn/table"

module Documents
  class CategoryReceiptPdf
    HEADERS        = ["Categoria", "Lanc.", "Pago", "Pendente", "Total"].freeze
    COLUMN_RATIOS  = [0.34, 0.11, 0.18, 0.18, 0.19].freeze
    TOTAL_LABEL    = "TOTAL"

    TITLE_SIZE  = 18
    HEADER_SIZE = 10
    TABLE_SIZE  = 9
    FOOTER_SIZE = 8

    # @param [Financial::Receipt]
    # @param [Array<UseCase::Financial::Category::ListCategoryTotalsUseCase::Total>]
    # @param [User]
    # @return [String]
    def call(receipt:, totals:, issuer:)
      Prawn::Document.new(page_size: "A4", margin: 40) do |pdf|
        render_title(pdf)
        render_header(pdf, receipt, issuer)
        pdf.move_down 16
        render_table(pdf, totals, receipt)
        render_footer(pdf)
      end.render
    end

    private

    def render_title(pdf)
      pdf.text "Comprovante por Categoria", size: TITLE_SIZE, style: :bold
      pdf.move_down 12
    end

    def render_header(pdf, receipt, issuer)
      header_lines(receipt, issuer).each { |line| pdf.text line, size: HEADER_SIZE }
    end

    # @return [Array<String>]
    def header_lines(receipt, issuer)
      [
        "Emitido por: #{issuer.name}",
        "Categoria: #{receipt.payer_name.presence || 'Nao informada'}",
        "WhatsApp: #{receipt.payer_phone}",
        "Periodo: #{format_month(receipt.period_start)} a #{format_month(receipt.period_end)}",
        "Emissao: #{Time.current.strftime('%d/%m/%Y %H:%M')}"
      ]
    end

    def render_table(pdf, totals, receipt)
      pdf.table(table_rows(totals, receipt),
                header:        true,
                width:         pdf.bounds.width,
                column_widths: column_widths(pdf.bounds.width),
                cell_style:    { size: TABLE_SIZE, padding: 6 }) do |table|
        table.row(0).font_style  = :bold
        table.row(-1).font_style = :bold
        table.columns(1..-1).align = :right
      end
    end

    # @param [Numeric]
    # @return [Array<Float>]
    def column_widths(available)
      COLUMN_RATIOS.map { |ratio| available * ratio }
    end

    # @return [Array<Array<String>>]
    def table_rows(totals, receipt)
      rows = totals.map do |total|
        [
          total.category_name,
          total.transactions_count.to_s,
          Formatters::Brl.call(total.paid_amount),
          Formatters::Brl.call(total.pending_amount),
          Formatters::Brl.call(total.total)
        ]
      end

      [HEADERS] + rows + [total_row(totals, receipt)]
    end

    # @return [Array<String>]
    def total_row(totals, receipt)
      [
        TOTAL_LABEL,
        totals.sum { |total| total.transactions_count }.to_s,
        Formatters::Brl.call(totals.sum { |total| total.paid_amount }),
        Formatters::Brl.call(totals.sum { |total| total.pending_amount }),
        Formatters::Brl.call(receipt.total_amount)
      ]
    end

    def render_footer(pdf)
      pdf.move_down 24
      pdf.text "Documento gerado automaticamente pelo Findu.", size: FOOTER_SIZE, style: :italic
    end

    # @param [Date]
    # @return [String]
    def format_month(date)
      date.strftime("%m/%Y")
    end
  end
end
