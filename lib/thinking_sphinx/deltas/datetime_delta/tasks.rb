namespace :thinking_sphinx do
  namespace :index do
    desc "Index Thinking Sphinx datetime delta indices"
#    task :delta => :app_env do
    task :delta => (
      (ThinkingSphinx.constants.include?(:Version) and ThinkingSphinx::Version.to_f < 3) \
        ? :app_env
        : :environment) do
      ThinkingSphinx::Deltas::DatetimeDelta.index
    end
  end
end

namespace :ts do
  namespace :in do
    desc "Index Thinking Sphinx datetime delta indices"
    task :delta => "thinking_sphinx:index:delta"
  end
  namespace :index do
    desc "Index Thinking Sphinx datetime delta indices"
    task :delta => "thinking_sphinx:index:delta"
  end
end
