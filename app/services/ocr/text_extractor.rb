# frozen_string_literal: true

require "open3"
require "timeout"

module Ocr
  class TextExtractor
    class ExtractionError < StandardError; end
    class EngineNotFound < ExtractionError; end
    class ExtractionTimeout < ExtractionError; end

    MAX_OUTPUT_BYTES = 512.kilobytes
    OCR_TIMEOUT = 30
    PSM_MODE = "4" # Column of text — best for receipt layouts
    LANGUAGE = "por+eng"

    def initialize(image_paths)
      @image_paths = Array(image_paths)
    end

    def call
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      all_lines = []

      @image_paths.each do |path|
        lines = extract_tsv(path)
        all_lines.concat(lines)
      end

      elapsed_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round

      raw_text = all_lines.select { |l| l[:text].present? }.map { |l| l[:text] }.join("\n")
      raise ExtractionError, I18n.t("ocr.errors.empty_output") if raw_text.blank?
      raise ExtractionError, I18n.t("ocr.errors.output_too_large") if raw_text.bytesize > MAX_OUTPUT_BYTES

      {
        lines: all_lines.select { |l| l[:text].present? },
        raw_text: raw_text,
        engine: "tesseract",
        language: LANGUAGE,
        processing_ms: elapsed_ms
      }
    end

    private

    def extract_tsv(image_path)
      output, error, status = Timeout.timeout(OCR_TIMEOUT) do
        Open3.capture3(
          "tesseract", image_path, "stdout",
          "-l", LANGUAGE,
          "--psm", PSM_MODE,
          "tsv"
        )
      end

      raise ExtractionError, I18n.t("ocr.errors.extraction_failed", detail: error.to_s.first(200)) unless status.success?

      parse_tsv(output)
    rescue Errno::ENOENT
      raise EngineNotFound, I18n.t("ocr.errors.engine_not_found")
    rescue Timeout::Error
      raise ExtractionTimeout, I18n.t("ocr.errors.extraction_timeout")
    end

    def parse_tsv(tsv_output)
      lines = []
      current_line = nil

      tsv_output.each_line do |row|
        word = parse_word_row(row)
        next unless word

        if current_line.nil? || current_line[:line_key] != word[:line_key]
          current_line = new_line_entry(word)
          lines << current_line
        else
          append_word_to_line(current_line, word)
        end
      end

      lines.map { |l| l.except(:line_key, :word_confidences) }
    end

    def parse_word_row(row)
      fields = row.chomp.split("\t")
      return if fields[0] == "level" || fields[0].to_i != 5

      text = fields[11].to_s.strip
      confidence = fields[10].to_f
      return if text.blank? || confidence.negative?

      {
        line_key: "#{fields[2]}_#{fields[4]}",
        text: text,
        confidence: confidence,
        bbox: [ fields[6].to_i, fields[7].to_i, fields[8].to_i, fields[9].to_i ]
      }
    end

    def new_line_entry(word)
      {
        line_key: word[:line_key],
        text: word[:text],
        confidence: word[:confidence],
        bbox: word[:bbox].dup,
        word_confidences: [ word[:confidence] ]
      }
    end

    def append_word_to_line(line, word)
      line[:text] = "#{line[:text]} #{word[:text]}"
      line[:word_confidences] << word[:confidence]
      line[:confidence] = line[:word_confidences].sum / line[:word_confidences].size
      expand_bbox(line[:bbox], word[:bbox])
    end

    def expand_bbox(bbox, word_bbox)
      left, top, width, height = word_bbox
      new_right = [ bbox[0] + bbox[2], left + width ].max
      new_bottom = [ bbox[1] + bbox[3], top + height ].max
      bbox[0] = [ bbox[0], left ].min
      bbox[1] = [ bbox[1], top ].min
      bbox[2] = new_right - bbox[0]
      bbox[3] = new_bottom - bbox[1]
    end
  end
end
