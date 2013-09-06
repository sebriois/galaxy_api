Galaxy Perl API
===============

* View/create history
* Upload file to history
* Run workflow

Usage
=====

```Shell
export GALAXY_BASE_URL=http://galaxy_host:port
export GALAXY_API_KEY=<Galaxy user's api key> # Given in preferences
```
```Perl
#!/usr/bin/env perl
use strict;
use warnings;

use Galaxy;

my $galaxy = Galaxy->new;

my $new_history = $galaxy->create_history( 'History title' );
my $file_hda    = $new_history->upload_file( '/path/to/file' ); # hda: History Dataset Association

# Get workflow and run it under the new_history context
my $workflow = $galaxy->get_workflow( name => 'workflow name' );
$workflow->run( $history, $file_hda );

while( not $workflow->has_completed() ) {
    sleep( 1 ); # Or anything smarter ;)
}

print Dumper $workflow->show_outputs;
```
