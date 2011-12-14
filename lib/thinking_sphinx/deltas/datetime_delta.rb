# Datetime Deltas for Thinking Sphinx
#
# This documentation is aimed at those reading the code. If you're looking for
# a guide to Thinking Sphinx and/or deltas, I recommend you start with the
# Thinking Sphinx site instead - or the README for this library at the very
# least.
#
# @author Patrick Allan
# @see http://ts.freelancing-gods.com Thinking Sphinx
#
class ThinkingSphinx::Deltas::DatetimeDelta < ThinkingSphinx::Deltas::DefaultDelta
  attr_accessor :column, :threshold

  def self.index
    ThinkingSphinx.context.indexed_models.collect { |model|
      model.constantize
    }.select { |model|
      model.define_indexes
      model.delta_indexed_by_sphinx?
    }.each do |model|
      model.sphinx_indexes.select { |index|
        index.delta? && index.delta_object.respond_to?(:delayed_index)
      }.each { |index|
        index.delta_object.delayed_index(index.model)
      }
    end
  end

  # Initialises the Delta object for the given index and settings. All handled
  # by Thinking Sphinx, so you shouldn't need to call this method yourself in
  # general day-to-day situations.
  #
  # @example
  #   ThinkingSphinx::Deltas::DatetimeDelta.new index,
  #     :delta_column => :updated_at,
  #     :threshold    => 1.day
  #
  # @param [ThinkingSphinx::Index] index the index using this delta object
  # @param [Hash] options a hash of options for the index
  # @option options [Symbol] :delta_column (:updated_at) The column to use for
  #   tracking when a record has changed. Default to :updated_at.
  # @option options [Integer] :threshold (1.day) The window of time to store
  #   changes for, in seconds. Defaults to one day.
  #
  def initialize(index, options = {})
    @index      = index
    @column     = options.delete(:delta_column) || :updated_at
    @threshold  = options.delete(:threshold)    || 1.day
  end

  # Does absolutely nothing, beyond returning true. Thinking Sphinx expects
  # this method, though, and we don't want to use the inherited behaviour from
  # DefaultDelta.
  #
  # All the real indexing logic is done by the delayed_index method.
  #
  # @param [Class] model the ActiveRecord model to index.
  # @param [ActiveRecord::Base] instance the instance of the given model that
  #   has changed. Optional.
  # @return [Boolean] true
  # @see #delayed_index
  #
  def index(model, instance = nil)
    # do nothing
    true
  end

  # Processes the delta index for the given model, and then merges the relevant
  # core and delta indexes together. By default, the output of these indexer
  # commands are printed to stdout. If you'd rather it didn't, set
  # ThinkingSphinx.suppress_delta_output to true.
  #
  # @param [Class] model the ActiveRecord model to index
  # @return [Boolean] true
  #
  def delayed_index(model)
    config = ThinkingSphinx::Configuration.instance
    rotate = ThinkingSphinx.sphinx_running? ? " --rotate" : ""

    output = `#{config.bin_path}#{config.indexer_binary_name} --config #{config.config_file}#{rotate} #{model.delta_index_names.join(' ')}`


    model.sphinx_indexes.select(&:delta?).each do |index|
      output += `#{config.bin_path}#{config.indexer_binary_name} --config #{config.config_file}#{rotate} --merge #{index.core_name} #{index.delta_name} --merge-dst-range sphinx_deleted 0 0`
    end unless ENV['DISABLE_MERGE'] == 'true'

    puts output unless ThinkingSphinx.suppress_delta_output?

    true
  end

  # Toggles the given instance to be flagged as part of the next delta indexing.
  # For datetime deltas, this means do nothing at all.
  #
  # @param [ActiveRecord::Base] instance the instance to be toggled
  #
  def toggle(instance)
    # do nothing
  end

  # Report whether a given instance is considered toggled (part of the next
  # delta process). For datetime deltas, this is true if the delta column
  # (updated_at by default) has a value within the threshold. Otherwise, false
  # is returned.
  #
  # @param [ActiveRecord::Base] instance the instance to check
  # @return [Boolean] True if within the threshold window, otherwise false.
  #
  def toggled(instance)
    instance.send(@column) > @threshold.ago
  end

  # Returns the SQL query that resets the model data after a normal index. For
  # datetime deltas, nothing needs to be done, so this method returns nil.
  #
  # @param [Class] model The ActiveRecord model that is requesting the query
  # @return [NilClass] Always nil
  #
  def reset_query(model)
    nil
  end

  # A SQL condition (as part of the WHERE clause) that limits the result set to
  # just the delta data, or all data, depending on whether the toggled argument
  # is true or not. For datetime deltas, the former value is a check on the
  # delta column being within the threshold. In the latter's case, no condition
  # is needed, so nil is returned.
  #
  # @param [Class] model The ActiveRecord model to generate the SQL condition
  #   for.
  # @param [Boolean] toggled Whether the query should request delta documents or
  #   all documents.
  # @return [String, NilClass] The SQL condition if the toggled version is
  #   requested, otherwise nil.
  #
  def clause(model, toggled)
    if toggled
      "#{model.quoted_table_name}.#{model.connection.quote_column_name(@column.to_s)}" +
      " > #{adapter.time_difference(@threshold)}"
    else
      nil
    end
  end
end
