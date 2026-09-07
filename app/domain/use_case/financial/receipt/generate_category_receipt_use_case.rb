# frozen_string_literal: true

class UseCase::Financial::Receipt::GenerateCategoryReceiptUseCase
  class EmptyPeriodError < StandardError; end

  # @param [UseCase::Financial::Category::ListCategoryTotalsUseCase]
  # @param [Documents::CategoryReceiptPdf]
  def initialize(totals_use_case: UseCase::Financial::Category::ListCategoryTotalsUseCase.new,
                 renderer: Documents::CategoryReceiptPdf.new)
    @totals_use_case = totals_use_case
    @renderer        = renderer
  end

  # @param [User]
  # @param [String]
  # @param [Date, String, nil]
  # @param [Date, String, nil]
  # @param [String, nil]
  # @param [String, nil]
  # @raise [ArgumentError]
  # @raise [EmptyPeriodError]
  # @return [Financial::Receipt]
  def call(user:, category_id:, from: nil, to: nil, transaction_type: nil, status: "paid")
    category = user.categories.find(category_id)
    phone = Support::Phone.e164(category.whatsapp)
    raise ArgumentError, "category whatsapp is required" if phone.blank?

    period_start = Support::DateParser.parse_month(from) || Date.current.beginning_of_month
    period_end   = Support::DateParser.parse_month(to)   || period_start
    period_start, period_end = period_end, period_start if period_end < period_start

    filters = {
      user:             user,
      category_id:      category.id,
      from:             period_start,
      to:               period_end,
      transaction_type: transaction_type,
      status:           status
    }

    totals = @totals_use_case.call(**filters)
    raise EmptyPeriodError, "No paid transactions found for this category in the period" if totals.empty?

    receipt = user.receipts.create!(
      category:     category,
      payer_name:   category.name,
      payer_phone:  phone,
      period_start: period_start,
      period_end:   period_end,
      total_amount: totals.sum(&:paid_amount),
      metadata:     metadata_for(filters, totals, category)
    )

    attach_pdf(receipt, totals, user)
    receipt
  end

  private

  def attach_pdf(receipt, totals, issuer)
    pdf = @renderer.call(receipt: receipt, totals: totals, issuer: issuer)

    receipt.file.attach(
      io:           StringIO.new(pdf),
      filename:     receipt.filename,
      content_type: ::Financial::Receipt::CONTENT_TYPE
    )
  end

  # @return [Hash]
  def metadata_for(filters, totals, category)
    {
      "category_id"      => category.id,
      "transaction_type" => filters[:transaction_type],
      "status"           => filters[:status],
      "categories_count" => totals.size,
      "entries_count"    => totals.sum(&:transactions_count)
    }.compact
  end
end
