# Copyright (C) 2003  Free Software Foundation, Inc.

# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2, or (at your option)
# any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA
# 02111-1307, USA.

package Automake::FileUtils;

use strict;
use Exporter;
use File::stat;
use IO::File;
use Automake::Channels;
use Automake::ChannelDefs;

use vars qw (@ISA @EXPORT);

@ISA = qw (Exporter);
@EXPORT = qw (&find_file &mtime &update_file &xsystem &contents);


# $FILENAME
# find_file ($FILENAME, @INCLUDE)
# -------------------------------
# We match exactly the behavior of GNU m4: first look in the current
# directory (which includes the case of absolute file names), and, if
# the file is not absolute, just fail.  Otherwise, look in the path.
#
# If the file is flagged as optional (ends with `?'), then return undef
# if absent.
sub find_file ($@)
{
  use File::Spec;

  my ($filename, @include) = @_;
  my $optional = 0;

  $optional = 1
    if $filename =~ s/\?$//;

  return File::Spec->canonpath ($filename)
    if -e $filename;

  if (File::Spec->file_name_is_absolute ($filename))
    {
      fatal "$filename: no such file or directory"
	unless $optional;
      return undef;
    }

  foreach my $path (reverse @include)
    {
      return File::Spec->canonpath (File::Spec->catfile ($path, $filename))
	if -e File::Spec->catfile ($path, $filename)
    }

  fatal "$filename: no such file or directory"
    unless $optional;

  return undef;
}

# $MTIME
# MTIME ($FILE)
# -------------
# Return the mtime of $FILE.  Missing files, or `-' standing for STDIN
# or STDOUT are ``obsolete'', i.e., as old as possible.
sub mtime ($)
{
  my ($file) = @_;

  return 0
    if $file eq '-' || ! -f $file;

  my $stat = stat ($file)
    or fatal "cannot stat $file: $!";

  return $stat->mtime;
}


# &update_file ($FROM, $TO)
# -------------------------
# Rename $FROM as $TO, preserving $TO timestamp if it has not changed.
# Recognize `$TO = -' standing for stdin.
sub update_file ($$)
{
  my ($from, $to) = @_;
  my $SIMPLE_BACKUP_SUFFIX = $ENV{'SIMPLE_BACKUP_SUFFIX'} || '~';
  use File::Compare;
  use File::Copy;

  if ($to eq '-')
    {
      my $in = new IO::File ("$from");
      my $out = new IO::File (">-");
      while ($_ = $in->getline)
	{
	  print $out $_;
	}
      $in->close;
      unlink ($from) || fatal "cannot not remove $from: $!";
      return;
    }

  if (-f "$to" && compare ("$from", "$to") == 0)
    {
      # File didn't change, so don't update its mod time.
      msg 'note', "`$to' is unchanged";
      return
    }

  if (-f "$to")
    {
      # Back up and install the new one.
      move ("$to",  "$to$SIMPLE_BACKUP_SUFFIX")
	or fatal "cannot not backup $to: $!";
      move ("$from", "$to")
	or fatal "cannot not rename $from as $to: $!";
      msg 'note', "`$to' is updated";
    }
  else
    {
      move ("$from", "$to")
	or fatal "cannot not rename $from as $to: $!";
      msg 'note', "`$to' is created";
    }
}


# handle_exec_errors ($COMMAND)
# -----------------------------
# Display an error message for $COMMAND, based on the content of $? and $!.
sub handle_exec_errors ($)
{
  my ($command) = @_;

  $command = (split (' ', $command))[0];
  if ($!)
    {
      fatal "failed to run $command: $!";
    }
  else
    {
      use POSIX qw (WIFEXITED WEXITSTATUS WIFSIGNALED WTERMSIG);

      if (WIFEXITED ($?))
	{
	  my $status = WEXITSTATUS ($?);
	  # Propagate exit codes.
	  fatal ("$command failed with exit status: $status",
		 exit_code => $status);
	}
      elsif (WIFSIGNALED ($?))
	{
	  my $signal = WTERMSIG ($?);
	  fatal "$command terminated by signal: $signal";
	}
      else
	{
	  fatal "$command exited abnormally";
	}
    }
}

# xqx ($COMMAND)
# --------------
# Same as `qx' (but in scalar context), but fails on errors.
sub xqx ($)
{
  my ($command) = @_;

  verb "running: $command";

  $! = 0;
  my $res = `$command`;
  handle_exec_errors $command
    if $?;

  return $res;
}


# xsystem ($COMMAND)
# ------------------
sub xsystem ($)
{
  my ($command) = @_;

  verb "running: $command";

  $! = 0;
  handle_exec_errors $command
    if system $command;
}


# contents ($FILENAME)
# --------------------
# Swallow the contents of file $FILENAME.
sub contents ($)
{
  my ($file) = @_;
  verb "reading $file";
  local $/;			# Turn on slurp-mode.
  my $f = new Automake::XFile "< $file";
  my $contents = $f->getline;
  $f->close;
  return $contents;
}


1; # for require

### Setup "GNU" style for perl-mode and cperl-mode.
## Local Variables:
## perl-indent-level: 2
## perl-continued-statement-offset: 2
## perl-continued-brace-offset: 0
## perl-brace-offset: 0
## perl-brace-imaginary-offset: 0
## perl-label-offset: -2
## cperl-indent-level: 2
## cperl-brace-offset: 0
## cperl-continued-brace-offset: 0
## cperl-label-offset: -2
## cperl-extra-newline-before-brace: t
## cperl-merge-trailing-else: nil
## cperl-continued-statement-offset: 2
## End:
