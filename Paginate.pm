package Data::Paginate;

use strict;
use warnings;
use version;our $VERSION = qv('0.0.1');

use Carp qw(croak);
use POSIX ();
use Class::Std;
use Class::Std::Utils;

{ #### begin scoping "inside-out" class ##

#### manually set_ because they recalculate ##
#### needs manually set in BUILD ##

    my %total_entries             :ATTR('get' => 'total_entries', 'default' => '100');
    sub set_total_entries {
        my ($self, $digit, $checkonly) = @_;
        my $reftype        = ref $digit;
        croak 'Argument to set_total_entries() must be a digit or an array ref' if $digit !~ m/^\d+$/ && $reftype ne 'ARRAY';
        return 1 if $checkonly;
        $total_entries{ ident $self } = $reftype eq 'ARRAY' ? @{ $digit } 
                                                            : $digit;
        $self->_calculate();
    }

    my %entries_per_page          :ATTR('get' => 'entries_per_page', 'default' => '10');
    sub set_entries_per_page { 
        my ($self, $digit, $checkonly) = @_; 
        croak 'Argument to set_entries_per_page() must be a digit' 
            if $digit !~ m/^\d+$/;   
        return 1 if $checkonly;
        $entries_per_page{ ident $self } = $digit;        
        $self->_calculate();
    }

    my %pages_per_set             :ATTR('get' => 'pages_per_set', 'default' => '10');
    sub set_pages_per_set { 
        my ($self, $digit, $checkonly) = @_; 
        croak 'Argument to set_pages_per_set() must be a digit' 
           if $digit !~ m/^\d+$/;      
        return 1 if $checkonly;
        $pages_per_set{ ident $self } = $digit;     
        $self->_calculate();    
    }

    my %current_page              :ATTR('get' => 'current_page', 'default' => '1');
    sub _set_current_page {     
        my ($self, $digit, $checkonly) = @_;               
        croak 'Argument to _set_current_page() must be a digit' 
           if $digit !~ m/^\d+$/;         
        return 1 if $checkonly;
        $current_page{ ident $self } = $digit;               
        $self->_calculate();    
    }

    my %variable_entries_per_page :ATTR('get' => 'variable_entries_per_page', 'default' => {});
    sub set_variable_entries_per_page {
        my ($self, $hashref, $checkonly) = @_;
        croak 'Argument to set_variable_entries_per_page() must be a hashref' 
            if ref $hashref ne 'HASH';
        for(keys %{ $hashref }) {
            croak 'Non digit key in set_variable_entries_per_page() arg' 
                if $_ !~ m/^\d+$/;
            croak "Non digit value in set_variable_entries_per_page() arg $_" 
                if $hashref->{$_} !~ m/^\d+$/;
        }
        return 1 if $checkonly;
        $variable_entries_per_page{ idetn $self } = $hashref;
        $self->_calculate();
    }

#### manually set_ because they need input checked ##
#### needs manually set in BUILD ##

    my %page_result_display_map :ATTR('get' => 'page_result_display_map', 'default' => {}); 
    sub set_page_result_display_map {
        my ($self, $hashref) = @_;
        croak 'Argument to set_page_result_display_map() must be a hashref' 
            if ref $hashref ne 'HASH';
        $page_result_display_map{ ident $self } = $hashref;
    }

    my %set_result_display_map  :ATTR('get' => 'set_result_display_map', 'default' => {}); 
    sub set_set_result_display_map {
        my ($self, $hashref) = @_;
        croak 'Argument to set_result_display_map() must be a hashref' 
            if ref $hashref ne 'HASH';
        $set_result_display_map{ ident $self } = $hashref;
    }

    my %result_display_map      :ATTR; # set 2 above, no get_:
    sub set_result_display_map {
        my ($self, $hashref) = @_;
        croak 'Argument to set_result_display_map() must be a hashref' 
            if ref $hashref ne 'HASH';
        $page_result_display_map{ ident $self } = $hashref;
        $set_result_display_map{ ident $self } = $hashref;
    }

    my %html_line_white_space   :ATTR('get' => 'html_line_white_space', 'default' => '0'); 
    sub set_html_line_white_space {
        my ($self, $digit) = @_;
        croak 'Argument to set_html_line_white_space() must be a digit' 
            if $digit !~ m/^\d+$/;
        $html_line_white_space{ ident $self } = $digit;
    }

    my %param_handler           :ATTR('get' => 'param_handler', 'default' => sub {eval 'use CGI;';CGI::param(@_);});
    sub set_param_handler {
        my ($self, $coderef) = @_;
        croak 'Argument to set_param_handler() must be a code ref' 
            if ref $coderef ne 'CODE';
        $param_handler{ ident $self } = $coderef;
    }

    my %sets_in_rows            :ATTR('get' => 'sets_in_rows', 'default' => '0');         
    sub set_sets_in_rows {
        my ($self, $digit) = @_;
        croak 'Argument to set_sets_in_rows() must be a digit' 
            if $digit !~ m/^\d+$/;
        $sets_in_rows{ ident $self } = $digit;
    }

#### get_ only since these are set only by _calulate() is done ##

    my %entries_on_this_page :ATTR('get' => 'entries_on_this_page');
    my %first_page           :ATTR('get' => 'first_page');           
    my %last_page            :ATTR('get' => 'last_page');            
    my %first                :ATTR('get' => 'first');     
    my %last                 :ATTR('get' => 'last');   
    my %previous_page        :ATTR('get' => 'previous_page'); 
    my %next_page            :ATTR('get' => 'next_page');    

    my %previous_set         :ATTR('get' => 'previous_set'); 
    my %next_set             :ATTR('get' => 'next_set');    
    my %pages_in_set         :ATTR('get' => 'pages_in_set');  

    my %last_set             :ATTR('get' => 'last_set');        
    my %first_set            :ATTR('get' => 'first_set');   
    my %last_page_in_set     :ATTR('get' => 'last_page_in_set');  
    my %first_page_in_set    :ATTR('get' => 'first_page_in_set');  
    my %current_set          :ATTR('get' => 'current_set');      

#### manually get_ only because they require handling ##

    sub get_pages_range {  
        my ($self) = @_;  
        return ($first{ ident $self } - 1 .. $last{ ident $self } - 1);
    }

    sub get_pages_splice { 
        my($self, $arrayref) = @_;
        return @{ $arrayref }[ $self->get_pages_range() ];
    }

    sub get_pages_splice_ref {
        my($self, $arrayref) = @_;
        return [ $self->get_pages_splice($arrayref) ];
    }

    sub get_firstlast {
        my ($self) = @_;
        return ($first{ ident $self }, $last{ ident $self }) if wantarray;
        return "$first{ ident $self },$last{ ident $self }";
    }

    sub get_lastfirst {
        my ($self) = @_;
        return ($last{ ident $self }, $first{ ident $self }) if wantarray;
        return "$last{ ident $self },$first{ ident $self }";
    }

    sub get_state_hashref {
        my ($self) = @_;
        my $hashref = eval $self->_DUMP(); 
        return $hashref->{ ref $self }; 
    }

#### get_ and set_ ##

    #### no default, handle in BUILD since it chokes on '&'
    my %pre_current_page       :ATTR('get' => 'pre_current_page', 'set' => 'pre_current_page', 'init_arg' => 'pre_current_page');
    my %pst_current_page       :ATTR('get' => 'pst_current_page', 'set' => 'pst_current_page', 'init_arg' => 'pst_current_page');
    my %pst_current_set        :ATTR('get' => 'pst_current_set', 'set' => 'pst_current_set', 'init_arg' => 'pst_current_set');
    my %pre_current_set        :ATTR('get' => 'pre_current_set', 'set' => 'pre_current_set', 'init_arg' => 'pre_current_set');

    my %total_entries_param    :ATTR('get' => 'total_entries_param', 'set' => 'total_entries_param', 'default' => 'te', 'init_arg' => 'total_entries_param');
    my %set_param              :ATTR('get' => 'set_param', 'set' => 'set_param', 'default' => 'st', 'init_arg' => 'set_param');
    my %next_page_html         :ATTR('get' => 'next_page_html', 'set' => 'next_page_html', 'default' => 'Next Page &rarr;', 'init_arg' => 'next_page_html');
    my %page_param             :ATTR('get' => 'page_param', 'set' => 'page_param', 'default' => 'pg', 'init_arg' => 'page_param');
    my %simple_nav             :ATTR('get' => 'simple_nav', 'set' => 'simple_nav', 'default' => '0', 'init_arg' => 'simple_nav');
    my %cssid_set              :ATTR('get' => 'cssid_set', 'set' => 'cssid_set', 'default' => 'set', 'init_arg' => 'cssid_set');
    my %cssid_not_current_page :ATTR('get' => 'cssid_not_current_page', 'set' => 'cssid_not_current_page', 'default' => 'notpg', 'init_arg' => 'cssid_not_current_page');
    my %cssid_current_set      :ATTR('get' => 'cssid_current_set', 'set' => 'cssid_current_set', 'default' => 'curst', 'init_arg' => 'cssid_current_set');
    my %pre_not_current_set    :ATTR('get' => 'pre_not_current_set', 'set' => 'pre_not_current_set', 'default' => '[', 'init_arg' => 'pre_not_current_set');
    my %pre_not_current_page   :ATTR('get' => 'pre_not_current_page', 'set' => 'pre_not_current_page', 'default' => '[', 'init_arg' => 'pre_not_current_page');
    my %pst_not_current_set    :ATTR('get' => 'pst_not_current_set', 'set' => 'pst_not_current_set', 'default' => ']', 'init_arg' => 'pst_not_current_set');
    my %prev_set_html          :ATTR('get' => 'prev_set_html', 'set' => 'prev_set_html', 'default' => '&larr; Prev Set', 'init_arg' => 'prev_set_html');
    my %one_set_hide           :ATTR('get' => 'one_set_hide', 'set' => 'one_set_hide', 'default' => '0', 'init_arg' => 'one_set_hide');
    my %no_prev_set_html       :ATTR('get' => 'no_prev_set_html', 'set' => 'no_prev_set_html', 'default' => '', 'init_arg' => 'no_prev_set_html');
    my %as_table               :ATTR('get' => 'as_table', 'set' => 'as_table', 'default' => '0', 'init_arg' => 'as_table');
    my %pst_not_current_page   :ATTR('get' => 'pst_not_current_page', 'set' => 'pst_not_current_page', 'default' => ']', 'init_arg' => 'pst_not_current_page');
    my %style                  :ATTR('get' => 'style', 'set' => 'style', 'default' => '<style type="text/css"><!-- #page {text-align: center} #set {text-align: center} --></style>', 'init_arg' => 'style');
    my %no_prev_page_html      :ATTR('get' => 'no_prev_page_html', 'set' => 'no_prev_page_html', 'default' => '', 'init_arg' => 'no_prev_page_html');
    my %one_page_hide          :ATTR('get' => 'one_page_hide', 'set' => 'one_page_hide', 'default' => '0', 'init_arg' => 'one_page_hide');
    my %next_set_html          :ATTR('get' => 'next_set_html', 'set' => 'next_set_html', 'default' => 'Next Set &rarr;', 'init_arg' => 'next_set_html');
    my %one_set_html           :ATTR('get' => 'one_set_html', 'set' => 'one_set_html', 'default' => '', 'init_arg' => 'one_set_html');
    my %no_next_page_html      :ATTR('get' => 'no_next_page_html', 'set' => 'no_next_page_html', 'default' => '', 'init_arg' => 'no_next_page_html');
    my %cssid_current_page     :ATTR('get' => 'cssid_current_page', 'set' => 'cssid_current_page', 'default' => 'curpg', 'init_arg' => 'cssid_current_page');
    my %no_next_set_html       :ATTR('get' => 'no_next_set_html', 'set' => 'no_next_set_html', 'default' => '', 'init_arg' => 'no_next_set_html');
    my %prev_page_html         :ATTR('get' => 'prev_page_html', 'set' => 'prev_page_html', 'default' => '&larr; Prev Page', 'init_arg' => 'prev_page_html');
    my %cssid_page             :ATTR('get' => 'cssid_page', 'set' => 'cssid_page', 'default' => 'page', 'init_arg' => 'cssid_page');
    my %cssid_not_current_set  :ATTR('get' => 'cssid_not_current_set', 'set' => 'cssid_not_current_set', 'default' => 'notst', 'init_arg' => 'cssid_not_current_set');
    my %use_of_vars            :ATTR('get' => 'use_of_vars', 'set' => 'use_of_vars', 'default' => '0', 'init_arg' => 'use_of_vars');
    my %one_page_html          :ATTR('get' => 'one_page_html', 'set' => 'one_page_html', 'default' => '', 'init_arg' => 'one_page_html');

    my %of_page_string         :ATTR('get' => 'of_page_string', 'set' => 'of_page_string', 'default' => 'Page', 'init_arg' => 'of_page_string');
    my %of_set_string          :ATTR('get' => 'of_set_string',  'set' => 'of_set_string',  'default' => 'Set',  'init_arg' => 'of_set_string');
    my %of_of_string           :ATTR('get' => 'of_of_string',   'set' => 'of_of_string',   'default' => 'of',   'init_arg' => 'of_of_string');
    my %of_page_html           :ATTR('get' => 'of_page_html',   'set' => 'of_page_html',   'default' => '',     'init_arg' => 'of_page_html');
    my %of_set_html            :ATTR('get' => 'of_set_html',    'set' => 'of_set_html',    'default' => '',     'init_arg' => 'of_set_html');

    sub _calculate {
        my ($self) = @_;
        my $ident = ident $self;

        $current_page{$ident}          = ((($current_set{$ident} - 1) * $pages_per_set{$ident}) + 1)
            if defined $current_set{$ident} && $current_set{$ident} =~ m/^\d+$/ && $current_set{$ident} > 0;

        $first_page_in_set{$ident}     = 0; # set to 0 so its numeric 
        $last_page_in_set{$ident}      = 0; # set to 0 so its numeric

        my $per_page                   = exists $variable_entries_per_page{$ident}->{ $current_page{$ident} } 
            ? $variable_entries_per_page{$ident}->{ $current_page{$ident} } : $entries_per_page{$ident};

        my ($p,$r) = (0,0);
        for(keys %{ $variable_entries_per_page{$ident} }) {
            if($variable_entries_per_page{$ident}->{$_} =~ m/^\d+$/) {
                $p++;
                $r                    += int($variable_entries_per_page{$ident}->{$_});
            }
        }

        ($first_page{$ident}, $first{$ident}, $last{$ident}) = (1,0,0);
        $last_page{$ident}             = POSIX::ceil($p + (($total_entries{$ident} - $r) / $entries_per_page{$ident}));
        $current_page{$ident}          = $last_page{$ident} if $current_page{$ident} > $last_page{$ident};

        for($first_page{$ident} .. $current_page{$ident}) {
            if($current_page{$ident} == $last_page{$ident} && $_ == $current_page{$ident}) {
                $first{$ident}         = $last{$ident} + 1;
                $last{$ident}         += $total_entries{$ident} - $last{$ident};
            } 
            else {
                $last{$ident}         += exists $variable_entries_per_page{$ident}->{$_} 
                    ? $variable_entries_per_page{$ident}->{$_} : $entries_per_page{$ident};
            }
        }

        $first{$ident}                 = $last{$ident} - ($per_page - 1) if !$first{$ident};
        $previous_page{$ident}         = $current_page{$ident} - 1;
        $next_page{$ident} = (($current_page{$ident} + 1) <= $last_page{$ident}) ? $current_page{$ident} + 1 : 0 ;
        $entries_on_this_page{$ident}  = ($last{$ident} - $first{$ident}) + 1;

        $of_page_string{$ident} = 'Page' unless defined $of_page_string{$ident}; # why do we need this hack, what make Class::Std miss it ??
        $of_of_string{$ident}   = 'of' unless defined $of_of_string{$ident}; # why do we need this hack, what make Class::Std miss it ??
        $of_page_html{$ident}          = "$of_page_string{$ident} $current_page{$ident} $of_of_string{$ident} $last_page{$ident}";

        if($pages_per_set{$ident} =~ m/^\d+$/ && $pages_per_set{$ident} > 0) {
            $last_set{$ident}          = POSIX::ceil($last_page{$ident} / $pages_per_set{$ident});
            $current_set{$ident}       = POSIX::ceil($current_page{$ident} / $pages_per_set{$ident})
                unless defined $current_set{$ident} && $current_set{$ident} =~ m/^\d+$/ && $current_set{$ident} > 0;
            $current_set{$ident}       = $last_set{$ident} if $current_set{$ident} > $last_set{$ident};
            $first_page_in_set{$ident} = (($current_set{$ident} - 1) * $pages_per_set{$ident}) + 1;
            $last_page_in_set{$ident}  = ($first_page_in_set{$ident} + $pages_per_set{$ident}) - 1;
 
            $first_set{$ident}         = 1;
            $previous_set{$ident}      = $current_set{$ident} - 1;
            $next_set{$ident}          = (($current_set{$ident} + 1) <= $last_set{$ident}) ? $current_set{$ident} + 1 : 0 ;
            $pages_in_set{$ident}      = $current_set{$ident} == $last_set{$ident} 
                ? $total_entries{$ident} - (($last_set{$ident} - 1) * $pages_per_set{$ident}) : $pages_per_set{$ident};

            $of_set_string{$ident} = 'Set' unless defined $of_set_string{$ident}; # why do we need this hack, what make Class::Std miss it ??
            $of_set_html{$ident}       = "$of_set_string{$ident} $current_set{$ident} $of_of_string{$ident} $last_set{$ident}";
        }
    }

    sub BUILD {
        my ($self, $ident, $arg_ref) = @_;

        #### since ATTR: chokes on default => ' with an & escaped or not... ##
        $pre_current_page{ $ident }          = exists $arg_ref->{pre_current_set}  ? $arg_ref->{pre_current_set} : q{&#187;};
        $pst_current_page{ $ident }          = exists $arg_ref->{pst_current_page} ? $arg_ref->{pst_current_page} : q{&#171;};
        $pre_current_set{ $ident }           = exists $arg_ref->{pre_current_set}  ? $arg_ref->{pre_current_set}  : q{&#187;};
        $pst_current_set{ $ident }           = exists $arg_ref->{pst_current_set}  ? $arg_ref->{pst_current_set}  : q{&#171;};

        $result_display_map{ $ident }       = exists $arg_ref->{result_display_map}      ? exists $arg_ref->{result_display_map}      : {};  
        $page_result_display_map{ $ident }  = exists $arg_ref->{page_result_display_map} ? exists $arg_ref->{page_result_display_map} : {};
        $set_result_display_map{ $ident }   = exists $arg_ref->{set_result_display_map}  ? exists $arg_ref->{set_result_display_map}  : {};
        $html_line_white_space{ $ident }    = exists $arg_ref->{html_line_white_space}   ? exists $arg_ref->{html_line_white_space}   : 0;
        $param_handler{ $ident }            = exists $arg_ref->{param_handler}           
            ? exists $arg_ref->{param_handler} : sub {eval 'use CGI;';CGI::param(@_);};
        $sets_in_rows{ $ident }             = exists $arg_ref->{sets_in_rows}            ? exists $arg_ref->{sets_in_rows}            : 0;

        #### $self->set_result_display_map( $result_display_map{ $ident } ); # this poofs the whole thing w/out error, why ?? ##
        $self->set_page_result_display_map( $page_result_display_map{ $ident } );
        $self->set_set_result_display_map( $set_result_display_map{ $ident } );
        $self->set_html_line_white_space( $html_line_white_space{ $ident } );
        $self->set_param_handler( $param_handler{ $ident } );
        $self->set_sets_in_rows( $sets_in_rows{ $ident } );

        $total_entries{ $ident }             = exists $arg_ref->{total_entries}             ? $arg_ref->{total_entries}             
                                                                                            : $param_handler{ $ident }->($total_entries_param{ $ident }) || 100; 
        $entries_per_page{ $ident }          = exists $arg_ref->{entries_per_page}          ? $arg_ref->{entries_per_page}          
                                                                                            : 10; # param 'pp' ???
        $pages_per_set{ $ident }             = exists $arg_ref->{pages_per_set}             ? $arg_ref->{pages_per_set} : 10;

        $page_param{ $ident }                = exists $arg_ref->{page_param}                ? $arg_ref->{page_param}    : 'pg';
        $set_param{ $ident }                 = exists $arg_ref->{set_param}                 ? $arg_ref->{set_param}     : 'st';

        $current_page{ $ident } = 1;
        if($arg_ref->{current_page} !~ m/^\d+$/ 
           || $arg_ref->{current_page} < 1) {
            my $curpg = $param_handler{ $ident }->($page_param{ $ident });
            $current_page{ $ident } = $curpg if defined $curpg 
                                                && $curpg =~ m/^\d+$/ 
                                                && $curpg > 0;
        } 

        if($arg_ref->{current_set} !~ m/^\d+$/ 
           || $arg_ref->{current_set} < 1) {
            my $curst = $param_handler{ $ident }->($set_param{ $ident });
            $current_set{ $ident } = $curst if defined $curst
                                                && $curst =~ m/^\d+$/
                                                && $curst > 0;
        }
#        $current_page{ $ident }              = exists $arg_ref->{current_page}              ? $arg_ref->{current_page}              
#                                                                                            : $param_handler{ $ident }->($page_param{ $ident }) || 1;
#        $current_set{ $ident }               = exists $arg_ref->{current_set}               ? $arg_ref->{current_set}
#                                                                                            : $param_handler{ $ident }->($set_param{ $ident }) || 1;

        $variable_entries_per_page{ $ident } = exists $arg_ref->{variable_entries_per_page} ? $arg_ref->{variable_entries_per_page} : {};

        #### second true arg is undocumented for a reason, don't use it - ever ##
        $self->set_total_entries( $total_entries{ $ident }, 1 );
        $self->set_entries_per_page( $entries_per_page{ $ident }, 1 );
        $self->set_pages_per_set( $pages_per_set{ $ident }, 1 );
        $self->_set_current_page( $current_page{ $ident }, 1 );
        $self->set_variable_entries_per_page( $variable_entries_per_page{ $ident}, 1 );

        $self->_calculate();
    }

    sub get_navi_html {
        my($self) = @_;
        my $ident = ident $self;

        eval 'use CGI';
        my $cgi = CGI->new();

        my $fixq = sub {
            my ($cgi) = @_;
            $cgi->delete($page_param{ $ident }) 
                if defined $page_param{ $ident };
            $cgi->delete($set_param{ $ident })
                if defined $page_param{ $ident };
            $cgi->delete($total_entries_param{ $ident })
                if defined $total_entries_param{ $ident };
            $cgi->param($total_entries_param{ $ident }, 
                        $total_entries{ $ident })
                if $total_entries_param{ $ident };
            1;
        };

        $fixq->($cgi); # do it here to clear current data

        $page_param{ $ident } = 'pg' if !$page_param{ $ident };
        $set_param{ $ident }  = 'st' if !$set_param{ $ident };

#   my $pgn = shift;
#   my $hsh = shift;
#   if(ref($hsh) eq 'HASH') { for(keys %{ $hsh }) { $var->($_,$hsh->{$_}); } }
#   $fixq->($cgi); # do it again here in case they changed the param names on us

        my $slf  = $cgi->url(relative=>1);
        my $sets = '';
        my $page = '';

        my $ws   = ' ' x $html_line_white_space{ $ident };
        my $div  = $as_table{ $ident } ? 'tr'  : 'div';
        my $spn  = $as_table{ $ident } ? 'td'  : 'span';
        my $tbl  = $as_table{ $ident } ? '   ' : '';
        my $beg  = $as_table{ $ident } ? "$ws<table $as_table{ $ident }>\n" : "\n";
        my $end  = $as_table{ $ident } ? "$ws</table>\n" : '';
        
# TODO-0 as_table if num of pages_in_set != $ numeber of sets (add more <td></td> or only show pages_in_set amount???)
# TODO1 if($sets_in_rows{ $ident } && $pages_per_set{ $ident }) {
#
# TODO1 } else {
            my ($simple_prev,$simple_next) = ('','');
            if($pages_per_set{ $ident }) {
                if($one_set_hide{ $ident } && $last_set{ $ident } == 1) { $sets = $one_set_html{ $ident }; }
                else {
                    $sets .= "$ws$tbl<$div id=\"$cssid_set{ $ident }\">\n";
                    $sets .= "$ws$tbl   <$spn id=\"cssid_set\">$of_set_html{ $ident }</$spn>\n" if $use_of_vars{ $ident };
                    $simple_prev .= qq($ws$tbl   <$spn id="$cssid_not_current_set{ $ident }">$no_prev_set_html{ $ident }</$spn>\n) if !$previous_set{ $ident };
                    if($previous_set{ $ident }) {
                        $cgi->param($set_param{ $ident }, $previous_set{ $ident });
                        my $url = $slf . '?' . $cgi->query_string();
                        $cgi->delete($set_param{ $ident });
                        $simple_prev .= qq($ws$tbl   <$spn id="$cssid_not_current_set{ $ident }"><a href="$url">$prev_set_html{ $ident }</a></$spn>\n);
                    }
                    $sets .= $simple_prev;
                    for($first_set{ $ident } .. $last_set{ $ident }) {
                        $cgi->param($set_param{ $ident }, $_);
                        my $url = $slf . '?' . $cgi->query_string();
                        $cgi->delete($set_param{ $ident });

                        my $disp = $set_result_display_map{ $ident }->{$_} || $_;
                        $sets .= qq($ws$tbl   <$spn id="$cssid_current_set{ $ident }">$pre_current_set{ $ident }$disp$pst_current_set{ $ident }</$spn>\n) if $_ == $current_set{ $ident };
                        $sets .= qq($ws$tbl   <$spn id="$cssid_not_current_set{ $ident }">$pre_not_current_set{ $ident }<a href="$url">$disp</a>$pst_not_current_set{ $ident }</$spn>\n) if $_ != $current_set{ $ident };
                    }
                    $simple_next .= qq($ws$tbl   <$spn id="$cssid_not_current_set{ $ident }">$no_next_set_html{ $ident }</$spn>\n) if !$next_set{ $ident };
                    if($next_set{ $ident }) {
                        $cgi->param($set_param{ $ident }, $next_set{ $ident });
                        my $url = $slf . '?' . $cgi->query_string();
                        $cgi->delete($set_param{ $ident });
                        $simple_next .= qq($ws$tbl   <$spn id="$cssid_not_current_set{ $ident }"><a href="$url">$next_set_html{ $ident }</a></$spn>\n);
                    }
                    $sets .= $simple_next;
                    $sets .= "$ws$tbl</$div>\n";
                }
            }
            if($one_page_hide{ $ident } && $last_page{ $ident } == 1) { $page = $one_page_html{ $ident }; }
            else {
                $page .= "$ws$tbl<$div id=\"$cssid_page{ $ident }\">\n";
                $page .= "$ws$tbl   <$spn id=\"cssid_page\">$of_page_html{ $ident }</$spn>\n" if $use_of_vars{ $ident };
                $page .= $simple_prev if $simple_nav{ $ident };
                $page .= qq($ws$tbl   <$spn id="$cssid_not_current_page{ $ident }">$no_prev_page_html{ $ident }</$spn>\n) if !$previous_page{ $ident };
                if($previous_page{ $ident  }) {
                    $cgi->param($page_param{ $ident }, $previous_page{ $ident });
                    my $url = $slf . '?' . $cgi->query_string();
                    $cgi->delete($page_param{ $ident });
                    $page .= qq($ws$tbl   <$spn id="$cssid_not_current_page{ $ident }"><a href="$url">$prev_page_html{ $ident }</a></$spn>\n);
                }
                my $strt = $first_page_in_set{ $ident } || $first_page{ $ident };
                my $stop = $last_page_in_set{ $ident } < $last_page{ $ident } && $last_page_in_set{ $ident } > 0 ? $last_page_in_set{ $ident } : $last_page{ $ident };
                for($strt .. $stop) {
                    $cgi->param($page_param{ $ident }, $_);
                    my $url = $slf . '?' . $cgi->query_string();
                    $cgi->delete($page_param{ $ident });

                    my $disp = $page_result_display_map{ $ident }->{$_} || $_;
                    $page .= qq($ws$tbl   <$spn id="$cssid_current_page{ $ident }">$pre_current_page{ $ident }$disp$pst_current_page{ $ident }</$spn>\n) if $_ == $current_page{ $ident };
                    $page .= qq($ws$tbl   <$spn id="$cssid_not_current_page{ $ident }">$pre_not_current_page{ $ident }<a href="$url">$disp</a>$pst_not_current_page{ $ident }</$spn>\n) if $_ != $current_page{ $ident };
                }
                $page .= qq($ws$tbl   <$spn id="$cssid_not_current_page{ $ident }">$no_next_page_html{ $ident }</$spn>\n) if !$next_page{ $ident };
                if($next_page{ $ident }) {
                    $cgi->param($page_param{ $ident }, $next_page{ $ident });
                    my $url = $slf . '?' . $cgi->query_string();
                    $cgi->delete($page_param{ $ident });
                    $page .= qq($ws$tbl   <$spn id="$cssid_not_current_page{ $ident }"><a href="$url">$next_page_html{ $ident }</a></$spn>\n);
                }
                $page .= $simple_next if $simple_nav{ $ident };
                $page .= "$ws$tbl</$div>\n";
            }
# TODO1 }
        return "$ws$style{ $ident }$beg$page$end" if $simple_nav{ $ident };
        return wantarray ? ( "$ws$style{ $ident }$beg$page$end", "$ws$style{ $ident }$beg$sets$end" ) : "$ws$style{ $ident }$beg$page$end$beg$sets$end";
    }

} #### end scoping "inside-out" class ##

1;

__END__

=head1 NAME

Data::Paginate - Perl extension for complete and efficient data pagination

=head1 SYNOPSIS

   use Data::Paginate;
   my $pgr = Data::Paginate->new(\%settings);

=head1 DESCRIPTION

This module gives you a single resource to paginate data very simply. 

It includes access to the page/data variables as well as a way to generate the navigation HTML and get the data for the current page from a list of data and many many other things. It can definately be extended to generate the navigation cotrols for XML, Tk, Flash, Curses, etc... (See "SUBCLASSING" below)

Each item in the "new()" and "Non new() entries" sections have a get_ and set_ method unless otherwise specified.

By that I mean if the "item" is "foo" then you can set it with $pgr->set_foo($new_value) and get it with $pgr->get_foo()...

=head1 new()

Its only argument can be a hashref where its keys are the names documented below in sections that say it can be specified in new().

Also, total_entries is the item that makes the most sense to use if you're only using one :)

=head2 Attributes that recalculate the page dynamics 

These all have get_ and set_ methods and can be specified in the hashref to new()

=over

=item total_entries (100)

This is the number of pieces of data to paginate.

When set it can be a digit or an array reference (whose number of elements is used as the digit)

=item entries_per_page (10)

The number of the "total_entries" that go in each page.

=item pages_per_set (10)

If set to a digit greater than 0 it turns on the use of "sets" in the object and tells it how many pages are to be in each set.

This is very handy to make the navigation easier to use. Say you have data that is paginated to 1000 pages.

If you set this to, say 20, you'd see navigation for pages 1..20, then 21..30, etc etc instead of 1..1000 which would be ungainly.

The use of sets is encouraged but you can turn it off by setting it to 0.

=item current_page (1)

The current page of the data set. 

No set_ method. (IE it needs to be specified in new() or via the param handler (which is also set in new()) 

=item variable_entries_per_page ({})

An optional hashref whose key is the page number and the value is the number of entries for that page. 

For example to make all your data paginated as a haiku:

   $pgr->set_variable_entries_per_page({
       '1' => '5',
       '2' => '7',
       '3' => '5',
   });

Page 1 will have 5 records, page 2 will have 7 records, and page 3 will have 5 records.

Pages 4 on will have "entries_per_page" records.

It is ok to not specify them in any sort of range or run:

   $pgr->set_variable_entries_per_page({
       '34' => '42',
       '55' => '78',
       '89' => '99',
   });

=back

=head2 Some display settings that require specific types of values.

These all have get_ and set_ methods and can be specified in the hashref to new().

Their argument in assignments must be the same type as the default values.

=over

=item page_result_display_map ({})

An optional hashref whose key is the page number and the value is what to use in the navigation instead of the digit.

=item set_result_display_map ({})

An optional hashref whose key is the set number and the value is what to use in the navigation instead of the digit.

=item result_display_map ({})

An optional hashref that sets page_result_display_map and set_result_display_map to the same thing.

There is no get_ method for this.

=item html_line_white_space (0)

A digit that specifies the number of spaces to indent the HMTL in any get_*_html functions.

=item param_handler

A CODE reference to handle the parameres. See source if you have a need to modify this.

There is no get_ method for this.

=item sets_in_rows (0)

Not currently used, see TODO.

=back

=head2 Misc (HTML) display settings

All have get_ and set_ methods and can be specfied in new()

=over

=item pre_current_page (&#187;)

=item pst_current_page (&#171;)

=item pst_current_set (&#187;)

=item pre_current_set (&#171;)

=item total_entries_param (te)

=item set_param (st)

=item next_page_html (Next Page &rarr;)

=item page_param (pg)

=item simple_nav (0)

=item cssid_set (set)

=item cssid_not_current_page (notpg)

=item cssid_current_set (curst)

=item pre_not_current_set ([)

=item pre_not_current_page ([)

=item pst_not_current_set (])

=item pst_not_current_page (])

=item prev_set_html (&larr; Prev Set)

=item one_set_hide (0)

=item no_prev_set_html ('')

=item as_table (0)

=item style (style tag that centers "#page" and "#set"

=item no_prev_page_html ('')

=item one_page_hide (0)

=item next_set_html (Next Set &rarr;)

=item one_set_html ('')

=item no_next_page_html ('')

=item cssid_current_page (curpg)

=item no_next_set_html ('')

=item prev_page_html (&larr; Prev Page)

=item cssid_page (page)

=item cssid_not_current_set (notst)

=item use_of_vars (0)

=item one_page_html ('')

=item of_page_string (Page)

=item of_set_string (Set)

=item of_of_string (of)

=item of_page_html ('')

=item of_set_html ('')

=back 

=head1 Non new() entries

=head2 Data that gets set during calculation. 

Each has a get_ function but does not have a set_ funtion and cannot be specified in new()


=over
 

=item entries_on_this_page


The number of entries on the page, its always "entries_per_page" except when you are on the last page and there are less than "entries_per_page" left.

=item first_page 

The first page number, its always 1.

=item last_page

The last page number.

=item first

first record in page counting from 1 not 0

=item last 

last record on page counting from 1 not 0

=item previous_page 

Number of the previous page. 0 if currently on page 1

=item next_page  

Number of the next page. 0 if currently on last page.

=item current_set

Number of the current set

=item previous_set 

Number of the previous set. 0 if currently on set 1

=item next_set  

Number of the next set. 0 if currently on last set.

=item pages_in_set  

The number of pages in this set, its always "pages_per_set" except when you are on the last set and there are less than "pages_per_set" left.

=item last_set  

Number of last set.

=item first_set    

Number of first set, always 1

=item last_page_in_set    

Page number of the last page in the set.

=item first_page_in_set    

Page number of the first page in the set.

=back

=head1 Other methods

=head2 $pgr->get_navi_html()

Get HTML navigation for the object's current state.

In scalar context returns a single string with the HTML navigation.

In array context returns the page HTML as the first item and the set HTML as the second.

If simple_nav is true it returns a single string regardless of context.

    print scalar $pgr->get_navi_html();

=head2 $pgr->get_data_html()

See "to do"

=head2 get_ misc data (IE no set_)                          

=over

=item get_pages_range 


Returns an array of numbers that are indexes of the current page's range on the data array.

=item get_pages_splice 
        

Returns an array of the current page's data as sliced for the given arrayref.
        
    my @data_to_display = $pgr->get_pages_slice(\@orig_data);

=item get_pages_splice_ref        

Same as get_pages_splice but returns an array ref instead of an array.
        

=item get_firstlast 
           

In array context returns $pgr->get_first() and $pgr->get_last() as its items.
In scalar context it returns a stringified, comma seperated version.
        
    my($first, $last)  = $pgr->get_firstlast(); # '1' and '10' respectively
    my $first_last_csv = $pgr->get_firstlast(); # '1,10'

=item get_lastfirst

In array context returns $pgr->get_last() and $pgr->get_first() as its items.
In scalar context it returns a stringified, comma seperated version.

    my($last, $first)  = $pgr->get_lastfirst(); # '10' and '1' respectively
    my $last_first_csv = $pgr->get_lastfirst(); # '10,1'

=item get_state_hashref

Returns a hashref that is a snapshot of the current state of the object.
Useful for debugging and development.

=back

=head1 EXAMPLE use for HTML

Example using module to not only paginate easily but optimize database calls:

    # set total_entries *once* then pass it around 
    # in the object's links from then on for efficiency:
    my $total_entries = CGI::param('te') =~ m/^\d+$/ && CGI::param('te') > 0
        ? CGI::param('te') 
        : $dbh->select_rowarray("SELECT COUNT(*) FROM baz WHERE $where");

    my $pgr = Data::Paginate->new({ total_entries => $total_entries });

    # only SELECT current page's records:
    my $query = "SELECT foo, bar FROM baz WHERE $where LIMIT " 
                . $pgr->get_firstlast();

    print scalar $pgr->get_navi_html();

    for my $record (@{ $dbh->selectall_arrayref($query) }) {
        # display $record here
    }

    print scalar $pgr->get_navi_html();

=head1 SUBCLASSING

If you'd like to add functionality to this module *please* do it correctly. Part of the reason I made this module was that similar modules had functionality spread out among several modules that did not use the namespace model or subclassing paradigm correctly and made it really confusing and difficult to use.

So say you want to add functionality for TMBG please do it like so:

- use "Data::Paginate::TMBG" as the package name.

- use Data::Paginate; in your module

- make the method name like:

    sub Data::Paginate::get_navi_tmbg { # each subclass should have a get_navi_* function so its use is consistent
         my ($pgr) = @_; # Data::Paginate Object

    sub Data::Paginate::make_a_little_birdhouse_in_your_soul {
         my ($pgr) = @_; # Data::Paginate Object

That way it can be used like so:

    use Data::Paginate::TMBG; # no need to use Data::Paginate in the script since your module will use() it for use in its method(s)

    my $pgr = Data::Paginate->new({ total_entries => $total_entries }):

    $pgr->make_a_little_birdhouse_in_your_soul({ 'say' => q{I'm the only bee in your bonnet} }); # misc function to do whatever you might need

    print $pgr->get_navi_tmbg();
        

=head1 TO DO

- get_data_html()

- A few additions to get_navi_html()

- Improve POD documentation depending on feedback.

=head1 AUTHOR

Daniel Muey, L<http://drmuey.com/cpan_contact.pl>

=head1 COPYRIGHT AND LICENSE

Copyright 2005 by Daniel Muey

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
