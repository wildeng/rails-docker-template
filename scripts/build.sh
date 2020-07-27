#!/usr/bin/env bash
#
# Manage a docker development environment for Demo App Portal

# Setting up default values
port='3000'
url='redis://redis:6379/0'
start=
build=

################################################################################
# Prints a help file
#
# Arguments:
#  None
################################################################################
usage() {
  cat <<USAGE >&2
Usage:
  -b build                Builds the containers
  -c Rubocop              Checks stile using Rubocop
  -d down                 Stops and removes the containers
  -h help                 Prints this help
  -i Bundle install       Runs bundle install
  -m migrate              Run all pending migrations
  -p port                 Port to be used by the Rails server
                          default is 3000
  -r stop                 Stops all running containers
  -s start                If not set up it builds and start a development environment.
                          It's one of the default options.
  -t run the tests        Runs the test suite
  -u redis url            URL of the redis instance, by default it uses
                          the one set up for the Redis container dependency
                          To start them you need to pass the -s option
  -v vulnerabilities      Checks current vulnerabilities using Brakeman

  If no options are passed to the script it will build and start the containers
  with default values.

  The script also exports env variables for MYSQL_USER and MYSQL_PASSWORD with
  default values which are the same defined in docker compose file.

  example:

  build_dev.sh

  Will start the containers using the default values. If the container weren't
  previously build, it will build them, run the migration and seeding he database.

  build_dev.sh -p 3001 -b

  Will build a container tha will be available on port 3001. However the containers
  will not be started.

USAGE
exit 0
}

################################################################################
# Prints the help file in case of error and then exits
#
# Arguments:
#   None
################################################################################
exit_abnormal() {
  usage
  exit 1
}

################################################################################
# Builds all the necessary containers for the dev environment
#
# Arguments:
#   None
################################################################################
build_container(){
  set_env_vars
  #docker-compose run --rm dev /bin/bash
  echo "building the environment"
  docker-compose build dev
}

################################################################################
# Revomes all the containers and their associated volumes
#
# Arguments:
#   None
################################################################################
remove_container(){
  set_env_vars
  # removing the containers and ther associated volumes
  docker-compose down -v
  exit 0
}

################################################################################
# Starts all the containers
# If containers have not been built, it will first build then.
# it also runs any pending migrations and seeds the database.
# If
#
# Arguments:
#   None
################################################################################
start(){
  set_env_vars
  echo "Starting the containers"
  docker-compose up -d dev

  echo "Waiting for the database to start"
  # Wait for the database to startrup before migrating
  ./script/docker/wait-for-it.sh db:3308 --timeout=25 --strict -- echo "Database is up!"

  echo "Migrating an seeding the database"

  docker-compose run --rm dev bundle exec rails db:create db:migrate db:seed

  echo "Attaching a terminal to the dev container"

  docker attach $(docker-compose ps -q dev )
}

################################################################################
# Stops all running containers
#
# Arguments:
#   None
################################################################################
stop(){
  echo "Stopping the containers"
  docker container stop $(docker container ps -q)
}

################################################################################
# Runs all pending migrations
#
# Arguments:
#   None
################################################################################
migrate(){
  set_env_vars
  echo "create db and running pending migrations"

  docker-compose run --rm dev bundle exec rake db:create db:migrate
  exit 0
}

################################################################################
# Runs all the tests
#
# Arguments:
#   None
################################################################################
run_tests(){
  set_env_vars
  echo "starting the containers"
  docker-compose build test
  echo "creating the database"
  docker-compose run --rm test bundle exec rake db:create RAILS_ENV=test
  echo "running migrations"
  docker-compose run --rm test bundle exec rake db:migrate RAILS_ENV=test
  echo "running all the tests"
  bundle="bundle install"
  spec="&& bundle exec rspec --format progress --format RspecJunitFormatter --out junit/rspec.xml"
  #echo "command: $bundle$spec"
  docker-compose run --rm test /bin/bash -c "$bundle$spec"
  exit 0
}

################################################################################
# Runs rubocop using dev containers
#
# Arguments:
#   None
################################################################################
rubocop(){
  set_env_vars
  echo "running Rubocop checkstyle"
  docker-compose run --rm dev rubocop
  exit 0
}

################################################################################
# Runs brakeman using dev containers
#
# Arguments:
#   None
################################################################################
brakeman(){
  set_env_vars
  echo "running Brakeman for vulnerabilities"
  docker-compose run --rm dev brakeman --no-exit-on-warn --no-exit-on-error -o brakeman-output.tabs
  exit 0
}

################################################################################
# Runs bundle install in dev containers
#
# Arguments:
#   None
################################################################################
bundle(){
  set_env_vars
  echo "running Bundle install"
  docker-compose run --rm dev bundle install
  exit 0
}

################################################################################
# Sets all environment variables
#
# Arguments:
#   None
################################################################################
set_env_vars(){
  # preparing env variables for the containers
  # MariaDB user and password can be changed to accomodate your needs,
  # remember to change them in the docker-compose file too
  export MYSQL_USER="<your user>"
  export MYSQL_PASSWORD="<your password>"
  export PORT=$port
  export REDIS_URL=$url
  echo "PORT has been set to ${PORT}"
  echo "REDIS_URL has been set to ${REDIS_URL}"

 # This a step needed on a Linux dev environment to avoid root user being the
 # owner of your development folder
  echo "Setting up user UID and GID"
  export uid=$(id -u)
  export gid=$(id -g)
}


# Checking the arguments
while getopts bcdhimprstuv: options; do
  case "${options}" in
    b) [ -n "$build" ] && usage || build='yes' ;;
    c) rubocop ;;
    d) [ -n "$build" ] && usage || build='no'  ;;
    h) usage ;;
    i) bundle ;;
    m) migrate ;;
    p)
      if [ -n "${OPTARG}" ]; then
        port=${OPTARG}
      else
        echo "Error: -p requires an argument"
        exit_abnormal
      fi
      ;;
    r) [ -n "$start" ] && usage || start='no' ;;
    s) [ -n "$start" ] && usage || start='yes' ;;
    t) run_tests ;;
    u)
      if [ -n "${OPTARG}" ]; then
         url=${OPTARG}
      else
        echo "Error: -u requires an argument"
        exit_abnormal
      fi
      ;;
    v) brakeman ;;
    *)
      echo "Error: Unknown argument: -${OPTARG}"
      exit_abnormal
      ;;
    esac
 done

 set_env_vars

 if [ "$build" = "yes" ]; then
   build_container
 else
   if [ "$build" = "no" ]; then
     remove_container
   fi
 fi

 if [ "$start" = "yes" ]; then
   start
 else
   if [ "$start" = "no" ]; then
     stop
   fi
 fi

 exit 0
