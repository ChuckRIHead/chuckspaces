#!/bin/bash
# Superset setup options
export SUP_ROW_LIMIT=5000 
export SUP_SECRET_KEY='thisismysecretkey' 
export SUP_CSRF_ENABLED=True



export LC_ALL=C.UTF-8
export LANG=C.UTF-8

set -xeo pipefail

export SUPERSET_HOME=$DOMINO_WORKING_DIR
export SUP_META_DB_URI=sqlite:///$DOMINO_WORKING_DIR/superset.db
env

# check to see if the superset config already exists, if it does skip to
# running the user supplied docker-entrypoint.sh, note that this means
# that users can copy over a prewritten superset config and that will be used
# without being modified
echo "Checking for existing Superset config..."
if [ ! -f $SUPERSET_HOME/superset_config.py ]; then
  echo "No Superset config found, creating from environment"
  touch $SUPERSET_HOME/superset_config.py

  cat > $SUPERSET_HOME/superset_config.py <<EOF
ROW_LIMIT = ${SUP_ROW_LIMIT}
WEBSERVER_THREADS = 4
SUPERSET_WEBSERVER_PORT = 8088
SUPERSET_WEBSERVER_TIMEOUT = 60
SECRET_KEY = '${SUP_SECRET_KEY}'
SQLALCHEMY_DATABASE_URI = '${SUP_META_DB_URI}'
CSRF_ENABLED = ${SUP_CSRF_ENABLED}

# https://stackoverflow.com/questions/48966344/assign-anonymoususermixin-to-a-real-user
AUTH_TYPE = 3
class PredefinedUserMiddleware:
    def __init__(self, app):
        self.app = app
    def __call__(self, environ, start_response):
        environ['REMOTE_USER'] = 'admin'
        return self.app(environ, start_response)
ADDITIONAL_MIDDLEWARE = [PredefinedUserMiddleware]

EOF
fi

# set up Superset if we haven't already
if [ ! -f $SUPERSET_HOME/.setup-complete ]; then

  echo "Running first time setup for Superset"
  /usr/local/anaconda/bin/fabmanager create-admin --app superset --username admin --password superset --firstname Admin --lastname Superset --email superset+admin@example.com
  
  echo "Initializing database"
  superset db upgrade

  echo "Creating default roles and permissions"
  superset init

  touch $SUPERSET_HOME/.setup-complete
else
  # always upgrade the database, running any pending migrations
  superset db upgrade
fi

echo "Starting up Superset"
superset runserver -a 0.0.0.0
