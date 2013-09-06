#!/usr/bin/env perl
package Galaxy::Workflow;
use Moose;
use JSON;

extends 'Galaxy';

has ['id', 'name'] => (
    is  => 'ro', 
    isa => 'Str'
);

has steps => (
    is => 'ro',
    isa => 'HashRef',
    lazy_build => 1
);

has source_step => (
    is => 'ro',
    isa => 'Int',
    lazy_build => 1
);

# Set at run time
has outputs => (
    is => 'rw',
    isa => 'ArrayRef',
    default => sub { [] }
);
has history => (
    is => 'rw',
    isa => 'Galaxy::History',
    required => 0
);

sub _build_source_step
{
    my ($self) = @_;
    
    if ( $Galaxy::VERBOSE ) {
        print "Searching first step of workflow " . $self->id . "\n";
    }
    
    while ( my ($step_id, $step_details) = each %{$self->steps} ) {
        if( not %{$step_details->{'input_steps'}} ) {
            return $step_id;
        }
    }
    
    # Should not get here
    die "Could not find source step for workflow " . $self->id;
}

sub _build_steps
{
    my ($self) = @_;
    
    if ( $Galaxy::VERBOSE ) {
        print "Loading steps of workflow " . $self->id . "\n";
    }
    
    my $details = $self->_request( 'GET', $Galaxy::WORKFLOWS_URL . '/' . $self->{'id'} );
    
    return $details->{'steps'};
}

sub run
{
    my ( $self, $history, $hda, $source_step ) = @_;
    $source_step ||= $self->source_step;
    
    if ( $Galaxy::VERBOSE ) {
        print "running " . $self->name . "\n";
    }
    
    # 3 required keys for running a workflow
    my %data = (
        'workflow_id'   => $self->id,
        'history'       => 'hist_id=' . $history->id,
        'ds_map'        => {}
    );
    
    # ds_map key defines inputs of each source step
    my %input_for_source = (
        $source_step => {
            'src' => 'hda',
            'id'  => $hda->{'id'},
        },
        # any other source step ...
    );
    
    $data{'ds_map'} = to_json( \%input_for_source );
    
    my $response = $self->_request( 'POST', $Galaxy::WORKFLOWS_URL, \%data );
    
    $self->history($history);
    $self->outputs($response->{'outputs'});
}

# Run this workflow from source step given a filepath
# It assumes the first step is an "upload file step"
sub quick_run
{
    my ( $self, $filepath ) = @_;
    
    my $history = $self->create_history('Unnamed history');
    my $hda = $history->upload_file( $filepath );
    
    return $self->run( $history, $hda );
}

sub has_completed
{
    my ($self) = @_;
    
    foreach my $hda_id (@{$self->outputs}) {
        my $hda = $self->history->get_hda( $hda_id );        
        
        if ( $hda->{'state'} ne 'ok' ) {
            return 0;
        }
    }
    
    return 1;
}

sub show_outputs
{
    my ($self) = @_;
    
    return $self->_request( 'GET', $Galaxy::DATASETS_URL . '/' . $self->outputs->[0] );
}
no Moose;

1;