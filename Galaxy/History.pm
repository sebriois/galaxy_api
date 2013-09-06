#!/usr/bin/env perl
package Galaxy::History;
use Moose;

use File::Basename;
use JSON;

extends 'Galaxy';

has ['id', 'name'] => (
    is  => 'ro', 
    isa => 'Str'
);

has hdas => (
    is => 'ro',
    isa => 'ArrayRef[HashRef]',
    lazy_build => 1
);

sub _build_hdas
{
    my ( $self ) = @_;
    
    return $self->_request( 'GET', $Galaxy::HISTORIES_URL . '/' . $self->id . '/contents' );
}

=pod
Return a HASH of detailed information for a specific HDA.
=cut
sub get_hda
{
    my ( $self, $hda_id ) = @_;
    
    return $self->_request( 'GET', $Galaxy::HISTORIES_URL . '/' . $self->id . '/contents/' . $hda_id );
}

sub upload_file
{
    my ( $self, $filepath, $file_type ) = @_;
    $file_type ||= 'auto';
    
    if ( $Galaxy::VERBOSE ) {
        print "Uploading $filepath ... \n";
    }
    
    my %data = (
        'tool_id'           => 'upload1',
        'history_id'        => $self->{'id'},
        'files_0|file_data' => [$filepath],
    );
    
    my %inputs = (
        'files_0|NAME'      => basename( $filepath ),
        'files_0|type'      => 'upload_dataset',
        'dbkey'             => '?',
        'file_type'         => $file_type,
        'ajax_upload'       => 'true',
    );
    
    $data{'inputs'} = to_json(\%inputs);
    
    my $response = $self->_request( 'POST', $Galaxy::TOOLS_URL, \%data );
    my $upload_details = $response->{'outputs'}->[0];
    
    # Return associated HDA
    my ($hda) = grep{ $_->{'name'} eq $upload_details->{'name'} } @{$self->hdas};
    
    return $hda;
}

no Moose;

1;