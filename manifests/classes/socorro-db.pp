class socorro-db inherits socorro-base {
    package {
	'postgresql-9.0':
            alias => 'postgresql',
            require => [Exec['update-postgres-ppa'], Exec['apt-get-update']],
	    ensure => 'present';

	'postgresql-plperl-9.0':
            alias => 'postgresql-plperl',
            require => Package['postgresql'],
	    ensure => 'present';

	'postgresql-contrib-9.0':
            alias => 'postgresql-contrib',
            require => Package['postgresql'],
	    ensure => 'present';
    }

    exec {
        '/usr/bin/createdb -E \'utf-8\' -T template0 breakpad':
            require => Package['postgresql'],
            unless => '/usr/bin/psql --list breakpad',
            alias => 'create-breakpad-db',
            user => 'postgres';
    }

    exec {
       'update-postgres-ppa':
            command => '/usr/bin/apt-get update',
            require => Exec['add-postgres-ppa'];

        '/usr/bin/sudo /usr/bin/add-apt-repository ppa:pitti/postgresql':
            alias => 'add-postgres-ppa',
            creates => '/etc/apt/sources.list.d/pitti-postgresql-lucid.list',
            require => Package['python-software-properties'];

        '/usr/bin/psql -f /home/socorro/dev/socorro/sql/schema/2.4/breakpad_roles.sql breakpad':
            alias => 'create-breakpad-roles',
            user => 'postgres',
            require => [Exec['create-breakpad-db'], Exec['socorro-clone']];

        '/usr/bin/psql -f /home/socorro/dev/socorro/sql/schema/2.4/breakpad_schema.sql breakpad':
            alias => 'setup-schema',
            user => 'postgres',
            require => [Exec['create-breakpad-roles'], Exec['socorro-clone']],
            onlyif => '/usr/bin/psql breakpad -c "\d reports" 2>&1 | grep "Did not find any relation"';
    }

    exec {
        '/usr/bin/psql -c "grant all on database breakpad to breakpad_rw"':
            alias => 'grant-breakpad-access',
            user => 'postgres',
            require => Exec['create-breakpad-roles'];
    }

    exec {
        '/usr/bin/psql breakpad < /usr/share/postgresql/9.0/contrib/citext.sql':
            user => 'postgres',
            require => [Exec['create-breakpad-db'], Package['postgresql-contrib']];
    }

    exec {
        '/usr/bin/psql -c "create language plpgsql" breakpad':
            user => 'postgres',
            unless => '/usr/bin/psql -c "SELECT lanname from pg_language where lanname = \'plpgsql\'" breakpad | grep plpgsql',
            alias => 'create-language-plpgsql',
            require => Exec['create-breakpad-db'];
    }

    exec {
        '/usr/bin/psql -c "create language plperl" breakpad':
            user => 'postgres',
            unless => '/usr/bin/psql -c "SELECT lanname from pg_language where lanname = \'plperl\'" breakpad | grep plperl',
            alias => 'create-language-plperl',
            require => [Exec['create-language-plpgsql'], Package['postgresql-plperl']];
    }

    exec {
        '/bin/bash /home/socorro/dev/socorro/tools/dataload/import.sh':
            alias => 'dataload',
            user => 'postgres',
            cwd => '/home/socorro/dev/socorro/tools/dataload/',
            onlyif => '/usr/bin/psql -xt breakpad -c "SELECT count(*) FROM reports" | grep "count | 0"',
            logoutput => on_failure,
            require => Exec['setup-schema'];
    }

    exec {
        '/usr/bin/psql -c "SELECT backfill_matviews(\'2012-01-02\', \'2012-01-03\'); UPDATE product_versions SET featured_version = true" breakpad':
            alias => 'bootstrap-matviews',
            user => 'postgres',
            onlyif => '/usr/bin/psql -xt breakpad -c "SELECT count(*) FROM product_versions" | grep "count | 0"',
            require => Exec['dataload'];
    }

    exec {
        '/usr/bin/createdb test':
            require => Package['postgresql'],
            unless => '/usr/bin/psql --list test',
            alias => 'create-test-db',
            user => 'postgres';
    }

    exec {
        '/usr/bin/psql -c "create role test login password \'aPassword\'"':
            alias => 'create-test-role',
            unless => '/usr/bin/psql -c "SELECT rolname from pg_roles where rolname = \'test\'" test | grep test',
            user => 'postgres',
            require => Exec['create-test-db'];
    }

    exec {
        '/usr/bin/psql -c "grant all on database test to test"':
            alias => 'grant-test-access',
            user => 'postgres',
            require => Exec['create-test-role'];
    }

    exec {
        '/usr/bin/psql test < /usr/share/postgresql/9.0/contrib/citext.sql':
            user => 'postgres',
            require => [Exec['create-test-db'], Package['postgresql-contrib']];
    }

    exec {
        '/usr/bin/psql -c "create language plpgsql" test':
            user => 'postgres',
            unless => '/usr/bin/psql -c "SELECT lanname from pg_language where lanname = \'plpgsql\'" test | grep plpgsql',
            require => Exec['create-test-db'];
    }

    exec {
        '/usr/bin/psql -c "create language plperl" test':
            user => 'postgres',
            unless => '/usr/bin/psql -c "SELECT lanname from pg_language where lanname = \'plperl\'" test | grep plperl',
            require => [Exec['create-test-db'], Package['postgresql-plperl']];
    }

    service {
        'postgresql':
            enable => true,
            alias => postgresql,
            require => Package['postgresql'],
            ensure => running;
    }

}
