# frozen_string_literal: true

require_relative "../test_helper"
require "test_workflow"

class Herd::GraphTest < Herd::TestCase
  def setup
    super
    @workflow = TestWorkflow.new
    @workflow_id = @workflow.id
  end

  def test_viz_runs_graphviz_to_render_graph
    instance = Redis.new
    RedisClient.redis = instance
    graph = Herd::Graph.new(@workflow_id)
    graph.viz
  end

  def test_path_returns_string_path_to_rendered_graph
    assert_equal Pathname.new(Dir.tmpdir).join(@filename).to_s, @graph.path
  end
end 