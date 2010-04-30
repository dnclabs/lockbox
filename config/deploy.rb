APP_NAME = "lockbox"

set :application, "#{APP_NAME}"
set :scm, :git
set :repository,  "ssh://deploy@gitdev.dnc.org/dnc/git/#{APP_NAME}.git"

set :deploy_to, "/dnc/app/#{APP_NAME}"



set :user, "deploy"
set :runner, "deploy"

set :keep_releases, 4

task :staging do
  set :rails_env, "staging"
  role :app,  "romulus.dnc.org"
  role :web,  "romulus.dnc.org"
  role :db,   "romulus.dnc.org", :primary => true
  role :cron, "romulus.dnc.org"
end

task :production do
  set :rails_env, "production"
  role :app, "viper1.dnc.org", "viper2.dnc.org", "viper3.dnc.org"
  role :web, "viper1.dnc.org", "viper2.dnc.org", "viper3.dnc.org"
  role :db,  "viper1.dnc.org", :primary => true
  role :cron, "viper1.dnc.org"
end

namespace :db do
  task :setup do
    run "cp #{deploy_to}/shared/config/database.yml #{release_path}/config/database.yml"
  end
end
# 
# 
after "deploy:update",   "db:setup"
after "deploy:update_code",   "db:setup"
after "deploy:update_code", "files:copy_cron_jobs"
after "deploy:setup",  "files:prepare"
after "deploy:restart", "cache:clear"

namespace :files do
  task :prepare do
    sudo "chown -R deploy:deploy #{deploy_to}"
    run "mkdir -p #{deploy_to}/shared/config/"

    sudo "cp #{current_path}/config/instance_profiles/app/#{rails_env}/nginx.conf /dnc/sw32/nginx/conf/sites/#{APP_NAME}.conf"      
    run "scp viper1.dnc.org:/dnc/app/#{APP_NAME}/shared/config/database.yml #{deploy_to}/shared/config/database.yml"
  end
  
  task :copy_cron_jobs, :roles => :cron do
    sudo "cp #{latest_release}/config/instance_profiles/app/#{rails_env}/cron_jobs /etc/cron.d/#{APP_NAME}_cron"
  end
end


namespace :deploy do
  [:start, :stop].each do |t|
    desc "#{t} task is a no-op with mod_rails"
    task t, :roles => :app do ; end
  end

  task :restart do
    run "touch #{current_path}/tmp/restart.txt"
  end

end

namespace :nginx do

  desc "reload the nginx.conf file gracefully if changes have been made to it"
  task :reload do
    sudo "pkill -HUP nginx"
  end

  desc "restart nginx"
  task :restart do
    sudo "/etc/init.d/nginx restart"
  end
end

namespace :cache do
  desc "clear memcache if it is set to be the actioncontroller base cache_store"
  task :clear do
    run "#{current_path}/script/runner -e #{rails_env} 'ActionController::Base.cache_store.clear'"
  end

end

#copies a file from src_path (on local computer) to dest_path (on remote computer)
#assumes file can only be copied into /tmp and then moved via sudo cp
def copy_file(src_path, dest_path)
  begin
    fname = File.basename(src_path)
    put(File.read(src_path), "/tmp/#{fname}")
    sudo "cp /tmp/#{fname} #{dest_path}"
  ensure
    sudo "rm -f /tmp/#{fname}"
  end
end
