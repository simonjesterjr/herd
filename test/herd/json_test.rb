# frozen_string_literal: true

require_relative "../test_helper"

class Herd::JSONTest < Herd::TestCase
  def test_encode_encodes_data_to_json
    assert_equal "{\"a\":123}", Herd::JSON.encode({ a: 123 })
  end

  def test_decode_decodes_json_to_data
    assert_equal({ a: 123 }, Herd::JSON.decode("{\"a\":123}"))
  end

  def test_decode_passes_options_to_internal_parser
    assert_equal({ a: 123 }, Herd::JSON.decode("{\"a\":123}", symbol_keys: true))
  end
end 