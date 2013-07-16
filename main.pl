#!/usr/bin/perl

package main;

use warnings;
use strict;
use mylib::Twitter;

my $twitter = Twitter->new;

if ($twitter->is_new_randompost) {
  my $greeting = $twitter->get_greeting;

  if (defined($greeting)) {
    $twitter->statuses_update($greeting);
  }
}

$twitter->statuses_mentions;

