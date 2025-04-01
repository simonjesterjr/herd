# frozen_string_literal: true

module Herd
    class Proxy
        attr_accessor :parent_id, :workflow_id

        def initialize(parent_id: nil, workflow_id: nil)
            @parent_id = parent_id
            @workflow_id = workflow_id
            @model = nil
        end

        def self.find_or_create_by(parent_id: nil, workflow_id: nil)
            proxy = new(parent_id: parent_id, workflow_id: workflow_id)
            proxy.find_or_create_model
            proxy
        end

        def partitioned!
            model.partitioned!
            add_note("Job partitioned", level: 'info')
        end

        def partitioned?
            model.partitioned?
        end

        def errored!
            model.errored!
            add_note("Job encountered an error", level: 'error')
        end

        def errored?
            model.errored?
        end

        def in_process!
            model.in_process!
            add_note("Job started processing", level: 'info')
        end

        def in_process?
            model.in_process?
        end

        def done!
            model.done!
            add_note("Job completed", level: 'info')
        end

        def done?
            model.done?
        end

        def completed!
            model.completed!
            add_note("Job fully completed", level: 'info')
        end

        def completed?
            model.completed?
        end

        def running?
            model.in_process?
        end

        def failed?
            model.errored?
        end

        def add_note(note, level: 'info', metadata: {})
            model.add_note(note, level: level, metadata: metadata)
        end

        def notes
            model.notes
        end

        def info_notes
            model.info_notes
        end

        def warning_notes
            model.warning_notes
        end

        def error_notes
            model.error_notes
        end

        private

        def model
            @model ||= find_or_create_model
        end

        def find_or_create_model
            @model = Models::Proxy.find_or_create_by!(
                workflow_id: workflow_id,
                parent_id: parent_id
            )
        end
    end
end
