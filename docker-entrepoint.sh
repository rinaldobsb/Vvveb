#!/bin/bash
echo $MYSQL_ENV_MYSQL_DATABASE:
echo $MYSQL_PORT_3306_TCP;
printenv -0;

if [[ "$1" == apache2* ]] || [ "$1" == php-fpm ]; then
  if [ -n "$MYSQL_PORT_3306_TCP" ]; then
    if [ -z "$DB_HOST" ]; then
      DB_HOST='db'
    else
      echo >&2 'warning: both DB_HOS and MYSQL_PORT_3306_TCP found'
      echo >&2 "  Connecting to DB_HOST ($DB_HOST)"
      echo >&2 '  instead of the linked mysql container'
    fi
  fi

  if [ -z "$DB_HOST" ]; then
    echo >&2 'error: missing DB_HOST and MYSQL_PORT_3306_ADDR environment variables'
    echo >&2 '  Did you forget to --link some_mysql_container:mysql or set an external db'
    echo >&2 '  with -e DB_HOST=hostname?'
    exit 1
  fi

  # if we're linked to MySQL and thus have credentials already, let's use them
  : ${DB_USER:=${MYSQL_ENV_MYSQL_USER:-root}}
  if [ "$DB_USER" = 'root' ]; then
    : ${DB_PASSWORD:=$MYSQL_ENV_MYSQL_ROOT_PASSWORD}
  fi

  : ${DB_PASSWORD:=$MYSQL_ENV_MYSQL_PASSWORD}
  : ${DB_DATABASE:=${MYSQL_ENV_MYSQL_DATABASE:-vvveb}}
  : ${DB_PORT:=${MYSQL_ENV_MYSQL_PORT:-3306}}
  : ${DB_DRIVER:=${MYSQL_ENV_MYSQL_DRIVER:-mysqli}}

  if [ -z "$DB_PASSWORD" ]; then
    echo >&2 'error: missing required DB_PASSWORD environment variable'
    echo >&2 '  Did you forget to -e DB_PASSWORD=... ?'
    echo >&2
    echo >&2 '  (Also of interest might be DB_USER and DB_DATABASE.)'
    exit 1
  fi

  if [[ "$1" == apache2* ]]; then
    CONF_FILE=/etc/apache2/conf-enabled/vvveb.conf
    grep -q "DB_HOST" "$CONF_FILE" || echo "PassEnv DB_HOST" > "$CONF_FILE"
    grep -q "DB_DATABASE" "$CONF_FILE" || echo "PassEnv DB_DATABASE" > "$CONF_FILE"
    grep -q "DB_USER" "$CONF_FILE" || echo "PassEnv DB_USER" > "$CONF_FILE"
    grep -q "DB_PASSWORD" "$CONF_FILE" || echo "PassEnv DB_PASSWORD" > "$CONF_FILE"
  elif [[ "$1" == php-fpm* ]]; then
    POOL_FILE=/usr/local/etc/php-fpm.d/www.conf
    grep -q "env['DB_HOST']" "$POOL_FILE" || echo "env['DB_HOST'] = $DB_HOST" >> "$POOL_FILE"
    grep -q "env['DB_DATABASE']" "$POOL_FILE" || echo "env['DB_DATABASE'] = $DB_DATABASE" >> "$POOL_FILE"
    grep -q "env['DB_USER']" "$DB_USER" || echo "env['DB_USER'] = $DB_USER" >> "$POOL_FILE"
    grep -q "env['DB_PASSWORD']" "$DB_PASSWORD" || echo "env['DB_PASSWORD'] = $DB_PASSWORD" >> "$POOL_FILE"
  fi

fi

exec "$@"
