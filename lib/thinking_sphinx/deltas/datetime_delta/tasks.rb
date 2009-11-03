namespace :thinking_sphinx do
  namespace :index do
    desc "Index Thinking Sphinx datetime delta indexes"
    task :delta => :app_env do
      ThinkingSphinx.indexed_models.select { |model|
        model.constantize.sphinx_indexes.any? { |index| index.delta? }
      }.each do |model|
        model.constantize.sphinx_indexes.select { |index|
          index.delta? && index.delta_object.respond_to?(:delayed_index)
        }.each { |index|
          index.delta_object.delayed_index(index.model)
        }
      end
    end
  end
end

namespace :ts do
  namespace :in do
    desc "Index Thinking Sphinx datetime delta indexes"
    task :delta => "thinking_sphinx:index:delta"
  end
end
