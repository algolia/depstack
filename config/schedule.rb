set :output, "log/cron.log"

job_type :runner, "source ${HOME}/.rvm/scripts/rvm && cd :path && bundle exec rails runner -e :environment ':task' :output"

every 1.minute, roles: [:cron] do
  runner "Library.where(id: Vote.where('created_at >= ?', 2.minute.ago).select('DISTINCT(library_id)').map(&:library_id)).reindex!"
end
