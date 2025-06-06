# frozen_string_literal: true

require "graphviz"
require 'tmpdir'

module Herd
  class Graph
    attr_reader :workflow, :filename, :path, :start_node, :end_node

    def initialize(workflow_id)
      @workflow_id = workflow_id
      @workflow = Herd::Client.new.find_workflow(workflow_id)
      @filename = "graph.png"
      @path = Pathname.new(Dir.tmpdir).join(filename)
    end

    def viz
      @graph = Graphviz::Graph.new(**graph_options)
      @start_node = add_node('start', shape: 'diamond', fillcolor: '#CFF09E')
      @end_node = add_node('end', shape: 'diamond', fillcolor: '#F56991')

      # First, create nodes for all jobs
      @job_name_to_node_map = {}
      workflow.jobs.each do |job|
        add_job_node(job)
      end

      # Next, link up the jobs with edges
      workflow.jobs.each do |job|
        link_job_edges(job)
      end

      format = 'png'
      file_format = path.split('.')[-1]
      format = file_format if file_format.length == 3

      Graphviz::output(@graph, path: path, format: format)
    end

    def path
      @path.to_s
    end

    private

    def add_node(name, **specific_options)
      @graph.add_node(name, **node_options.merge(specific_options))
    end

    def add_job_node(job)
      @job_name_to_node_map[job.name] = add_node(job.name, label: node_label_for_job(job))
    end

    def link_job_edges(job)
      job_node = @job_name_to_node_map[job.name]

      if job.incoming.empty?
        @start_node.connect(job_node, **edge_options)
      end

      if job.outgoing.empty?
        job_node.connect(@end_node, **edge_options)
      else
        job.outgoing.each do |id|
          outgoing_job = workflow.find_job(id)
          job_node.connect(@job_name_to_node_map[outgoing_job.name], **edge_options)
        end
      end
    end

    def node_label_for_job(job)
      job.class.to_s
    end

    def graph_options
      {
          dpi: 200,
          compound: true,
          rankdir: "LR",
          center: true,
          format: 'png'
      }
    end

    def node_options
      {
        shape: "ellipse",
        style: "filled",
        color: "#555555",
        fillcolor: "white"
      }
    end

    def edge_options
      {
        dir: "forward",
        penwidth: 1,
        color: "#555555"
      }
    end
  end
end
