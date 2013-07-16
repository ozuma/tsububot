#!/usr/bin/perl

package Twitter;

use utf8;
use strict;
use warnings;
use Encode;
use YAML;
use Net::Twitter;
use Data::Dumper;

my $VERSION = "0.40";

sub new {
  my $pkg = shift;

  my $RANDOM_MESSAGEFILE = "conf/random_message.txt";
  my $GREETINGFILE = "conf/greeting.txt";
  my $REPLYFILE = "conf/reply_keyword.txt";
  my $SINCEIDFILE = "stats/sinceid.txt";
  my $RANDOMLOGFILE = "stats/random_meslog.txt";
  my $TOKENFILE = "conf/token.txt";

  my $RANDOM_MESSAGE = YAML::LoadFile($RANDOM_MESSAGEFILE);
  my $GREETING = YAML::LoadFile($GREETINGFILE);
  my $REPLY = YAML::LoadFile($REPLYFILE);
  my $SINCEID = YAML::LoadFile($SINCEIDFILE);
  my $RANDOMLOG = YAML::LoadFile($RANDOMLOGFILE);
  my $TOKEN = YAML::LoadFile($TOKENFILE);

  my $TWITCON = Net::Twitter->new(
    traits   => [qw/OAuth API::RESTv1_1/],
    consumer_key        => "inbhMhZfctsHzgsdZfAzQ",
    consumer_secret     => "ceDrhPACPROu1bPlMKdAShXFHGhfkmspG8tPU96xI",
    access_token        => $TOKEN->{token},
    access_token_secret => $TOKEN->{secret},
  );

  # create reply key index. (priority ordered)
  my @REPLY_KEY = ();
  open(REPFP, "<$REPLYFILE");
  while (my $line = <REPFP>) {
    unless ($line =~ m/^[# :-]/) {
          $line =~ s/\r//;
      $line =~ s/\n//;
      $line =~ s/: .*//;
      push (@REPLY_KEY, $line);
    }
  }

  my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime(time);
  $year += 1900;
  $mon += 1;

  bless {
    sinceid => $SINCEID->{'number'},
    sinceid_filename => $SINCEIDFILE,
    randomlog => $RANDOMLOG->{'hour'},
    randomlog_filename => $RANDOMLOGFILE,
    random_message => $RANDOM_MESSAGE,
    reply => $REPLY,
    reply_key => \@REPLY_KEY,
    greeting => $GREETING,
    twitcon => $TWITCON,
    nowtime => { sec   => $sec,
                 min   => $min,
                 hour  => $hour,
                 mday  => $mday,
                 mon   => $mon,
                 year  => $year,
                 wday  => $wday,
                 yday  => $yday,
                 isdst => $isdst,
               },
  }, $pkg;
}


# Do I need to post a random message?
sub is_new_randompost {
  my $self = shift;
  my $retVal = 0;

  if ($self->{randomlog} != $self->{nowtime}->{hour}) {
    $retVal = 1;

    my $filename = $self->{randomlog_filename};
    open(FP, ">$filename");
    print FP "hour: $self->{nowtime}->{hour}\n";
    close(FP);
  }

  return $retVal;
}


sub get_greeting {
  my $self = shift;
  my $greeting;

  my $hour = $self->{nowtime}->{hour};

  if (exists($self->{greeting}->{$hour})) {
    if (ref($self->{greeting}->{$hour})) {
      my @message_arr = @{$self->{greeting}->{$hour}};
      $greeting = $message_arr[rand(int($#message_arr + 1))];
    } else {
      $greeting = $self->{greeting}->{$hour};
    }
    my $r_mes = $self->_get_random_message;
    $greeting =~ s/mes:random/$r_mes/;
  } else {
    $greeting = undef;
  }

  return $greeting;
}


sub statuses_update {
  my $self = shift;
  my $status = shift;

  my $req = $self->_auth_post_request($status);
}


sub statuses_mentions {
  my $self = shift;
  my @status_idlist = ();  # since_id

  my $res = $self->{twitcon}->mentions({since_id=>$self->{sinceid}});
#  print Dumper($res);

  my @mention_list = $self->_get_mentions_list($res);

  if (scalar(@mention_list) > 0) {
  # write since_id to file.(if mention exist.)
    my $s_filename = $self->{'sinceid_filename'};
    open(FP, ">$s_filename");
    # First mention has MAX sinceid. Save as String (since_id is too big for integer.)
    print FP "number: '$mention_list[0]->{status_id}'\n";
    close(FP);
  }

  # Let's twitt each mention.
  foreach my $mention (@mention_list) {
    my $message = "\@" . $mention->{'screenname'} . " " . $self->_get_default_reply($mention);
    push(@status_idlist, $mention->{'status_id'});

    # Does a mention match my keywords?
    foreach my $key (@{$self->{reply_key}}) {
      if ($mention->{'status_text'} =~ m/$key/ && exists($self->{reply}->{$key})) {
        my $reply = $self->{reply}->{$key};

        if (ref($reply)) {
          my @message_arr = @$reply;
          $reply = $message_arr[rand(int($#message_arr + 1))];
        }
        $reply =~ s/twitter:name/$mention->{'name'}/;
        $message = "\@" . $mention->{'screenname'} . " " . $reply;
        last;
      }
    }
    eval { $self->statuses_update($message); };
  }

}


sub _auth_post_request {
    my ($self, $status) = @_;

    my $res = $self->{twitcon}->update(Encode::decode_utf8($status));

    return $res;
}

sub _get_random_message {
  my $self = shift;

  srand;
  my @random_message = @{$self->{random_message}};
  return $random_message[rand(int($#random_message + 1))];
}


sub _get_default_reply {
  my ($self, $mention) = @_;

  my $reply = $self->{reply}->{'default'};
  if (ref($reply)) {
    my @message_arr = @$reply;
    $reply = $message_arr[rand(int($#message_arr + 1))];
  }

  $reply =~ s/twitter:name/$mention->{'name'}/;

  return $reply;
}



sub _get_mentions_list {
  my ($self, $mentions) = @_;

  my @retVal = ();

  foreach my $mention (@$mentions) {
    my $hashref = {
                  'status_id' => Encode::encode_utf8($mention->{id_str}),
                  'status_text' => Encode::encode_utf8($mention->{text}),
                  'screenname' => Encode::encode_utf8($mention->{user}->{screen_name}),
                  'userid' => Encode::encode_utf8($mention->{user}->{id}),
                  'name' => Encode::encode_utf8($mention->{user}->{name}),
                };
      push(@retVal, $hashref);
  }

  return @retVal;
}

1;

