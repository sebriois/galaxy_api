#!/usr/bin/env perl
# 
# created by : Sebastien Briois 01/09/2013
package Galaxy;
use Moose;

use Galaxy::History;
use Galaxy::Workflow;

use Data::Dumper;
use HTTP::Request::Common;
use LWP::UserAgent;
use URI;
use JSON;

our $API_KEY  = $ENV{'GALAXY_API_KEY'};
our $BASE_URL = $ENV{'GALAXY_BASE_URL'};
our $VERBOSE  = 1;

our $HISTORIES_URL = '/api/histories';
our $WORKFLOWS_URL = '/api/workflows';
our $TOOLS_URL     = '/api/tools';
our $DATASETS_URL  = '/api/datasets';

has histories => (
    is      => 'ro',
    isa     => 'ArrayRef[Galaxy::History]',
    auto_deref => 1,
    lazy_build => 1,
    init_arg => undef,
);

has workflows => (
    is      => 'ro',
    isa     => 'ArrayRef[Galaxy::Workflow]',
    auto_deref => 1,
    lazy_build => 1,
    init_arg => undef,
);

before  '_build_histories' => sub {my $self = shift; print "Loading histories ... " if $VERBOSE};
after   '_build_histories' => sub {my $self = shift; print "done.\n" if $VERBOSE};

before  '_build_workflows' => sub {my $self = shift; print "Loading workflows ... " if $VERBOSE};
after   '_build_workflows' => sub {my $self = shift; print "done.\n" if $VERBOSE};


#
#   LAZY BUILDS
#

sub _build_histories
{
    my ( $self ) = @_;
        
    my $histories = $self->_request( 'GET', $HISTORIES_URL );
    
    my @history_objects = map {
        Galaxy::History->new( id => $_->{'id'}, name => $_->{'name'} )
    } @$histories;
    
    return \@history_objects;
}

sub _build_workflows
{
    my ($self) = @_;
    
    my $workflows = $self->_request( 'GET', $WORKFLOWS_URL );
    
    my @workflow_objects = map {
        Galaxy::Workflow->new( id => $_->{'id'}, name => $_->{'name'} )
    } @$workflows;
        
    return \@workflow_objects;
}


###### PUBLIC METHODS

sub create_history
{
    my ( $self, $history_name ) = @_;
    
    my $new_history = $self->_request( 'POST', $HISTORIES_URL, { 'name' => $history_name } );
    
    if ( $VERBOSE ) {
        print "Created history! " . $new_history->{'name'} . " (" . $new_history->{'id'} . ")\n";
    }
    
    # Create actual Galaxy::History object
    my $history_obj = Galaxy::History->new( id => $new_history->{'id'}, name => $new_history->{'name'} );
    push( @{$self->histories}, $history_obj );
    
    return $history_obj;
}

sub get_workflow
{
    my ( $self, %filters ) = @_;
    
    my @selected_worflows = $self->workflows;
    while ( my ($key, $value) = each %filters ) {
        @selected_worflows = grep{ $_->{$key} eq $value } @selected_worflows;
    }
    
    my $selected_worflow = shift @selected_worflows;
    die "Workflow not found!"
        unless defined $selected_worflow;
    
    if ( $VERBOSE ) {
        print "Found workflow! " . $selected_worflow->{'name'} . "\n";
    }
    
    return $selected_worflow;
}


############ PRIVATE METHODS

sub _request
{
    my ( $self, $method, $url, $data ) = @_;
    
    $url = $self->_make_url( $BASE_URL . $url ); # insert api key into url
    
    my $request;
    
    if ( uc $method eq 'GET' ) {
        $request = GET( $url );
    }
    elsif( uc $method eq 'POST' ) {
        $request = POST( $url, 
            'Content_Type' => 'form-data', 
            'Content' => [ %$data ]
        );
    }
    elsif( uc $method eq 'PUT' ) {
        $request = PUT( $url,
            'Content_Type' => 'form-data', 
            'Content' => [ %$data ]
        );
    }
    elsif( uc $method eq 'DELETE' ) {
        $request = DELETE( $url );
    }
    
    my $browser  = LWP::UserAgent->new;
    my $response = $browser->request( $request );
    
    if ( !$response->is_success ) {
        die "[$url] " . $response->message . ' : ' . $response->decoded_content;
    }
    
    return from_json( $response->decoded_content );
}

#
# Adds the API Key to the URL if it's not already there.
# Note: API Key should always be in the URL, even when not using GET method
sub _make_url
{
    my ( $self, $url, $args ) = @_;
    $args ||= [];
    
    my $argsep = '&';
    
    if ( not $url =~ m/\?/ ) {
        $argsep = '?';
    }
    
    if ( not $url =~ m/\?key/ && not  $url =~ m/&key=/ ) {
        unshift( @$args, [ 'key', $API_KEY ] );
    }
    
    return $url . $argsep . join( '&', join( '=', map{ @{$_} } @$args ) );
}

no Moose;

1;
