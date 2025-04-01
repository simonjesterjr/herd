# frozen_string_literal: true

module Herd
  module Test
    class ProxyTest < TestCase
      def setup
        super
        @proxy = TestProxy.new
        @proxy.instance_variable_set(:@model, mock_proxy_model)
      end

      def test_proxy_initializes_with_default_values
        assert_nil @proxy.parent_id
        assert_empty @proxy.jobs
        assert_empty @proxy.proxies
        refute @proxy.persisted
      end

      def test_proxy_creates_with_parent_id
        proxy = TestProxy.create(parent_id: "parent-1")
        assert_equal "parent-1", proxy.parent_id
      end

      def test_proxy_finds_by_id
        proxy = TestProxy.create
        found = TestProxy.find(proxy.id)
        assert_equal proxy.id, found.id
      end

      def test_proxy_raises_not_found_for_invalid_id
        assert_raises(Herd::ProxyNotFound) do
          TestProxy.find("invalid-id")
        end
      end

      def test_proxy_saves_and_persists
        @proxy.save
        assert @proxy.persisted
        @mock_proxy_model.verify
      end

      def test_proxy_state_changes
        @proxy.partitioned!
        assert @proxy.partitioned?
        @mock_proxy_model.verify

        @proxy.in_process!
        assert @proxy.in_process?
        @mock_proxy_model.verify

        @proxy.done!
        assert @proxy.done?
        @mock_proxy_model.verify

        @proxy.completed!
        assert @proxy.completed?
        @mock_proxy_model.verify

        @proxy.errored!
        assert @proxy.errored?
        @mock_proxy_model.verify
      end

      def test_proxy_adds_note
        @proxy.add_note("Test note")
        @mock_proxy_model.verify
      end

      def test_proxy_adds_note_with_metadata
        @proxy.add_note("Test note", metadata: { key: "value" })
        @mock_proxy_model.verify
      end

      def test_proxy_notes_are_ordered
        @proxy.add_note("First note")
        @proxy.add_note("Second note")
        @proxy.add_note("Third note")
        @mock_proxy_model.verify
      end

      def test_proxy_notes_by_level
        @proxy.add_note("Info note", level: "info")
        @proxy.add_note("Warning note", level: "warning")
        @proxy.add_note("Error note", level: "error")
        @mock_proxy_model.verify
      end

      def test_proxy_to_json_returns_correct_hash
        result = JSON.parse(@proxy.to_json)
        expected = {
          "id" => String,
          "parent_id" => nil,
          "status" => "partitioned",
          "total" => 0,
          "finished" => 0,
          "started_at" => nil,
          "finished_at" => nil,
          "jobs" => [],
          "proxies" => []
        }

        expected.each do |key, value|
          if value == String
            assert_instance_of String, result[key]
          else
            assert_equal value, result[key]
          end
        end
      end

      def test_proxy_reloads_state
        @proxy.partitioned!
        @proxy.save

        reloaded = @proxy.reload
        assert reloaded.partitioned?
      end
    end
  end
end 